import Auth0
import Foundation

@MainActor
final class AuthenticationService: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var userName: String?
    @Published private(set) var userEmail: String?
    @Published private(set) var convexSynced = false
    @Published private(set) var primaryCrewId: String?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let authentication = Auth0.authentication(
        clientId: AppConfiguration.auth0ClientID,
        domain: AppConfiguration.auth0Domain
    )
    private let convexService = ConvexService()
    private let pushNotifications = PushNotificationService.shared
    private lazy var credentialsManager = CredentialsManager(authentication: authentication)

    init() {
        Task {
            await checkAuthenticationStatus()
        }
    }

    func checkAuthenticationStatus() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let credentials = try await credentialsManager.credentials()
            isAuthenticated = true
            refreshProfile()
            await syncWithConvex(credentials: credentials)
            _ = try? await ensureDefaultCrew(credentials: credentials)
            registerPushDevice(credentials: credentials)
        } catch {
            isAuthenticated = false
            convexSynced = false
        }
    }

    func login() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let credentials = try await Auth0
                .webAuth(clientId: AppConfiguration.auth0ClientID, domain: AppConfiguration.auth0Domain)
                .scope("openid profile email offline_access")
                .start()

            guard credentialsManager.store(credentials: credentials) else {
                errorMessage = String(localized: "Could not store Auth0 credentials.")
                return
            }

            isAuthenticated = true
            refreshProfile()
            await syncWithConvex(credentials: credentials)
            _ = try? await ensureDefaultCrew(credentials: credentials)
            registerPushDevice(credentials: credentials)
        } catch {
            isAuthenticated = false
            convexSynced = false
            errorMessage = String(localized: "Login failed: \(error.localizedDescription)")
        }
    }

    func logout() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await Auth0
                .webAuth(clientId: AppConfiguration.auth0ClientID, domain: AppConfiguration.auth0Domain)
                .clearSession()
        } catch {
            errorMessage = String(localized: "Logout session clear failed: \(error.localizedDescription)")
        }

        _ = credentialsManager.clear()
        isAuthenticated = false
        userName = nil
        userEmail = nil
        convexSynced = false
        primaryCrewId = nil
    }

    func ensureDefaultCrew() async throws -> RemoteCrewSnapshot {
        try await ensureDefaultCrew(credentials: try await currentCredentials())
    }

    func createInviteURL() async throws -> URL {
        let credentials = try await currentCredentials()
        let crew = try await ensureDefaultCrew(credentials: credentials)
        return try await convexService.createInvite(crewId: crew.id, idToken: credentials.idToken)
    }

    func updateNotificationPreferences(_ preferences: NotificationPreferences) async throws {
        let credentials = try await currentCredentials()
        let crew = try await ensureDefaultCrew(credentials: credentials)
        try await convexService.updateNotificationPreferences(
            crewId: crew.id,
            pushAlerts: preferences.pushAlerts,
            claimUpdates: preferences.claimUpdates,
            firstReminderHours: preferences.firstReminderHours,
            idToken: credentials.idToken
        )
    }

    func acceptInvite(token: String) async throws -> RemoteCrewSnapshot {
        let credentials = try await currentCredentials()
        let crew = try await convexService.acceptInvite(token: token, idToken: credentials.idToken)
        primaryCrewId = crew.id
        return crew
    }

    func createCar(name: String, color: String) async throws -> RemoteCrewSnapshot {
        let credentials = try await currentCredentials()
        let crew = try await ensureDefaultCrew(credentials: credentials)
        let updatedCrew = try await convexService.createCar(
            name: name,
            crewId: crew.id,
            color: color,
            idToken: credentials.idToken
        )
        primaryCrewId = updatedCrew.id
        return updatedCrew
    }

    func renameCrew(name: String) async throws -> RemoteCrewSnapshot {
        let credentials = try await currentCredentials()
        let crew = try await ensureDefaultCrew(credentials: credentials)
        let updatedCrew = try await convexService.renameCrew(crewId: crew.id, name: name, idToken: credentials.idToken)
        primaryCrewId = updatedCrew.id
        return updatedCrew
    }

    func renameCar(carId: String, name: String) async throws -> RemoteCrewSnapshot {
        let credentials = try await currentCredentials()
        let updatedCrew = try await convexService.renameCar(carId: carId, name: name, idToken: credentials.idToken)
        primaryCrewId = updatedCrew.id
        return updatedCrew
    }

    func parkCar(
        carId: String,
        latitude: Double,
        longitude: Double,
        corridor: String,
        side: String,
        ruleId: String,
        scheduleLabel: String,
        nextSweepAt: Date,
        firstReminderHours: Double
    ) async throws -> RemoteCrewSnapshot {
        let credentials = try await currentCredentials()
        let updatedCrew = try await convexService.parkCar(
            carId: carId,
            latitude: latitude,
            longitude: longitude,
            corridor: corridor,
            side: side,
            ruleId: ruleId,
            scheduleLabel: scheduleLabel,
            nextSweepAt: nextSweepAt,
            firstReminderHours: firstReminderHours,
            idToken: credentials.idToken
        )
        primaryCrewId = updatedCrew.id
        return updatedCrew
    }

    func claimMove(parkingSessionId: String) async throws -> RemoteCrewSnapshot {
        let credentials = try await currentCredentials()
        let updatedCrew = try await convexService.claimMove(parkingSessionId: parkingSessionId, idToken: credentials.idToken)
        primaryCrewId = updatedCrew.id
        return updatedCrew
    }

    func completeMove(
        previousParkingSessionId: String,
        latitude: Double,
        longitude: Double,
        corridor: String,
        side: String,
        ruleId: String,
        scheduleLabel: String,
        nextSweepAt: Date,
        firstReminderHours: Double
    ) async throws -> RemoteCrewSnapshot {
        let credentials = try await currentCredentials()
        let updatedCrew = try await convexService.completeMove(
            previousParkingSessionId: previousParkingSessionId,
            latitude: latitude,
            longitude: longitude,
            corridor: corridor,
            side: side,
            ruleId: ruleId,
            scheduleLabel: scheduleLabel,
            nextSweepAt: nextSweepAt,
            firstReminderHours: firstReminderHours,
            idToken: credentials.idToken
        )
        primaryCrewId = updatedCrew.id
        return updatedCrew
    }

    private func refreshProfile() {
        let user = credentialsManager.user
        userName = user?.name ?? user?.nickname ?? user?.email
        userEmail = user?.email
    }

    private func syncWithConvex(credentials: Credentials) async {
        do {
            try await convexService.upsertCurrentUser(idToken: credentials.idToken)
            convexSynced = true
        } catch {
            convexSynced = false
            errorMessage = String(localized: "Convex sync failed: \(error.localizedDescription)")
        }
    }

    private func currentCredentials() async throws -> Credentials {
        try await credentialsManager.credentials()
    }

    private func ensureDefaultCrew(credentials: Credentials) async throws -> RemoteCrewSnapshot {
        let crew = try await convexService.ensureDefaultCrew(idToken: credentials.idToken)
        primaryCrewId = crew.id
        return crew
    }

    private func registerPushDevice(credentials: Credentials) {
        Task {
            do {
                let token = try await pushNotifications.requestDeviceToken()
                try await convexService.registerDevice(pushToken: token, idToken: credentials.idToken)
            } catch {
                errorMessage = String(localized: "Push registration failed: \(error.localizedDescription)")
            }
        }
    }
}
