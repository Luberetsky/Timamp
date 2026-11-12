@testable import AmpX
import XCTest

/// Files handed over by Finder: "Open With", a drop on the Dock icon, or a double-click.
///
/// Rules under test: the files are queued at the end of the playlist; the first of them starts
/// playing when AmpX was launched to open it or the playlist was empty; the startup chime plays
/// only with an empty playlist and never when a file was handed over.
@MainActor
final class OpenFilesTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        super.setUp()
        self.suiteName = "ampx-open-files-\(UUID().uuidString)"
        self.userDefaults = try XCTUnwrap(UserDefaults(suiteName: self.suiteName))
        self.tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ampx-open-files-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: self.tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        self.userDefaults.removePersistentDomain(forName: self.suiteName)
        try? FileManager.default.removeItem(at: self.tempDirectory)
        super.tearDown()
    }

    // MARK: - Helpers

    private struct Harness {
        let application: AmpXApplicationController
        /// The real player the startup chime goes through; the playlist uses `mock`.
        let player: AudioPlayer
        let mock: MockAudioPlayer
        let manager: PlaylistManager
        let hosts: AmpXHostCoordinator
    }

    private func makeFile(_ name: String) -> URL {
        let url = self.tempDirectory.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: Data([0x00]))
        return url
    }

    /// `savedPaths` simulates a playlist saved by the previous launch; the manager restores it
    /// asynchronously, exactly as the app does on start.
    private func makeManager(player: MockAudioPlayer, restoring savedPaths: [String] = []) -> PlaylistManager {
        let stateStore = PlaylistStateStore(userDefaults: self.userDefaults)
        if !savedPaths.isEmpty {
            let bookmarkStore = SecurityScopedBookmarkStore(userDefaults: self.userDefaults)
            for path in savedPaths {
                bookmarkStore.saveBookmark(for: URL(fileURLWithPath: path))
            }
            stateStore.saveState(PersistedPlaylistState(
                trackPaths: savedPaths,
                currentIndex: 0,
                shuffleEnabled: false,
                repeatEnabled: false
            ))
        }
        return PlaylistManager(
            audioPlayer: player,
            restoreBookmarks: !savedPaths.isEmpty,
            restorePlaylist: !savedPaths.isEmpty,
            bookmarkStore: SecurityScopedBookmarkStore(userDefaults: self.userDefaults),
            stateStore: stateStore,
            alertPresenter: SilentPlaylistAlertPresenter()
        )
    }

    private func makeApplication(restoring savedPaths: [String] = []) -> Harness {
        let mock = MockAudioPlayer()
        let manager = self.makeManager(player: mock, restoring: savedPaths)
        let player = AudioPlayer(installRemoteCommands: false)
        let hosts = AmpXHostCoordinator(
            state: AmpXModuleState(),
            skin: ClassicModernSkin(),
            layoutStore: makeIsolatedLayoutStore(),
            audioPlayer: player,
            playlistManager: manager
        )
        let application = AmpXApplicationController(
            audioPlayer: player,
            playlistManager: manager,
            hosts: hosts,
            playsStartupSound: true
        )
        return Harness(application: application, player: player, mock: mock, manager: manager, hosts: hosts)
    }

    /// Lets nested main-actor hops (track load completion, then play) finish.
    private func settle(_ seconds: TimeInterval = 0.3) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func waitForCurrentTrack(on player: AudioPlayer, timeout: TimeInterval = 5.0) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, player.currentTrack == nil {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    // MARK: - Queueing rules (PlaylistManager)

    func testOpenedFilePlaysWhenPlaylistIsEmpty() async {
        let player = MockAudioPlayer()
        let manager = self.makeManager(player: player)
        let file = self.makeFile("first.mp3")

        manager.enqueueOpenedURLs([file]) { playlistWasEmpty in playlistWasEmpty }
        await waitForTrackCount(1, on: manager)
        await self.settle()

        XCTAssertEqual(manager.tracks.first?.url, file)
        XCTAssertEqual(manager.currentIndex, 0)
        XCTAssertEqual(player.loadTrackCalls.count, 1)
        XCTAssertEqual(player.playCallCount, 1)
    }

    func testOpenedFileIsOnlyQueuedWhenPlaylistHasTracks() async {
        let player = MockAudioPlayer()
        let manager = self.makeManager(player: player)
        manager.tracks = [Track(title: "Playing", artist: "Artist", url: URL(fileURLWithPath: "/tmp/playing.mp3"))]
        manager.currentIndex = 0
        let file = self.makeFile("queued.flac")

        manager.enqueueOpenedURLs([file]) { playlistWasEmpty in playlistWasEmpty }
        await waitForTrackCount(2, on: manager)
        await self.settle()

        XCTAssertEqual(manager.tracks.last?.url, file)
        XCTAssertEqual(manager.currentIndex, 0)
        XCTAssertTrue(player.loadTrackCalls.isEmpty)
        XCTAssertEqual(player.playCallCount, 0)
    }

    func testSeveralOpenedFilesAreQueuedInOrderAndTheFirstPlays() async {
        let player = MockAudioPlayer()
        let manager = self.makeManager(player: player)
        let first = self.makeFile("one.wav")
        let second = self.makeFile("two.mp3")

        manager.enqueueOpenedURLs([first, second]) { playlistWasEmpty in playlistWasEmpty }
        await waitForTrackCount(2, on: manager)
        await self.settle()

        XCTAssertEqual(manager.tracks.compactMap { $0.url }, [first, second])
        XCTAssertEqual(manager.currentIndex, 0)
        XCTAssertEqual(player.loadTrackCalls.first?.url, first)
        XCTAssertEqual(player.playCallCount, 1)
    }

    func testOpenedM3UQueuesItsTracks() async throws {
        _ = self.makeFile("a.mp3")
        _ = self.makeFile("b.flac")
        let playlist = self.tempDirectory.appendingPathComponent("list.m3u")
        try "#EXTM3U\na.mp3\nb.flac\n".write(to: playlist, atomically: true, encoding: .utf8)
        let player = MockAudioPlayer()
        let manager = self.makeManager(player: player)

        manager.enqueueOpenedURLs([playlist]) { playlistWasEmpty in playlistWasEmpty }
        await waitForTrackCount(2, on: manager)
        await self.settle()

        XCTAssertEqual(manager.tracks.compactMap { $0.url?.lastPathComponent }, ["a.mp3", "b.flac"])
        XCTAssertEqual(manager.currentIndex, 0)
        XCTAssertEqual(player.playCallCount, 1)
    }

    func testOpenedFileWithUnsupportedExtensionIsIgnored() async {
        let player = MockAudioPlayer()
        let manager = self.makeManager(player: player)
        let file = self.makeFile("clip.ogg")

        manager.enqueueOpenedURLs([file]) { _ in true }
        await self.settle()

        XCTAssertTrue(manager.tracks.isEmpty)
        XCTAssertTrue(player.loadTrackCalls.isEmpty)
    }

    func testFileOpenedAtLaunchIsQueuedAfterTheRestoredPlaylistAndPlays() async {
        let saved = self.makeFile("saved.mp3")
        let opened = self.makeFile("opened.mp3")
        let player = MockAudioPlayer()
        let manager = self.makeManager(player: player, restoring: [saved.path])

        // Same main-actor turn as the launch: the restore has not delivered its tracks yet.
        XCTAssertTrue(manager.tracks.isEmpty)
        manager.enqueueOpenedURLs([opened]) { _ in true }
        await waitForTrackCount(2, on: manager)
        await self.settle()

        XCTAssertEqual(manager.tracks.compactMap { $0.url?.lastPathComponent }, ["saved.mp3", "opened.mp3"])
        XCTAssertEqual(manager.currentIndex, 1)
        XCTAssertEqual(player.loadTrackCalls.last?.url, opened)
        XCTAssertEqual(player.playCallCount, 1)
    }

    // MARK: - Launch and running app (AmpXApplicationController)

    func testLaunchByOpeningFileSkipsStartupSoundAndPlaysTheFile() async {
        let harness = self.makeApplication()
        defer { harness.hosts.hideAllWindowsForTesting() }
        let file = self.makeFile("launch.mp3")

        harness.application.start(opening: [file])
        await waitForTrackCount(1, on: harness.manager)
        await self.settle(1.0)

        XCTAssertEqual(harness.manager.currentIndex, 0)
        XCTAssertEqual(harness.mock.playCallCount, 1)
        XCTAssertNil(harness.player.currentTrack, "the startup chime must not load")
    }

    func testLaunchByOpeningFilePlaysItEvenWithARestoredPlaylist() async {
        let saved = self.makeFile("saved.mp3")
        let harness = self.makeApplication(restoring: [saved.path])
        defer { harness.hosts.hideAllWindowsForTesting() }
        let file = self.makeFile("launch.mp3")

        harness.application.start(opening: [file])
        await waitForTrackCount(2, on: harness.manager)
        await self.settle(1.0)

        XCTAssertEqual(harness.manager.currentIndex, 1)
        XCTAssertEqual(harness.mock.loadTrackCalls.last?.url, file)
        XCTAssertEqual(harness.mock.playCallCount, 1)
        XCTAssertNil(harness.player.currentTrack, "the startup chime must not load")
    }

    func testFileOpenedWhileRunningWithTracksIsOnlyQueued() async {
        let harness = self.makeApplication()
        defer { harness.hosts.hideAllWindowsForTesting() }
        harness.manager.tracks = [Track(title: "Playing", artist: "Artist", url: URL(fileURLWithPath: "/tmp/playing.mp3"))]
        harness.manager.currentIndex = 0
        let file = self.makeFile("queued.mp3")

        harness.application.start()
        harness.application.openFiles([file])
        await waitForTrackCount(2, on: harness.manager)
        await self.settle(1.0)

        XCTAssertEqual(harness.manager.tracks.last?.url, file)
        XCTAssertEqual(harness.manager.currentIndex, 0)
        XCTAssertTrue(harness.mock.loadTrackCalls.isEmpty)
        XCTAssertEqual(harness.mock.playCallCount, 0)
    }

    func testFileOpenedRightAfterLaunchCancelsThePendingStartupSound() async {
        let harness = self.makeApplication()
        defer { harness.hosts.hideAllWindowsForTesting() }
        let file = self.makeFile("soon.mp3")

        harness.application.start()
        harness.application.openFiles([file])
        await waitForTrackCount(1, on: harness.manager)
        await self.settle(1.0)

        XCTAssertEqual(harness.mock.playCallCount, 1)
        XCTAssertNil(harness.player.currentTrack, "the startup chime must not load")
    }

    // MARK: - Startup chime: empty playlist only

    func testStartupSoundPlaysWhenPlaylistIsEmpty() async {
        let harness = self.makeApplication()
        defer {
            harness.player.stop()
            harness.hosts.hideAllWindowsForTesting()
        }

        harness.application.start()
        await self.waitForCurrentTrack(on: harness.player)

        XCTAssertEqual(harness.player.currentTrack?.url?.lastPathComponent, "startup.mp3")
    }

    func testStartupSoundStaysSilentWhenPlaylistIsRestored() async {
        let saved = self.makeFile("saved.mp3")
        let harness = self.makeApplication(restoring: [saved.path])
        defer { harness.hosts.hideAllWindowsForTesting() }

        harness.application.start()
        await waitForTrackCount(1, on: harness.manager)
        await self.settle(1.0)

        XCTAssertNil(harness.player.currentTrack, "the chime is for an empty playlist only")
        XCTAssertEqual(harness.mock.playCallCount, 0)
    }

    // MARK: - Declared file types

    func testEverySupportedFormatIsDeclaredAsADocumentType() throws {
        let types = try XCTUnwrap(Bundle.main.infoDictionary?["CFBundleDocumentTypes"] as? [[String: Any]])
        let declared = Set(types.flatMap { $0["CFBundleTypeExtensions"] as? [String] ?? [] })

        XCTAssertTrue(declared.isSuperset(of: M3UParser.supportedExtensions), "declared: \(declared.sorted())")
        XCTAssertTrue(declared.isSuperset(of: Set(["m3u", "m3u8"])), "declared: \(declared.sorted())")
    }
}
