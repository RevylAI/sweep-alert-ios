import SwiftUI

/// User-selectable appearance mode stored in UserDefaults.
enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// Human-readable label shown in Settings.
    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    /// Maps the preference to a SwiftUI color scheme override; `nil` follows the device setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    /// UserDefaults key for persisting the selected appearance mode.
    static let storageKey = "appearancePreference"
}
