import SwiftUI

/// Centralized brand and semantic colors that adapt to the current color scheme.
enum SweepColors {
    /// Primary brand accent used for buttons, links, and highlights.
    static let blue = Color(red: 0.05, green: 0.39, blue: 0.90)

    /// Primary text color that adapts between light and dark mode.
    static let ink = Color("SweepInk")

    /// Secondary text color that adapts between light and dark mode.
    static let muted = Color("SweepMuted")

    /// Card and panel border stroke that adapts between light and dark mode.
    static let cardStroke = Color("SweepCardStroke")
}

/// User-selectable app appearance preference stored in UserDefaults.
enum AppAppearance: String, CaseIterable, Identifiable {
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

    /// Resolves the SwiftUI color scheme override, if any.
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
}
