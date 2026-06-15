import Foundation

struct RemoteCrewMember {
    let id: String
    let name: String
    let role: String
    let isCurrentUser: Bool
}

struct RemoteParkingSession {
    let id: String
    let status: String
    let latitude: Double
    let longitude: Double
    let corridor: String
    let side: String
    let ruleId: String
    let scheduleLabel: String
    let nextSweepAt: Date
    let parkedByName: String?
    let claimedByName: String?
    let claimedAt: Date?
    let movedByName: String?
    let movedAt: Date?
}

struct RemoteCrewCar {
    let id: String
    let name: String
    let color: String
    let activeSession: RemoteParkingSession?
}

struct RemoteCrewSnapshot {
    let id: String
    let name: String
    let carName: String
    let members: [RemoteCrewMember]
    let cars: [RemoteCrewCar]
}

struct ConvexService {
    enum ConvexServiceError: LocalizedError {
        case invalidResponse
        case httpStatus(Int, String)
        case functionError(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Convex returned an invalid response."
            case let .httpStatus(status, message):
                return "Convex request failed with HTTP \(status): \(message)"
            case let .functionError(message):
                return message
            }
        }
    }

    func upsertCurrentUser(idToken: String) async throws {
        _ = try await mutation(path: "users:upsertCurrentUser", args: [:], idToken: idToken)
    }

    func registerDevice(pushToken: String, idToken: String) async throws {
        _ = try await mutation(
            path: "cars:registerDevice",
            args: [
                "platform": "ios",
                "pushToken": pushToken,
                "timezone": TimeZone.current.identifier,
                "environment": AppConfiguration.apnsEnvironment
            ],
            idToken: idToken
        )
    }

    func updateNotificationPreferences(
        crewId: String,
        pushAlerts: Bool,
        claimUpdates: Bool,
        firstReminderHours: Double,
        idToken: String
    ) async throws {
        _ = try await mutation(
            path: "cars:updateNotificationPreferences",
            args: [
                "crewId": crewId,
                "pushAlerts": pushAlerts,
                "claimUpdates": claimUpdates,
                "firstReminderHours": firstReminderHours
            ],
            idToken: idToken
        )
    }

    func ensureDefaultCrew(idToken: String) async throws -> RemoteCrewSnapshot {
        let value = try await mutation(
            path: "cars:ensureDefaultCrew",
            args: ["name": "Apartment car crew"],
            idToken: idToken
        )
        return try parseCrewSnapshot(value)
    }

    func createInvite(crewId: String, idToken: String) async throws -> URL {
        let value = try await mutation(path: "cars:createInvite", args: ["crewId": crewId], idToken: idToken)
        guard let object = value as? [String: Any],
              let urlString = object["url"] as? String,
              let url = URL(string: urlString) else {
            throw ConvexServiceError.invalidResponse
        }
        return url
    }

    func acceptInvite(token: String, idToken: String) async throws -> RemoteCrewSnapshot {
        let value = try await mutation(path: "cars:acceptInvite", args: ["token": token], idToken: idToken)
        return try parseCrewSnapshot(value)
    }

    func createCar(name: String, crewId: String, color: String, idToken: String) async throws -> RemoteCrewSnapshot {
        let value = try await mutation(
            path: "cars:createCar",
            args: ["crewId": crewId, "name": name, "color": color],
            idToken: idToken
        )
        return try parseCrewSnapshot(value)
    }

    func renameCrew(crewId: String, name: String, idToken: String) async throws -> RemoteCrewSnapshot {
        let value = try await mutation(
            path: "cars:renameCrew",
            args: ["crewId": crewId, "name": name],
            idToken: idToken
        )
        return try parseCrewSnapshot(value)
    }

    func renameCar(carId: String, name: String, idToken: String) async throws -> RemoteCrewSnapshot {
        let value = try await mutation(
            path: "cars:renameCar",
            args: ["carId": carId, "name": name],
            idToken: idToken
        )
        return try parseCrewSnapshot(value)
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
        firstReminderHours: Double,
        idToken: String
    ) async throws -> RemoteCrewSnapshot {
        let value = try await mutation(
            path: "cars:parkCar",
            args: [
                "carId": carId,
                "latitude": latitude,
                "longitude": longitude,
                "corridor": corridor,
                "side": side,
                "ruleId": ruleId,
                "scheduleLabel": scheduleLabel,
                "nextSweepAt": nextSweepAt.timeIntervalSince1970 * 1000,
                "firstReminderHours": firstReminderHours
            ],
            idToken: idToken
        )
        return try parseCrewSnapshot(value)
    }

    func claimMove(parkingSessionId: String, idToken: String) async throws -> RemoteCrewSnapshot {
        let value = try await mutation(
            path: "cars:claimMove",
            args: ["parkingSessionId": parkingSessionId],
            idToken: idToken
        )
        return try parseCrewSnapshot(value)
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
        firstReminderHours: Double,
        idToken: String
    ) async throws -> RemoteCrewSnapshot {
        let value = try await mutation(
            path: "cars:completeMove",
            args: [
                "previousParkingSessionId": previousParkingSessionId,
                "latitude": latitude,
                "longitude": longitude,
                "corridor": corridor,
                "side": side,
                "ruleId": ruleId,
                "scheduleLabel": scheduleLabel,
                "nextSweepAt": nextSweepAt.timeIntervalSince1970 * 1000,
                "firstReminderHours": firstReminderHours
            ],
            idToken: idToken
        )
        return try parseCrewSnapshot(value)
    }

    private func mutation(path: String, args: [String: Any], idToken: String) async throws -> Any {
        let url = AppConfiguration.convexURL.appending(path: "api/mutation")
        let payload: [String: Any] = [
            "path": path,
            "format": "convex_encoded_json",
            "args": [args]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ios-sweep-alert", forHTTPHeaderField: "Convex-Client")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConvexServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) || httpResponse.statusCode == 560 else {
            throw ConvexServiceError.httpStatus(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? String else {
            throw ConvexServiceError.invalidResponse
        }

        if status == "success" {
            return json["value"] ?? NSNull()
        }

        throw ConvexServiceError.functionError((json["errorMessage"] as? String) ?? "Convex function failed.")
    }

    private func parseCrewSnapshot(_ value: Any) throws -> RemoteCrewSnapshot {
        guard let object = value as? [String: Any],
              let id = stringValue(object["id"]),
              let name = object["name"] as? String,
              let carName = object["carName"] as? String,
              let membersValue = object["members"] as? [[String: Any]] else {
            throw ConvexServiceError.invalidResponse
        }

        let members = membersValue.compactMap { member -> RemoteCrewMember? in
            guard let memberId = stringValue(member["id"]),
                  let memberName = member["name"] as? String,
                  let role = member["role"] as? String,
                  let isCurrentUser = member["isCurrentUser"] as? Bool else {
                return nil
            }

            return RemoteCrewMember(id: memberId, name: memberName, role: role, isCurrentUser: isCurrentUser)
        }

        let carsValue = object["cars"] as? [[String: Any]] ?? []
        let cars = carsValue.compactMap(parseCrewCar)

        return RemoteCrewSnapshot(id: id, name: name, carName: carName, members: members, cars: cars)
    }

    private func parseCrewCar(_ car: [String: Any]) -> RemoteCrewCar? {
        guard let id = stringValue(car["id"]),
              let name = car["name"] as? String else {
            return nil
        }

        let color = car["color"] as? String ?? "blue"
        let session = (car["activeSession"] as? [String: Any]).flatMap { parseParkingSession($0) }
        return RemoteCrewCar(id: id, name: name, color: color, activeSession: session)
    }

    private func parseParkingSession(_ session: [String: Any]) -> RemoteParkingSession? {
        guard let id = stringValue(session["id"]),
              let status = session["status"] as? String,
              let latitude = doubleValue(session["latitude"]),
              let longitude = doubleValue(session["longitude"]),
              let corridor = session["corridor"] as? String,
              let side = session["side"] as? String,
              let ruleId = session["ruleId"] as? String,
              let scheduleLabel = session["scheduleLabel"] as? String,
              let nextSweepAtMilliseconds = doubleValue(session["nextSweepAt"]) else {
            return nil
        }

        return RemoteParkingSession(
            id: id,
            status: status,
            latitude: latitude,
            longitude: longitude,
            corridor: corridor,
            side: side,
            ruleId: ruleId,
            scheduleLabel: scheduleLabel,
            nextSweepAt: Date(timeIntervalSince1970: nextSweepAtMilliseconds / 1000),
            parkedByName: session["parkedByName"] as? String,
            claimedByName: session["claimedByName"] as? String,
            claimedAt: dateFromMilliseconds(session["claimedAt"]),
            movedByName: session["movedByName"] as? String,
            movedAt: dateFromMilliseconds(session["movedAt"])
        )
    }

    private func stringValue(_ value: Any?) -> String? {
        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private func dateFromMilliseconds(_ value: Any?) -> Date? {
        if let number = doubleValue(value) {
            return Date(timeIntervalSince1970: number / 1000)
        }
        return nil
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? Double {
            return number
        }
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        return nil
    }
}
