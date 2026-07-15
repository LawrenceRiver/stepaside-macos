import Carbon.HIToolbox
import Foundation
import StepAsideCore

@MainActor
final class AppPreferences {
    private enum Key {
        static let spacing = "spacing"
        static let hotKeyKeyCode = "hotKeyKeyCode"
        static let hotKeyModifiers = "hotKeyModifiers"
        static let completedOnboarding = "completedOnboarding"
        static let latestResult = "latestResult"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var spacing: SpacingPreference {
        get {
            guard let rawValue = defaults.string(forKey: Key.spacing) else { return .balanced }
            return SpacingPreference(rawValue: rawValue) ?? .balanced
        }
        set { defaults.set(newValue.rawValue, forKey: Key.spacing) }
    }

    var hotKeyKeyCode: UInt32 {
        get {
            guard defaults.object(forKey: Key.hotKeyKeyCode) != nil else {
                return UInt32(kVK_ANSI_S)
            }
            return UInt32(defaults.integer(forKey: Key.hotKeyKeyCode))
        }
        set { defaults.set(Int(newValue), forKey: Key.hotKeyKeyCode) }
    }

    var hotKeyModifiers: UInt32 {
        get {
            guard defaults.object(forKey: Key.hotKeyModifiers) != nil else {
                return UInt32(controlKey | optionKey)
            }
            return UInt32(defaults.integer(forKey: Key.hotKeyModifiers))
        }
        set { defaults.set(Int(newValue), forKey: Key.hotKeyModifiers) }
    }

    var completedOnboarding: Bool {
        get { defaults.bool(forKey: Key.completedOnboarding) }
        set { defaults.set(newValue, forKey: Key.completedOnboarding) }
    }

    var latestResult: String {
        get { defaults.string(forKey: Key.latestResult) ?? "Ready to arrange." }
        set { defaults.set(newValue, forKey: Key.latestResult) }
    }
}
