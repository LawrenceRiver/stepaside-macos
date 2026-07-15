import AppKit
import StepAsideCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let coordinator: ArrangementCoordinator
    private let preferences: AppPreferences
    private let accessibility: AccessibilityGate
    private let launchService: LaunchAtLoginService
    private let settings: SettingsController
    private let hud: HUDController
    private var canUndo = false
    private var isArranging = false

    init(
        coordinator: ArrangementCoordinator,
        preferences: AppPreferences,
        accessibility: AccessibilityGate,
        launchService: LaunchAtLoginService,
        settings: SettingsController,
        hud: HUDController
    ) {
        self.coordinator = coordinator
        self.preferences = preferences
        self.accessibility = accessibility
        self.launchService = launchService
        self.settings = settings
        self.hud = hud
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureStatusItem()
    }

    func arrange() {
        guard accessibility.isTrusted else {
            _ = accessibility.requestAccess()
            settings.show()
            hud.show(headline: "Accessibility permission needed", tone: .attention)
            return
        }
        guard !isArranging else {
            hud.show(headline: "Already arranging", tone: .information)
            return
        }

        isArranging = true
        setStatusSymbol("hourglass")
        let spacing = preferences.spacing.points
        Task { [weak self] in
            guard let self else { return }
            let outcome = await self.coordinator.arrange(spacing: spacing)
            self.finish(outcome)
        }
    }

    func stop() {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "StepAside — arrange this desktop"
        setStatusSymbol("rectangle.grid.2x2")
    }

    private func setStatusSymbol(_ name: String) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "StepAside")?
            .withSymbolConfiguration(configuration)
        statusItem.button?.image?.isTemplate = true
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu(from: sender)
        } else {
            arrange()
        }
    }

    private func showMenu(from button: NSStatusBarButton) {
        let menu = NSMenu(title: "StepAside")
        menu.delegate = self
        menu.addItem(item("Arrange Now", action: #selector(arrangeFromMenu), key: ""))

        let undo = item("Undo Last Arrangement", action: #selector(undoFromMenu), key: "z")
        undo.isEnabled = canUndo && !isArranging
        menu.addItem(undo)
        menu.addItem(.separator())

        let launch = item("Launch at Login", action: #selector(toggleLaunchAtLogin), key: "")
        launch.state = launchService.isEnabled ? .on : .off
        menu.addItem(launch)
        menu.addItem(item("Settings…", action: #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Quit StepAside", action: #selector(quit), key: "q"))

        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    private func item(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func arrangeFromMenu() {
        arrange()
    }

    @objc private func undoFromMenu() {
        guard !isArranging else { return }
        isArranging = true
        setStatusSymbol("arrow.uturn.backward")
        Task { [weak self] in
            guard let self else { return }
            let outcome = await self.coordinator.undo()
            self.finish(outcome)
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try launchService.setEnabled(!launchService.isEnabled)
            settings.refresh()
        } catch {
            hud.show(headline: "Could not change login setting", tone: .attention)
        }
    }

    @objc private func openSettings() {
        settings.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func finish(_ outcome: ArrangementOutcome) {
        isArranging = false
        canUndo = outcome.status == .success || outcome.status == .partial
        if outcome.status == .undone || outcome.status == .nothingToUndo {
            canUndo = false
        }
        preferences.latestResult = outcome.headline
        settings.refresh()
        setStatusSymbol("rectangle.grid.2x2")
        hud.show(outcome)
    }
}

