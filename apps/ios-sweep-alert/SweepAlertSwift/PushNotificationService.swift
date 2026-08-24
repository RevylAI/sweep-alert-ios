import Foundation
import UIKit
import UserNotifications

enum PushNotificationError: LocalizedError {
    case permissionDenied
    case registrationFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return String(localized: "Notification permission was not granted.")
        case let .registrationFailed(message):
            return message
        }
    }
}

@MainActor
final class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()

    @Published private(set) var deviceToken: String?
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var registrationError: String?

    private var tokenContinuations: [CheckedContinuation<String, Error>] = []

    func requestDeviceToken() async throws -> String {
        if let deviceToken {
            return deviceToken
        }

        UNUserNotificationCenter.current().delegate = self

        let granted = try await requestAuthorization()
        let settings = await notificationSettings()
        authorizationStatus = settings.authorizationStatus

        guard granted || settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            throw PushNotificationError.permissionDenied
        }

        return try await withCheckedThrowingContinuation { continuation in
            tokenContinuations.append(continuation)
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func didRegisterForRemoteNotifications(deviceToken data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        deviceToken = token
        registrationError = nil
        resolveContinuations(.success(token))
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        registrationError = error.localizedDescription
        resolveContinuations(.failure(PushNotificationError.registrationFailed(error.localizedDescription)))
    }

    private func requestAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound, .timeSensitive]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func resolveContinuations(_ result: Result<String, Error>) {
        let continuations = tokenContinuations
        tokenContinuations.removeAll()

        for continuation in continuations {
            switch result {
            case let .success(token):
                continuation.resume(returning: token)
            case let .failure(error):
                continuation.resume(throwing: error)
            }
        }
    }
}

extension PushNotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}

final class SweepAlertAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationService.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationService.shared.didFailToRegisterForRemoteNotifications(error: error)
        }
    }
}
