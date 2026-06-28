import SwiftUI

/// Shared color tokens that adapt to the current interface style.
enum SweepColors {
    /// Brand accent blue used for primary actions and highlights.
    static let blue = Color(red: 0.05, green: 0.39, blue: 0.90)

    /// Primary text color that adapts between light and dark mode.
    static let ink = Color.primary

    /// Secondary text color that adapts between light and dark mode.
    static let muted = Color.secondary
}
