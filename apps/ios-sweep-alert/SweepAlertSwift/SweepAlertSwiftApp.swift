import SwiftUI

@main
struct SweepAlertSwiftApp: App {
    @UIApplicationDelegateAdaptor(SweepAlertAppDelegate.self) private var appDelegate
    @StateObject private var authentication = AuthenticationService()
    @AppStorage("appAppearance") private var appAppearanceRaw = AppAppearance.system.rawValue

    private var appAppearance: AppAppearance {
        AppAppearance(rawValue: appAppearanceRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authentication)
                .preferredColorScheme(appAppearance.colorScheme)
        }
    }
}
