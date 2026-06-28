import SwiftUI
import UIKit

import SwiftUI
import UIKit

/// User-selectable appearance modes for the app shell.
enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// Human-readable label for settings controls.
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

    /// SwiftUI color scheme override, or nil to follow the device setting.
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

/// Shared adaptive color tokens for SweepAlert light and dark appearances.
enum SweepTheme {
    /// Primary brand blue used for actions and highlights.
    static let blue = Color("SweepBlue")

    /// Primary text color that adapts between dark ink and light ink.
    static let ink = Color("SweepInk")

    /// Secondary text color for subtitles and supporting labels.
    static let muted = Color("SweepMuted")

    /// Card and pill border color for frosted surfaces.
    static let border = Color("SweepBorder")

    /// Shadow color that stays subtle in both appearances.
    static let shadow = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.35)
            : UIColor.black.withAlphaComponent(0.14)
    })
}
