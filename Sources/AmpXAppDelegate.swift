import AppKit

@main
@MainActor
final class AmpXAppDelegate: NSObject, NSApplicationDelegate {
    private static var isRunningUnderTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    static func main() {
        let app = NSApplication.shared
        let delegate = AmpXAppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    private var applicationController: AmpXApplicationController?
    private var keyboardEventMonitor: Any?
    /// Files Finder handed over before launch finished ("Open With" on a closed AmpX).
    private var pendingOpenURLs: [URL] = []

    func applicationDidFinishLaunching(_: Notification) {
        guard !Self.isRunningUnderTest else { return }

        AmpXFonts.register()
        UserDefaults.standard.set(false, forKey: "NSFullScreenMenuItemEverywhere")

        let audioPlayer = AudioPlayer.shared
        let playlistManager = PlaylistManager.shared
        let layoutStore = AmpXLayoutStore(defaults: .standard)
        let saved = layoutStore.load()
        let hosts = AmpXHostCoordinator(
            state: saved.state,
            skin: ClassicModernSkin(),
            layoutStore: layoutStore,
            audioPlayer: audioPlayer,
            playlistManager: playlistManager
        )
        let application = AmpXApplicationController(
            audioPlayer: audioPlayer,
            playlistManager: playlistManager,
            hosts: hosts
        )
        self.applicationController = application

        NSApp.mainMenu = AmpXMenuBuilder.makeMainMenu(application: application)
        self.installKeyboardShortcuts()

        let launchURLs = self.pendingOpenURLs
        self.pendingOpenURLs.removeAll()
        application.start(opening: launchURLs)
    }

    /// "Open With", a drop on the Dock icon, or a double-click in Finder.
    func application(_: NSApplication, open urls: [URL]) {
        guard let application = self.applicationController else {
            // AmpX is being launched to open these files: AppKit delivers them before
            // `applicationDidFinishLaunching`, so keep them until the app is set up.
            self.pendingOpenURLs.append(contentsOf: urls)
            return
        }
        application.openFiles(urls)
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            self.applicationController?.hosts.showAll()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_: Notification) {
        self.applicationController?.terminate()
        if let monitor = keyboardEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func installKeyboardShortcuts() {
        self.keyboardEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let application = self.applicationController else { return event }
            return AmpXKeyRouter.handle(
                event,
                window: NSApp.keyWindow,
                audioPlayer: application.audioPlayer,
                playlistManager: application.playlistManager,
                entheaTheater: application.hosts,
                moduleCommandHandler: { command in
                    application.hosts.performModuleCommand(command)
                },
                playerCommandHandler: { command in
                    application.hosts.performPlayerCommand(command)
                }
            )
        }
    }
}
