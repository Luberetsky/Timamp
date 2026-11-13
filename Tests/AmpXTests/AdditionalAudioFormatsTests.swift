@testable import AmpX
import AVFoundation
import UniformTypeIdentifiers
import XCTest

private let toneSampleRate = 44100.0
private let toneSeconds = 1.0

/// How a test tone is encoded; the file type itself follows from the file extension.
private enum ToneEncoding {
    case aac, appleLossless, aiff

    var settings: [String: Any] {
        var settings: [String: Any] = [AVSampleRateKey: toneSampleRate, AVNumberOfChannelsKey: 2]
        switch self {
        case .aac:
            settings[AVFormatIDKey] = kAudioFormatMPEG4AAC
        case .appleLossless:
            settings[AVFormatIDKey] = kAudioFormatAppleLossless
            settings[AVEncoderBitDepthHintKey] = 16
        case .aiff:
            settings[AVFormatIDKey] = kAudioFormatLinearPCM
            settings[AVLinearPCMBitDepthKey] = 16
            settings[AVLinearPCMIsFloatKey] = false
            settings[AVLinearPCMIsBigEndianKey] = true
        }
        return settings
    }
}

/// MPEG-4 audio (AAC and Apple Lossless in .m4a and .m4b), raw AAC and AIFF.
///
/// macOS decodes these formats itself, so the player only has to accept the extensions. Each format
/// test encodes a one-second tone and takes that file through what the player does with any track:
/// the extension filter, format details, metadata, loading and decoding.
@MainActor
final class AdditionalAudioFormatsTests: XCTestCase {
    private var directory: URL!
    private var player: AudioPlayer!

    override func setUpWithError() throws {
        super.setUp()
        self.directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ampx-formats-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        self.player = AudioPlayer(installRemoteCommands: false)
    }

    override func tearDown() {
        self.player = nil
        try? FileManager.default.removeItem(at: self.directory)
        super.tearDown()
    }

    // MARK: - Helpers

    /// A one-second 440 Hz tone. The file is closed, and so complete, when this returns.
    private func writeTone(named name: String, as encoding: ToneEncoding) throws -> URL {
        let url = self.directory.appendingPathComponent(name)
        let file = try AVAudioFile(forWriting: url, settings: encoding.settings)
        let format = file.processingFormat
        let frames = AVAudioFrameCount(toneSampleRate * toneSeconds)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        let channels = try XCTUnwrap(buffer.floatChannelData)
        for channel in 0 ..< Int(format.channelCount) {
            for frame in 0 ..< Int(frames) {
                let phase = 2 * Double.pi * 440 * Double(frame) / toneSampleRate
                channels[channel][frame] = Float(sin(phase)) * 0.25
            }
        }
        try file.write(from: buffer)
        return url
    }

    private func copy(_ source: URL, as name: String) throws -> URL {
        let url = self.directory.appendingPathComponent(name)
        try FileManager.default.copyItem(at: source, to: url)
        return url
    }

    private func load(_ track: Track) async -> Bool {
        let finished = expectation(description: "load \(track.title)")
        let outcome = SendableBox(false)
        self.player.loadTrack(track) { loaded in
            outcome.value = loaded
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 5)
        return outcome.value
    }

    /// Takes one file through everything the player does with a track before it plays.
    private func assertPlayable(_ url: URL, file: StaticString = #filePath, line: UInt = #line) async throws {
        let name = url.lastPathComponent
        XCTAssertTrue(M3UParser.isSupportedAudioExtension(url.pathExtension), "\(name) is filtered out", file: file, line: line)

        let details = try XCTUnwrap(AudioFormatInfo.read(from: url), "no format details for \(name)", file: file, line: line)
        XCTAssertEqual(details.sampleRateHz, toneSampleRate, "\(name): sample rate", file: file, line: line)
        XCTAssertEqual(details.channelCount, 2, "\(name): channels", file: file, line: line)

        let track = await Track.load(from: url)
        XCTAssertEqual(track.duration, toneSeconds, accuracy: 0.2, "\(name): duration in the playlist", file: file, line: line)

        let loaded = await self.load(track)
        XCTAssertTrue(loaded, "the player could not load \(name)", file: file, line: line)
        XCTAssertEqual(self.player.duration, toneSeconds, accuracy: 0.2, "\(name): duration in the player", file: file, line: line)

        // Playback reads samples through this same API.
        let decoder = try AVAudioFile(forReading: url)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: decoder.processingFormat, frameCapacity: 8192))
        try decoder.read(into: buffer)
        let samples = try XCTUnwrap(buffer.floatChannelData)
        let peak = (0 ..< Int(buffer.frameLength)).map { abs(samples[0][$0]) }.max() ?? 0
        XCTAssertGreaterThan(peak, 0.1, "\(name) decodes to silence", file: file, line: line)
    }

    // MARK: - Formats

    func testAACInM4AIsPlayable() async throws {
        try await self.assertPlayable(self.writeTone(named: "tone-aac.m4a", as: .aac))
    }

    func testAppleLosslessInM4AIsPlayable() async throws {
        try await self.assertPlayable(self.writeTone(named: "tone-lossless.m4a", as: .appleLossless))
    }

    func testAudiobookExtensionIsPlayable() async throws {
        let m4a = try self.writeTone(named: "tone.m4a", as: .aac)
        try await self.assertPlayable(self.copy(m4a, as: "tone.m4b"))
    }

    func testRawAACIsPlayable() async throws {
        try await self.assertPlayable(self.writeTone(named: "tone.aac", as: .aac))
    }

    func testAIFFIsPlayableUnderBothExtensions() async throws {
        let aiff = try self.writeTone(named: "tone.aiff", as: .aiff)
        try await self.assertPlayable(aiff)
        try await self.assertPlayable(self.copy(aiff, as: "tone.aif"))
    }

    // MARK: - Where the formats are offered

    func testPlaylistFilesMayListTheNewFormats() {
        let urls = M3UParser.parseTrackURLs(
            from: "one.m4a\ntwo.m4b\nthree.aac\nfour.aiff\nfive.aif\nprotected.m4p\n",
            playlistDirectory: self.directory
        )
        XCTAssertEqual(urls.map(\.lastPathComponent), ["one.m4a", "two.m4b", "three.aac", "four.aiff", "five.aif"])
    }

    func testAddFilesPanelOffersEverySupportedFormat() throws {
        let offered = PlaylistManager.filePickerContentTypes
        for ext in M3UParser.supportedExtensions.sorted() + ["m3u"] {
            let type = try XCTUnwrap(UTType(filenameExtension: ext), ext)
            XCTAssertTrue(offered.contains(type), "\(ext) is missing from the Add Files panel")
        }
        XCTAssertEqual(Set(offered).count, offered.count, "a type is offered twice")
    }
}
