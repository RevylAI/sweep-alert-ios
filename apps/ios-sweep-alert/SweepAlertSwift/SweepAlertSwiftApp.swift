import SwiftUI

@main
struct SweepAlertSwiftApp: App {
    @UIApplicationDelegateAdaptor(SweepAlertAppDelegate.self) private var appDelegate
    @StateObject private var authentication = AuthenticationService()
    @AppStorage(AppearancePreference.storageKey) private var appearanceRawValue = AppearancePreference.system.rawValue

    /// Resolves the persisted appearance preference to a SwiftUI color scheme override.
    private var preferredScheme: ColorScheme? {
        (AppearancePreference(rawValue: appearanceRawValue) ?? .system).colorScheme
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authentication)
                .preferredColorScheme(preferredScheme)
        }
    }
}
