import SwiftUI

@main
struct SweepAlertSwiftApp: App {
    @UIApplicationDelegateAdaptor(SweepAlertAppDelegate.self) private var appDelegate
    @StateObject private var authentication = AuthenticationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authentication)
                .preferredColorScheme(.light)
        }
    }
}
