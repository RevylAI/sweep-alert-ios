import SwiftUI

/// Shared color tokens and chrome helpers that adapt to light and dark mode.
enum SweepTheme {
    /// Brand accent blue, unchanged across appearance modes.
    static let blue = Color(red: 0.05, green: 0.39, blue: 0.90)

    /// Primary body text that follows the system label color.
    static let ink = Color(.label)

    /// Secondary supporting text that follows the system secondary label color.
    static let muted = Color(.secondaryLabel)

    /// Returns a subtle card stroke tuned for the active color scheme.
    static func cardStroke(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.white.opacity(0.58)
    }

    /// Returns a card shadow color tuned for the active color scheme.
    static func cardShadow(for colorScheme: ColorScheme, opacity: Double = 0.09) -> Color {
        let darkOpacity = min(opacity + 0.20, 0.45)
        return Color.black.opacity(colorScheme == .dark ? darkOpacity : opacity)
    }
}
