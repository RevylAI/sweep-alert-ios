import SwiftUI

/// Adaptive brand and surface colors for light and dark appearance.
enum SweepTheme {
    /// Primary brand blue used for CTAs, icons, and accents.
    static let blue = Color("SweepBlue")

    /// Primary text color that adapts between light and dark mode.
    static let ink = Color("SweepInk")

    /// Secondary text color for captions and supporting labels.
    static let muted = Color("SweepMuted")

    /// Hairline border for frosted cards and floating panels.
    static let cardBorder = Color("SweepCardBorder")

    /// Drop shadow tint for elevated surfaces.
    static let cardShadow = Color("SweepCardShadow")
}
