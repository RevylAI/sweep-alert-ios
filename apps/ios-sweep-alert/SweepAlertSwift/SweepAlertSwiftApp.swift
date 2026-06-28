import SwiftUI

@main
struct SweepAlertSwiftApp: App {
    @UIApplicationDelegateAdaptor(SweepAlertAppDelegate.self) private var appDelegate
    @StateObject private var authentication = AuthenticationService()

    init() {
        #if DEBUG
        applyRevylAppearanceOverrideIfNeeded()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authentication)
        }
    }

    #if DEBUG
    /// Applies a Revyl launch-var appearance override for device verification screenshots.
    private func applyRevylAppearanceOverrideIfNeeded() {
        guard let appearance = ProcessInfo.processInfo.environment["REVYL_APPEARANCE"]?.lowercased() else {
            return
        }

        let style: UIUserInterfaceStyle
        switch appearance {
        case "dark":
            style = .dark
        case "light":
            style = .light
        default:
            return
        }

        UIView.appearance().overrideUserInterfaceStyle = style
    }
    #endif
}
