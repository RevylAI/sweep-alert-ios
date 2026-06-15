import Foundation

enum AppConfiguration {
    static let bundleIdentifier = "ai.revyl.sweepalert.swift"

    static let auth0Domain = "dev-c15pmd5mlqf06u0m.us.auth0.com"
    static let auth0ClientID = "Q4fOB6NPC5LGO0WdNYpf0jXZedHnaP9n"

    static let convexURL = URL(string: "https://upbeat-zebra-710.convex.cloud")!
    static let convexSiteURL = URL(string: "https://upbeat-zebra-710.convex.site")!
    static let inviteBaseURL = URL(string: "https://getsweepalert.com/invite")!

    #if DEBUG
    static let apnsEnvironment = "sandbox"
    #else
    static let apnsEnvironment = "production"
    #endif
}
