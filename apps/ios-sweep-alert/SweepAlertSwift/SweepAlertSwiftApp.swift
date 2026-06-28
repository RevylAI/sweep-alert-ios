import SwiftUI

@main
struct SweepAlertSwiftApp: App {
    @UIApplicationDelegateAdaptor(SweepAlertAppDelegate.self) private var appDelegate
    @StateObject private var authentication = AuthenticationService()
    @AppStorage("appearancePreference") private var appearancePreference = AppearancePreference.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authentication)
                .preferredColorScheme(currentAppearance.colorScheme)
        }
    }

    /// Resolves the persisted appearance preference for the app root view.
    private var currentAppearance: AppearancePreference {
        AppearancePreference(rawValue: appearancePreference) ?? .system
    }
}
