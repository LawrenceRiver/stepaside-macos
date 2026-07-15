import AppKit
import Combine
import StepAsideCore
import SwiftUI

@MainActor
final class SettingsModel: ObservableObject {
    @Published private(set) var permissionGranted = false
    @Published private(set) var spacing: SpacingPreference = .balanced
    @Published private(set) var launchAtLogin = false
    @Published private(set) var latestResult = "Ready to arrange."
    @Published private(set) var launchError: String?

    let hotKeyLabel = "⌃⌥S"
    let hotKeyAccessibleLabel = "Control Option S"
    let version: String

    private let preferences: AppPreferences
    private let accessibility: AccessibilityGate
    private let launchService: LaunchAtLoginService

    init(
        preferences: AppPreferences,
        accessibility: AccessibilityGate,
        launchService: LaunchAtLoginService
    ) {
        self.preferences = preferences
        self.accessibility = accessibility
        self.launchService = launchService
        version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "development"
        refresh()
    }

    func refresh() {
        permissionGranted = accessibility.isTrusted
        spacing = preferences.spacing
        launchAtLogin = launchService.isEnabled
        latestResult = preferences.latestResult
    }

    func requestPermission() {
        _ = accessibility.requestAccess()
        refreshPermissionSoon()
    }

    func openPermissionSettings() {
        accessibility.openSystemSettings()
        refreshPermissionSoon()
    }

    func setSpacing(_ spacing: SpacingPreference) {
        preferences.spacing = spacing
        self.spacing = spacing
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchService.setEnabled(enabled)
            launchError = nil
        } catch {
            launchError = error.localizedDescription
        }
        launchAtLogin = launchService.isEnabled
    }

    private func refreshPermissionSoon() {
        Task { [weak self] in
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self else { return }
                self.permissionGranted = self.accessibility.isTrusted
                if self.permissionGranted { return }
            }
        }
    }
}

@MainActor
final class SettingsController: NSObject, NSWindowDelegate {
    private let model: SettingsModel
    private let preferences: AppPreferences
    private lazy var window: NSWindow = makeWindow()

    init(
        preferences: AppPreferences,
        accessibility: AccessibilityGate,
        launchService: LaunchAtLoginService
    ) {
        self.preferences = preferences
        model = SettingsModel(
            preferences: preferences,
            accessibility: accessibility,
            launchService: launchService
        )
        super.init()
    }

    func show() {
        model.refresh()
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func refresh() {
        model.refresh()
    }

    func windowWillClose(_ notification: Notification) {
        preferences.completedOnboarding = true
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 630, height: 720),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "StepAside Settings"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(red: 0.965, green: 0.949, blue: 0.902, alpha: 1)
        window.contentView = NSHostingView(rootView: SettingsView(model: model))
        return window
    }
}

