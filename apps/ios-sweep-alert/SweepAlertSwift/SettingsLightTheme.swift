import SwiftUI

/// Light appearance tokens for the unauthenticated Settings screen.
struct SettingsLightTheme {
    /// Grouped screen background used behind settings cards.
    let groupedBackground: Color
    /// Card and navigation control surfaces.
    let cardBackground: Color
    /// Secondary button and field surfaces.
    let secondarySurface: Color
    /// Primary text color for titles and labels.
    let ink: Color
    /// Secondary text color for subtitles and section headers.
    let muted: Color
    /// Divider and card border color.
    let separator: Color

    /// Default light palette for signed-out Settings.
    static let unauthenticated = SettingsLightTheme(
        groupedBackground: Color(red: 0.949, green: 0.949, blue: 0.969),
        cardBackground: .white,
        secondarySurface: Color(red: 0.941, green: 0.941, blue: 0.957),
        ink: Color(red: 0.08, green: 0.10, blue: 0.14),
        muted: Color(red: 0.38, green: 0.43, blue: 0.50),
        separator: Color(red: 0.82, green: 0.84, blue: 0.87)
    )
}

/// Applies light appearance for the signed-out Settings screen.
struct SettingsUnauthenticatedLightMode: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.preferredColorScheme(.light)
        } else {
            content
        }
    }
}

extension View {
    /// Forces light mode styling for the unauthenticated Settings experience.
    func settingsUnauthenticatedLightMode(isEnabled: Bool) -> some View {
        modifier(SettingsUnauthenticatedLightMode(isEnabled: isEnabled))
    }
}
