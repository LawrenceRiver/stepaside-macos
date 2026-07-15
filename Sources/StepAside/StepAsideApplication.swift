import AppKit
import StepAsideCore

@main
enum StepAsideApplication {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = StepAsideAppDelegate()
        application.delegate = delegate
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
private final class StepAsideAppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = AppPreferences()
    private let accessibility = AccessibilityGate()
    private let launchService = LaunchAtLoginService()
    private let hotKey = GlobalHotKeyService()
    private let hud = HUDController()
    private let coordinator = ArrangementCoordinator(
        windowSystem: MacWindowSystem(),
        layoutEngine: LayoutEngine()
    )

    private var settings: SettingsController?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let settings = SettingsController(
            preferences: preferences,
            accessibility: accessibility,
            launchService: launchService
        )
        let statusItem = StatusItemController(
            coordinator: coordinator,
            preferences: preferences,
            accessibility: accessibility,
            launchService: launchService,
            settings: settings,
            hud: hud
        )
        self.settings = settings
        self.statusItem = statusItem

        do {
            try hotKey.register(
                keyCode: preferences.hotKeyKeyCode,
                modifiers: preferences.hotKeyModifiers
            ) { [weak statusItem] in
                statusItem?.arrange()
            }
        } catch {
            preferences.latestResult = "Shortcut unavailable · menu click still works"
            settings.refresh()
        }

        if !preferences.completedOnboarding || !accessibility.isTrusted {
            settings.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKey.stop()
        statusItem?.stop()
    }
}
