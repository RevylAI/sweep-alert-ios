import CoreLocation
import Foundation
import MapKit
import SwiftUI
import UserNotifications

struct SweepSegment: Decodable, Identifiable {
    let id: String
    let corridor: String
    let limits: String
    let side: String
    let schedule: String
    let day: Int
    let fromHour: Int
    let toHour: Int
    let weeks: [Int]
    let coords: [[Double]]

    var coordinate: CLLocationCoordinate2D {
        guard let first = coords.first, first.count >= 2 else {
            return sfCoordinate
        }
        return CLLocationCoordinate2D(latitude: first[0], longitude: first[1])
    }
}

struct ParkedLocation {
    let coordinate: CLLocationCoordinate2D
    let droppedAt: Date
}

struct CarParkingSession {
    let id: String
    let status: String
    let coordinate: CLLocationCoordinate2D
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

struct CrewCar: Identifiable {
    let id: String
    var name: String
    var tint: Color
    var colorName: String
    var activeSession: CarParkingSession?
}

struct CrewMember: Identifiable {
    let id: String
    let name: String
    let role: String
    let tint: Color
    let isCurrentUser: Bool
}

struct SharedCarCrew {
    let id: String
    var name: String
    var carName: String
    var cars: [CrewCar]
    var members: [CrewMember]

    var currentMemberName: String {
        members.first { $0.isCurrentUser }?.name ?? "You"
    }

    static let empty = SharedCarCrew(
        id: "signed-out",
        name: "Your car crew",
        carName: "Shared car",
        cars: [],
        members: []
    )

    static let demo = SharedCarCrew(
        id: "roommates-honda",
        name: "Apartment car crew",
        carName: "Roommates' Honda",
        cars: [
            CrewCar(id: "roommates-honda", name: "Roommates' Honda", tint: sweepBlue, colorName: "blue", activeSession: nil),
            CrewCar(id: "maya-subaru", name: "Maya's Subaru", tint: Color.green, colorName: "green", activeSession: nil)
        ],
        members: [
            CrewMember(id: "landseer", name: "Landseer", role: "Owner", tint: sweepBlue, isCurrentUser: true),
            CrewMember(id: "anam", name: "Anam", role: "Can move", tint: Color.green, isCurrentUser: false),
            CrewMember(id: "maya", name: "Maya", role: "Can move", tint: Color.orange, isCurrentUser: false)
        ]
    )
}

struct MoveClaim {
    let memberName: String
    let claimedAt: Date
}

struct MoveActivity {
    let memberName: String
    let movedAt: Date
}

struct NotificationPreferences: Equatable {
    var pushAlerts = true
    var claimUpdates = true
    var firstReminderHours = 12.0
}

struct SweepRule: Identifiable {
    let segment: SweepSegment
    let distanceMeters: CLLocationDistance
    let sideScore: Double
    let nextOccurrence: Date
    let hoursUntil: Double

    var id: String { segment.id }
}

private struct NearbySegment {
    let segment: SweepSegment
    let distanceMeters: CLLocationDistance
    let sideScore: Double
}

private struct LineProjection {
    let distanceMeters: CLLocationDistance
    let offsetX: Double
    let offsetY: Double
}

@MainActor
final class LocationStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var locationReady = false
    @Published var userCoordinate: CLLocationCoordinate2D?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationReady = true
        @unknown default:
            locationReady = true
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .denied, .restricted:
                self.locationReady = true
            case .notDetermined:
                break
            @unknown default:
                self.locationReady = true
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.userCoordinate = location.coordinate
            self.locationReady = true
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationReady = true
        }
    }
}

private let sfCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
private let searchRadiusMeters: CLLocationDistance = 60
private let sweepBlue = Color(red: 0.05, green: 0.39, blue: 0.90)
private let sweepInk = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1)
        : UIColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1)
})
private let sweepMuted = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.62, green: 0.66, blue: 0.72, alpha: 1)
        : UIColor(red: 0.38, green: 0.43, blue: 0.50, alpha: 1)
})
private let sweepCardStroke = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark
        ? UIColor.white.withAlphaComponent(0.12)
        : UIColor.white.withAlphaComponent(0.58)
})

private let fallbackSweepSegments = [
    SweepSegment(
        id: "1640782",
        corridor: "Market St",
        limits: "Larkin St - Polk St",
        side: "SouthEast",
        schedule: "Tuesday",
        day: 2,
        fromHour: 5,
        toHour: 6,
        weeks: [1, 1, 1, 1, 1],
        coords: [[37.777494, -122.416292], [37.777410, -122.416317], [37.776561, -122.417392]]
    ),
    SweepSegment(
        id: "1622348",
        corridor: "Gough St",
        limits: "Hayes St - Ivy St",
        side: "East",
        schedule: "Tuesday",
        day: 2,
        fromHour: 0,
        toHour: 6,
        weeks: [1, 1, 1, 1, 1],
        coords: [[37.776884, -122.422978], [37.777349, -122.423073]]
    )
]

private enum SweepDataStore {
    static func loadSegments() -> [SweepSegment] {
        guard let url = Bundle.main.url(forResource: "sweeping", withExtension: "json") else {
            return fallbackSweepSegments
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([SweepSegment].self, from: data)
        } catch {
            return fallbackSweepSegments
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var authentication: AuthenticationService
    @StateObject private var locationStore = LocationStore()
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: sfCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var parkedPin: ParkedLocation?
    @State private var rules: [SweepRule]?
    @State private var selectedSide: String?
    @State private var sideWasOverridden = false
    @State private var rulesLoading = false
    @State private var settingsPresented = false
    @State private var invitePresented = false
    @State private var carCrew = SharedCarCrew.empty
    @State private var selectedCarId = ""
    @State private var notificationPreferences = NotificationPreferences()
    @State private var moveClaim: MoveClaim?
    @State private var lastMoveActivity: MoveActivity?
    @State private var activeParkingSessionId: String?
    @State private var activeParkingSessionIsRemote = false
    @State private var isReparking = false
    @State private var inviteURL = URL(string: "https://getsweepalert.com/invite/roommates-honda")!
    @State private var pendingInviteToken: String?
    @State private var statusMessage: String?
    @State private var rulesSheetExpanded = true

    var body: some View {
        ZStack(alignment: .top) {
            mapView
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer()
            }

            VStack {
                Spacer()

                if authentication.isAuthenticated
                    && locationStore.locationReady
                    && parkedPin == nil
                    && !rulesLoading
                    && !isReparking
                    && !carCrew.cars.isEmpty {
                    parkHereButton
                        .padding(.bottom, 28)
                }

                if !authentication.isAuthenticated {
                    SignedOutPanel(
                        isLoading: authentication.isLoading,
                        onSignIn: signIn,
                        onOpenSettings: {
                            settingsPresented = true
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if carCrew.cars.isEmpty && !rulesLoading {
                    EmptyCrewPanel(
                        crewName: carCrew.name,
                        onOpenSettings: {
                            settingsPresented = true
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if isReparking {
                    ReparkMapControls(
                        carName: selectedCar?.name ?? carCrew.carName,
                        onUseCurrentLocation: useCurrentLocationForRepark,
                        onCancel: cancelRepark
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if parkedPin != nil || rulesLoading || !carCrew.cars.isEmpty {
                    RulesSheet(
                        cars: carCrew.cars,
                        selectedCarId: selectedCarId,
                        rules: rules,
                        loading: rulesLoading,
                        selectedSide: selectedSide,
                        sideSelectionIsAutomatic: !sideWasOverridden,
                        carCrew: carCrew,
                        moveClaim: moveClaim,
                        lastMoveActivity: lastMoveActivity,
                        isReparking: isReparking,
                        isExpanded: rulesSheetExpanded,
                        onToggleExpanded: {
                            rulesSheetExpanded.toggle()
                        },
                        onSelectCar: selectCar,
                        onSelectSide: selectSide,
                        onClaimMove: claimMove,
                        onBeginRepark: beginRepark,
                        onUseCurrentLocationForRepark: useCurrentLocationForRepark,
                        onCancelRepark: cancelRepark,
                        onClearPin: clearPin
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .background(Color(.systemGroupedBackground))
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: parkedPin != nil)
        .onAppear {
            locationStore.requestLocation()
        }
        .onReceive(locationStore.$userCoordinate) { newValue in
            guard let coordinate = newValue, parkedPin == nil else { return }
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
        }
        .overlay {
            if settingsPresented {
                SettingsScreen(
                    carCrew: carCrew,
                    authentication: authentication,
                    preferences: $notificationPreferences,
                    inviteURL: inviteURL,
                    onClose: { settingsPresented = false },
                    onInviteCrew: prepareInviteAndPresent,
                    onRenameCrew: renameCrew,
                    onAddCar: addCar,
                    onRenameCar: renameCar
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.92), value: settingsPresented)
        .sheet(isPresented: $invitePresented) {
            InviteSheet(carCrew: carCrew, inviteURL: inviteURL)
                .presentationDetents([.height(320), .medium])
        }
        .onOpenURL(perform: handleIncomingURL)
        .task {
            await loadBackendCrewIfPossible()
        }
        .onChange(of: authentication.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                Task {
                    await loadBackendCrewIfPossible()
                    await acceptPendingInviteIfPossible()
                }
            } else {
                resetCrewStateAfterSignOut()
            }
        }
        .alert("SweepAlert", isPresented: Binding(
            get: { statusMessage != nil },
            set: { isPresented in
                if !isPresented {
                    statusMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {
                statusMessage = nil
            }
        } message: {
            Text(statusMessage ?? "")
        }
    }

    private var selectedCar: CrewCar? {
        carCrew.cars.first { $0.id == selectedCarId } ?? carCrew.cars.first
    }

    private var selectedCarSession: CarParkingSession? {
        selectedCar?.activeSession
    }

    private var mapView: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                if let coordinate = locationStore.userCoordinate {
                    Marker("You are here", systemImage: "location.fill", coordinate: coordinate)
                        .tint(.blue)
                }

                if let parkedPin, !selectedSessionMatchesPendingPin {
                    Marker("Parked here", systemImage: "mappin.circle.fill", coordinate: parkedPin.coordinate)
                        .tint(.red)
                }

                if authentication.isAuthenticated {
                    ForEach(carCrew.cars) { car in
                        if let session = car.activeSession {
                            Annotation(car.name, coordinate: session.coordinate, anchor: .bottom) {
                                Button {
                                    selectCar(car.id)
                                } label: {
                                    CarMapMarker(car: car, isSelected: car.id == selectedCarId)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onTapGesture { point in
                if let coordinate = proxy.convert(point, from: .local) {
                    dropPin(at: coordinate)
                }
            }
        }
        .accessibilityLabel("San Francisco parking map")
    }

    private var selectedSessionMatchesPendingPin: Bool {
        guard let parkedPin, let session = selectedCarSession else {
            return false
        }
        return coordinateDistance(parkedPin.coordinate, session.coordinate) < 2
    }

    private var header: some View {
        HStack {
            Text("SweepAlert")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(sweepInk)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(sweepCardStroke, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.09), radius: 12, x: 0, y: 6)
                .accessibilityIdentifier("app-title-badge")

            Spacer()

            Button {
                settingsPresented = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(sweepInk)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(sweepCardStroke, lineWidth: 1)
                    }
            }
            .shadow(color: .black.opacity(0.09), radius: 12, x: 0, y: 6)
            .accessibilityLabel("Open settings")
            .accessibilityIdentifier("settings-button")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var parkHereButton: some View {
        Button {
            let coordinate = locationStore.userCoordinate ?? sfCoordinate
            dropPin(at: coordinate)
        } label: {
            Label("Park Here", systemImage: "mappin.circle.fill")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(sweepBlue)
                .clipShape(Capsule())
                .shadow(color: sweepBlue.opacity(0.30), radius: 14, x: 0, y: 8)
        }
        .accessibilityIdentifier("park-here-button")
    }

    private func signIn() {
        Task {
            await authentication.login()
            await loadBackendCrewIfPossible()
            await acceptPendingInviteIfPossible()
        }
    }

    private func resetCrewStateAfterSignOut() {
        carCrew = .empty
        selectedCarId = ""
        parkedPin = nil
        rules = nil
        selectedSide = nil
        sideWasOverridden = false
        moveClaim = nil
        lastMoveActivity = nil
        activeParkingSessionId = nil
        activeParkingSessionIsRemote = false
        isReparking = false
        rulesSheetExpanded = true
    }

    private func dropPin(at coordinate: CLLocationCoordinate2D) {
        guard authentication.isAuthenticated else {
            statusMessage = "Sign in to create or join a car crew before setting a parking spot."
            settingsPresented = true
            return
        }

        guard let car = selectedCar else {
            statusMessage = "Add a car before setting a parking spot."
            settingsPresented = true
            return
        }

        let previousRemoteSessionId = car.activeSession?.id ?? (activeParkingSessionIsRemote ? activeParkingSessionId : nil)
        rulesSheetExpanded = true
        parkedPin = ParkedLocation(coordinate: coordinate, droppedAt: Date())
        rules = nil
        selectedSide = nil
        sideWasOverridden = false
        lastMoveActivity = previousRemoteSessionId != nil
            ? MoveActivity(memberName: carCrew.currentMemberName, movedAt: Date())
            : nil
        moveClaim = nil
        isReparking = false
        activeParkingSessionId = UUID().uuidString
        activeParkingSessionIsRemote = false
        lookupRules(near: coordinate, carId: car.id, previousRemoteSessionId: previousRemoteSessionId)
    }

    private func clearPin() {
        parkedPin = nil
        rules = nil
        selectedSide = nil
        sideWasOverridden = false
        moveClaim = nil
        lastMoveActivity = nil
        isReparking = false
        activeParkingSessionId = nil
        activeParkingSessionIsRemote = false
        rulesSheetExpanded = true
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [localReminderNotificationIdentifier])
    }

    private func selectSide(_ side: String) {
        selectedSide = side
        sideWasOverridden = true
        if let rules, let first = firstRule(in: rules, side: side) {
            scheduleNotificationIfEnabled(for: first)
            if let coordinate = parkedPin?.coordinate, let carId = selectedCar?.id {
                syncParkingSession(rule: first, coordinate: coordinate, carId: carId)
            }
        }
    }

    private func claimMove() {
        let claim = MoveClaim(memberName: carCrew.currentMemberName, claimedAt: Date())
        moveClaim = claim
        isReparking = true
        rulesSheetExpanded = false
        guard let parkingSessionId = selectedCarSession?.id ?? activeParkingSessionId else {
            return
        }
        guard authentication.isAuthenticated else {
            return
        }
        Task {
            do {
                let remoteCrew = try await authentication.claimMove(parkingSessionId: parkingSessionId)
                applyRemoteCrew(remoteCrew, preferredCarId: selectedCarId)
                moveClaim = claim
                isReparking = true
                rulesSheetExpanded = false
            } catch {
                authentication.errorMessage = "Move claim sync failed: \(error.localizedDescription)"
            }
        }
    }

    private func beginRepark() {
        if moveClaim == nil {
            moveClaim = MoveClaim(memberName: carCrew.currentMemberName, claimedAt: Date())
        }
        isReparking = true
        rulesSheetExpanded = false
    }

    private func useCurrentLocationForRepark() {
        let coordinate = locationStore.userCoordinate ?? parkedPin?.coordinate ?? sfCoordinate
        dropPin(at: coordinate)
    }

    private func cancelRepark() {
        moveClaim = nil
        isReparking = false
        rulesSheetExpanded = true
    }

    private func scheduleNotificationIfEnabled(for rule: SweepRule) {
        guard notificationPreferences.pushAlerts else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [localReminderNotificationIdentifier])
            return
        }

        guard !authentication.isAuthenticated else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [localReminderNotificationIdentifier])
            return
        }

        var notificationCrew = carCrew
        notificationCrew.carName = selectedCar?.name ?? carCrew.carName
        scheduleNotification(for: rule, crew: notificationCrew, preferences: notificationPreferences)
    }

    private func lookupRules(
        near coordinate: CLLocationCoordinate2D,
        carId: String? = nil,
        previousRemoteSessionId: String? = nil,
        shouldSync: Bool = true,
        preferredSide: String? = nil
    ) {
        rulesLoading = true
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            let sweepRules = await Task.detached(priority: .userInitiated) {
                buildSweepRules(latitude: latitude, longitude: longitude, from: Date())
            }.value

            guard !Task.isCancelled else {
                return
            }

            let initialSide = preferredSide ?? bestSide(in: sweepRules)
            rules = sweepRules
            selectedSide = initialSide
            sideWasOverridden = preferredSide != nil
            rulesLoading = false

            if let first = firstRule(in: sweepRules, side: initialSide) {
                scheduleNotificationIfEnabled(for: first)
                if shouldSync, let carId {
                    syncParkingSession(
                        rule: first,
                        coordinate: coordinate,
                        carId: carId,
                        previousRemoteSessionId: previousRemoteSessionId
                    )
                }
            }
        }
    }

    private func loadBackendCrewIfPossible() async {
        guard authentication.isAuthenticated else {
            return
        }

        do {
            let remoteCrew = try await authentication.ensureDefaultCrew()
            applyRemoteCrew(remoteCrew, preferredCarId: selectedCarId)
        } catch {
            authentication.errorMessage = "Crew sync failed: \(error.localizedDescription)"
        }
    }

    private func prepareInviteAndPresent() {
        guard authentication.isAuthenticated else {
            settingsPresented = true
            statusMessage = "Sign in before creating a car crew invite link."
            return
        }

        Task {
            do {
                inviteURL = try await authentication.createInviteURL()
                invitePresented = true
            } catch {
                statusMessage = "Could not create invite: \(error.localizedDescription)"
            }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard let token = inviteToken(from: url), !token.isEmpty else {
            return
        }

        pendingInviteToken = token
        if authentication.isAuthenticated {
            Task {
                await acceptPendingInviteIfPossible()
            }
        } else {
            settingsPresented = true
            statusMessage = "Sign in to accept this car crew invite."
        }
    }

    private func acceptPendingInviteIfPossible() async {
        guard authentication.isAuthenticated, let token = pendingInviteToken else {
            return
        }

        do {
            let remoteCrew = try await authentication.acceptInvite(token: token)
            applyRemoteCrew(remoteCrew, preferredCarId: remoteCrew.cars.first?.id)
            pendingInviteToken = nil
            statusMessage = "Joined \(remoteCrew.name)."
        } catch {
            statusMessage = "Could not accept invite: \(error.localizedDescription)"
        }
    }

    private func syncParkingSession(
        rule: SweepRule,
        coordinate: CLLocationCoordinate2D,
        carId: String,
        previousRemoteSessionId: String? = nil
    ) {
        guard authentication.isAuthenticated else {
            return
        }

        Task {
            do {
                let scheduleLabel = "\(rule.segment.schedule) \(formatTimeWindow(fromHour: rule.segment.fromHour, toHour: rule.segment.toHour))"
                let remoteCrew: RemoteCrewSnapshot
                if let previousRemoteSessionId {
                    remoteCrew = try await authentication.completeMove(
                        previousParkingSessionId: previousRemoteSessionId,
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        corridor: rule.segment.corridor,
                        side: rule.segment.side,
                        ruleId: rule.segment.id,
                        scheduleLabel: scheduleLabel,
                        nextSweepAt: rule.nextOccurrence,
                        firstReminderHours: notificationPreferences.firstReminderHours
                    )
                } else {
                    remoteCrew = try await authentication.parkCar(
                        carId: carId,
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        corridor: rule.segment.corridor,
                        side: rule.segment.side,
                        ruleId: rule.segment.id,
                        scheduleLabel: scheduleLabel,
                        nextSweepAt: rule.nextOccurrence,
                        firstReminderHours: notificationPreferences.firstReminderHours
                    )
                }

                applyRemoteCrew(remoteCrew, preferredCarId: carId)
                activeParkingSessionId = selectedCarSession?.id
                activeParkingSessionIsRemote = true
            } catch {
                authentication.errorMessage = "Parking sync failed: \(error.localizedDescription)"
            }
        }
    }

    private func inviteToken(from url: URL) -> String? {
        if url.scheme == "https", url.host == "getsweepalert.com" {
            let parts = url.pathComponents.filter { $0 != "/" }
            guard parts.first == "invite" else { return nil }
            return parts.dropFirst().first
        }

        if url.scheme == AppConfiguration.bundleIdentifier, url.host == "invite" {
            return url.pathComponents.filter { $0 != "/" }.first
        }

        return nil
    }

    private func selectCar(_ carId: String) {
        selectedCarId = carId
        showParkingStateForSelectedCar()
        focusCameraOnCrewCars()
    }

    private func showParkingStateForSelectedCar() {
        guard let car = selectedCar else {
            parkedPin = nil
            rules = nil
            activeParkingSessionId = nil
            activeParkingSessionIsRemote = false
            return
        }

        guard let session = car.activeSession else {
            parkedPin = nil
            rules = nil
            selectedSide = nil
            sideWasOverridden = false
            moveClaim = nil
            lastMoveActivity = nil
            activeParkingSessionId = nil
            activeParkingSessionIsRemote = false
            return
        }

        parkedPin = ParkedLocation(coordinate: session.coordinate, droppedAt: Date())
        activeParkingSessionId = session.id
        activeParkingSessionIsRemote = true
        moveClaim = session.status == "claimed"
            ? MoveClaim(memberName: session.claimedByName ?? "Someone", claimedAt: session.claimedAt ?? Date())
            : nil
        lastMoveActivity = session.movedByName.flatMap { name in
            MoveActivity(memberName: name, movedAt: session.movedAt ?? Date())
        }
        if !isReparking {
            rulesSheetExpanded = true
        }
        lookupRules(
            near: session.coordinate,
            carId: car.id,
            shouldSync: false,
            preferredSide: session.side
        )
    }

    private func applyRemoteCrew(_ remoteCrew: RemoteCrewSnapshot, preferredCarId: String?) {
        carCrew = sharedCarCrew(from: remoteCrew)
        if let preferredCarId, carCrew.cars.contains(where: { $0.id == preferredCarId }) {
            selectedCarId = preferredCarId
        } else if !carCrew.cars.contains(where: { $0.id == selectedCarId }) {
            selectedCarId = carCrew.cars.first?.id ?? selectedCarId
        }
        showParkingStateForSelectedCar()
        focusCameraOnCrewCars()
    }

    private func focusCameraOnCrewCars() {
        let coordinates = carCrew.cars.compactMap { $0.activeSession?.coordinate }
        guard let region = mapRegion(containing: coordinates) else {
            return
        }
        cameraPosition = .region(region)
    }

    private func renameCrew(_ name: String) {
        guard authentication.isAuthenticated else {
            statusMessage = "Sign in before renaming your crew."
            return
        }
        Task {
            do {
                let remoteCrew = try await authentication.renameCrew(name: name)
                applyRemoteCrew(remoteCrew, preferredCarId: selectedCarId)
            } catch {
                statusMessage = "Could not rename crew: \(error.localizedDescription)"
            }
        }
    }

    private func addCar(_ name: String) {
        guard authentication.isAuthenticated else {
            statusMessage = "Sign in before adding another car."
            return
        }
        Task {
            do {
                let color = nextCarColorName(index: carCrew.cars.count)
                let remoteCrew = try await authentication.createCar(name: name, color: color)
                applyRemoteCrew(remoteCrew, preferredCarId: remoteCrew.cars.last?.id)
            } catch {
                statusMessage = "Could not add car: \(error.localizedDescription)"
            }
        }
    }

    private func renameCar(_ carId: String, _ name: String) {
        guard authentication.isAuthenticated else {
            statusMessage = "Sign in before renaming cars."
            return
        }
        Task {
            do {
                let remoteCrew = try await authentication.renameCar(carId: carId, name: name)
                applyRemoteCrew(remoteCrew, preferredCarId: carId)
            } catch {
                statusMessage = "Could not rename car: \(error.localizedDescription)"
            }
        }
    }

    private func sharedCarCrew(from remoteCrew: RemoteCrewSnapshot) -> SharedCarCrew {
        let palette: [Color] = [sweepBlue, Color.green, Color.orange, Color.purple, Color.teal]
        let members = remoteCrew.members.enumerated().map { index, member in
            CrewMember(
                id: member.id,
                name: member.name,
                role: member.role == "owner" ? "Owner" : "Can move",
                tint: palette[index % palette.count],
                isCurrentUser: member.isCurrentUser
            )
        }
        let cars = remoteCrew.cars.enumerated().map { index, car in
            CrewCar(
                id: car.id,
                name: car.name,
                tint: colorForCarName(car.color, fallbackIndex: index),
                colorName: car.color,
                activeSession: car.activeSession.map { localParkingSession(from: $0) }
            )
        }

        return SharedCarCrew(
            id: remoteCrew.id,
            name: remoteCrew.name,
            carName: cars.first?.name ?? remoteCrew.carName,
            cars: cars,
            members: members
        )
    }

    private func localParkingSession(from remote: RemoteParkingSession) -> CarParkingSession {
        CarParkingSession(
            id: remote.id,
            status: remote.status,
            coordinate: CLLocationCoordinate2D(latitude: remote.latitude, longitude: remote.longitude),
            corridor: remote.corridor,
            side: remote.side,
            ruleId: remote.ruleId,
            scheduleLabel: remote.scheduleLabel,
            nextSweepAt: remote.nextSweepAt,
            parkedByName: remote.parkedByName,
            claimedByName: remote.claimedByName,
            claimedAt: remote.claimedAt,
            movedByName: remote.movedByName,
            movedAt: remote.movedAt
        )
    }
}

struct RulesSheet: View {
    let cars: [CrewCar]
    let selectedCarId: String
    let rules: [SweepRule]?
    let loading: Bool
    let selectedSide: String?
    let sideSelectionIsAutomatic: Bool
    let carCrew: SharedCarCrew
    let moveClaim: MoveClaim?
    let lastMoveActivity: MoveActivity?
    let isReparking: Bool
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onSelectCar: (String) -> Void
    let onSelectSide: (String) -> Void
    let onClaimMove: () -> Void
    let onBeginRepark: () -> Void
    let onUseCurrentLocationForRepark: () -> Void
    let onCancelRepark: () -> Void
    let onClearPin: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                sheetCloseBar
                carSwitcher

                if loading {
                    loadingContent
                } else if let rules, rules.isEmpty {
                    noRulesContent
                } else if let rules {
                    rulesContent(rules)
                } else {
                    Text("Tap the map to drop your parking pin")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(sweepMuted)
                        .padding(.top, 24)
                        .padding(.bottom, 32)
                }
            } else {
                Button(action: onToggleExpanded) {
                    collapsedContent
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Expand parking details")
                .accessibilityIdentifier("rules-sheet-expand-button")
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            Color(.systemBackground)
                .opacity(isExpanded ? 0.96 : 0.98)
                .ignoresSafeArea(edges: .bottom)
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: isExpanded ? 28 : 22, topTrailingRadius: isExpanded ? 28 : 22))
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: isExpanded ? 28 : 22, topTrailingRadius: isExpanded ? 28 : 22)
                .stroke(sweepCardStroke, lineWidth: 1)
        }
        .shadow(color: .black.opacity(isExpanded ? 0.16 : 0.10), radius: isExpanded ? 20 : 14, x: 0, y: -8)
        .accessibilityIdentifier("rules-sheet")
        .ignoresSafeArea(edges: .bottom)
    }

    private var selectedCar: CrewCar? {
        cars.first { $0.id == selectedCarId } ?? cars.first
    }

    private var sheetCloseBar: some View {
        HStack {
            Spacer()

            Button(action: onToggleExpanded) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(sweepInk)
                    .frame(width: 34, height: 34)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Collapse parking details")
            .accessibilityIdentifier("rules-sheet-collapse-button")
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private var collapsedContent: some View {
        if loading {
            collapsedRow(
                title: "Reading curb rules",
                subtitle: "Checking nearby sweeping schedules",
                icon: "location.magnifyingglass",
                color: sweepBlue
            )
        } else if let rules, let top = primaryRule(in: rules) {
            collapsedRow(
                title: urgencyLabel(top.nextOccurrence),
                subtitle: ruleSummary(top),
                icon: top.hoursUntil < 12 ? "exclamationmark.triangle.fill" : "sparkles",
                color: urgencyColor(top.hoursUntil)
            )
        } else {
            collapsedRow(
                title: "No street cleaning found",
                subtitle: "Tap to review this parking spot",
                icon: "checkmark.circle.fill",
                color: Color.green
            )
        }
    }

    private func collapsedRow(title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(sweepInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(sweepMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.up")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(sweepMuted)
                .frame(width: 34, height: 34)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    private var loadingContent: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(sweepBlue.opacity(0.12))
                    .frame(width: 54, height: 54)

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(sweepBlue)
            }

            VStack(spacing: 4) {
                Text("Reading curb rules")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(sweepInk)

                Text("Checking nearby SF sweeping schedules...")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(sweepMuted)
            }
        }
        .frame(minHeight: 190)
    }

    private var noRulesContent: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Color.green)
                .padding(.top, 6)

            Text("No street cleaning found")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(sweepInk)

            Text("No sweeping schedule found near this spot. Double-check the pin is on the street.")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(sweepMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            clearButton("Clear Pin")
        }
        .padding(.bottom, 32)
    }

    private func rulesContent(_ rules: [SweepRule]) -> some View {
        let sideChoices = sideOptions(for: rules)
        let activeSide = selectedSide ?? sideChoices.first
        let filteredRules = rulesForSelectedSide(rules, side: activeSide)
        let visibleRules = filteredRules.isEmpty ? rules : filteredRules
        let top = visibleRules[0]
        let statusColor = urgencyColor(top.hoursUntil)

        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.16))
                        .frame(width: 54, height: 54)

                    Image(systemName: top.hoursUntil < 12 ? "exclamationmark.triangle.fill" : "sparkles")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(urgencyLabel(top.nextOccurrence))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(sweepInk)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(ruleSummary(top))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(sweepMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, sideChoices.count > 1 ? 16 : 18)

            if sideChoices.count > 1 {
                sideSelector(sideChoices, activeSide: activeSide)
                    .padding(.bottom, 16)
            }

            HStack {
                Text("Nearby rules")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(sweepInk)

                Spacer()

                Text("\(visibleRules.count) match\(visibleRules.count == 1 ? "" : "es") within \(Int(searchRadiusMeters))m")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(sweepMuted)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(visibleRules) { rule in
                        RuleRow(rule: rule)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 2)
            }
            .frame(maxHeight: 282)

            primaryGroupActions
        }
        .padding(.bottom, 28)
    }

    private var carSwitcher: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(carCrew.name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(sweepMuted)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(crewStatusText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(sweepMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer()

                HStack(spacing: 10) {
                    memberStack

                    Text("\(cars.count) car\(cars.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(sweepMuted)
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(cars) { car in
                        let isSelected = car.id == selectedCarId
                        Button {
                            onSelectCar(car.id)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: car.activeSession == nil ? "car" : "car.fill")
                                    .font(.system(size: 13, weight: .bold))
                                Text(car.name)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(isSelected ? .white : sweepInk)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(isSelected ? car.tint : Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 16)
    }

    private func primaryRule(in rules: [SweepRule]) -> SweepRule? {
        let sideChoices = sideOptions(for: rules)
        let activeSide = selectedSide ?? sideChoices.first
        let filteredRules = rulesForSelectedSide(rules, side: activeSide)
        return (filteredRules.isEmpty ? rules : filteredRules).first
    }

    private var crewStatusPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(sweepBlue)
                    .frame(width: 30, height: 30)
                    .background(sweepBlue.opacity(0.10))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedCar?.name ?? carCrew.carName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(sweepInk)

                    Text(crewStatusText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(sweepMuted)
                }

                Spacer(minLength: 8)

                memberStack
            }

        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.separator).opacity(0.28), lineWidth: 0.5)
        }
    }

    private var primaryGroupActions: some View {
        VStack(spacing: 8) {
            if isReparking {
                reparkActions
            } else if let moveClaim {
                moveClaimStatus(moveClaim)
            } else {
                Button(action: onClaimMove) {
                    Label(lastMoveActivity == nil ? "I'll move it" : "Move \(selectedCar?.name ?? "car") again", systemImage: "figure.walk")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(sweepBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: sweepBlue.opacity(0.18), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .accessibilityIdentifier("claim-move-button")
            }
        }
    }

    private var reparkActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(sweepBlue)

                Text("Where is it parked now?")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(sweepInk)

                Spacer(minLength: 8)
            }

            Text("Tap the map to place a new pin, or use your current location.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(sweepMuted)
                .lineLimit(2)

            HStack(spacing: 8) {
                Button(action: onUseCurrentLocationForRepark) {
                    Label("Use current", systemImage: "location.fill")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(sweepBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .accessibilityIdentifier("use-current-location-repark-button")

                Button(action: onCancelRepark) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(sweepInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.systemBackground).opacity(0.78))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .accessibilityIdentifier("cancel-repark-button")
            }
        }
        .padding(12)
        .background(sweepBlue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func moveClaimStatus(_ moveClaim: MoveClaim) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.green)

            Text("\(moveClaim.memberName) is moving it")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(sweepInk)

            Spacer(minLength: 8)

            Button(action: onBeginRepark) {
                Text("Choose spot")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(sweepBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(sweepBlue.opacity(0.10))
                    .clipShape(Capsule())
            }
            .accessibilityIdentifier("set-spot-after-claim-button")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var memberStack: some View {
        HStack(spacing: -8) {
            ForEach(carCrew.members.prefix(3)) { member in
                Text(memberInitials(member.name))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(member.tint)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    }
            }
        }
    }

    private var crewStatusText: String {
        if isReparking {
            return "\(carCrew.currentMemberName) is setting the new spot"
        }
        if let moveClaim {
            return "\(moveClaim.memberName) claimed this move"
        }
        if let lastMoveActivity {
            return "\(lastMoveActivity.memberName) moved it \(relativeMoveTime(lastMoveActivity.movedAt))"
        }
        return "\(carCrew.members.count) people get alerts"
    }

    private func sideSelector(_ sides: [String], activeSide: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Street side")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(sweepInk)

                Spacer()

                Text(sideSelectionIsAutomatic ? "Auto-selected" : "Changed")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(sweepMuted)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sides, id: \.self) { side in
                        let isSelected = side == activeSide
                        Button {
                            onSelectSide(side)
                        } label: {
                            Text(formatSide(side))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(isSelected ? .white : sweepInk)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(isSelected ? sweepBlue : Color(.systemBackground).opacity(0.82))
                                .clipShape(Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(isSelected ? sweepBlue : Color(.separator).opacity(0.4), lineWidth: 0.75)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func clearButton(_ title: String) -> some View {
        Button(action: onClearPin) {
            Label(title, systemImage: "car.fill")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(sweepBlue)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: sweepBlue.opacity(0.18), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .accessibilityIdentifier("clear-pin-button")
    }
}

struct ReparkMapControls: View {
    let carName: String
    let onUseCurrentLocation: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Set \(carName)'s new spot")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(sweepInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("Tap the map or use current location")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(sweepMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: onUseCurrentLocation) {
                Image(systemName: "location.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(sweepBlue)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Use current location")
            .accessibilityIdentifier("use-current-location-repark-button")

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(sweepInk)
                    .frame(width: 38, height: 38)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Cancel move")
            .accessibilityIdentifier("cancel-repark-button")
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(sweepCardStroke, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 16, x: 0, y: 8)
    }
}

struct SignedOutPanel: View {
    let isLoading: Bool
    let onSignIn: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "person.2.badge.key.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(sweepBlue)
                    .frame(width: 42, height: 42)
                    .background(sweepBlue.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Create your car crew")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("Sign in to save cars, share invite links, and sync alerts.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button(action: onSignIn) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 14, weight: .bold))
                        }

                        Text(isLoading ? "Checking account" : "Sign in")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isLoading)
                .accessibilityIdentifier("signed-out-login-button")

                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 46, height: 46)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .accessibilityLabel("Open settings")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground).opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(sweepCardStroke, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
    }
}

struct EmptyCrewPanel: View {
    let crewName: String
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "car.2.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(sweepBlue)
                .frame(width: 42, height: 42)
                .background(sweepBlue.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(crewName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(sweepInk)

                Text("Add a car in settings to start tracking parking spots.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(sweepMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onOpenSettings) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(sweepBlue)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Add a car")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground).opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(sweepCardStroke, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
    }
}

struct CarMapMarker: View {
    let car: CrewCar
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: isSelected ? 44 : 38, height: isSelected ? 44 : 38)
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)

                Circle()
                    .fill(car.tint)
                    .frame(width: isSelected ? 36 : 30, height: isSelected ? 36 : 30)

                Image(systemName: "car.fill")
                    .font(.system(size: isSelected ? 16 : 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            .overlay {
                Circle()
                    .stroke(isSelected ? sweepInk.opacity(0.18) : Color.clear, lineWidth: 3)
            }

            Text(car.name)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(sweepInk)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color(.systemBackground).opacity(0.92))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)
        }
        .accessibilityLabel("\(car.name) parking marker")
    }
}

struct RuleRow: View {
    let rule: SweepRule

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "road.lanes")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(sweepBlue)
                        .frame(width: 24, height: 24)
                        .background(sweepBlue.opacity(0.11))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(rule.segment.corridor)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(sweepInk)
                            .lineLimit(1)

                        Text(rule.segment.limits)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(sweepMuted)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 6) {
                    rowPill("\(formatSide(rule.segment.side)) side", systemImage: "arrow.left.and.right")
                    rowPill(formatDistance(rule.distanceMeters), systemImage: "scope")
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 5) {
                Text(rule.segment.schedule)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(sweepInk)
                    .lineLimit(1)

                Text(formatTimeWindow(fromHour: rule.segment.fromHour, toHour: rule.segment.toHour))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(sweepMuted)

                Text(formatDate(rule.nextOccurrence))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(urgencyColor(rule.hoursUntil))
            }
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 0.5)
        }
    }

    private func rowPill(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(sweepMuted)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemBackground))
            .clipShape(Capsule())
    }
}

struct SettingsScreen: View {
    let carCrew: SharedCarCrew
    @ObservedObject var authentication: AuthenticationService
    @Binding var preferences: NotificationPreferences
    let inviteURL: URL
    let onClose: () -> Void
    let onInviteCrew: () -> Void
    let onRenameCrew: (String) -> Void
    let onAddCar: (String) -> Void
    let onRenameCar: (String, String) -> Void
    @State private var crewNameDraft = ""
    @State private var newCarName = ""
    @State private var carNameDrafts: [String: String] = [:]

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    accountSection
                    if authentication.isAuthenticated {
                        notificationSection
                        crewSection
                    } else {
                        signedOutCrewSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .accessibilityIdentifier("settings-screen")
        .onChange(of: preferences) { _, newValue in
            syncNotificationPreferences(newValue)
        }
        .onAppear(perform: syncDrafts)
        .onChange(of: carCrew.name) { _, _ in syncDrafts() }
        .onChange(of: carCrew.cars.count) { _, _ in syncDrafts() }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(Color(.separator).opacity(0.28), lineWidth: 0.5)
                    }
            }
            .accessibilityLabel("Back")
            .accessibilityIdentifier("settings-back-button")

            Spacer()

            Text("Settings")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Spacer()

            if authentication.isAuthenticated {
                Button(action: onInviteCrew) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(sweepBlue)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Share invite link")
            } else {
                Color.clear
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Manage your crew, cars, shared alerts, and who can move them.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }

    private var accountSection: some View {
        settingsGroup(title: "Account") {
            HStack(spacing: 12) {
                Image(systemName: authentication.isAuthenticated ? "checkmark.seal.fill" : "person.crop.circle.badge.plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(authentication.isAuthenticated ? Color.green : sweepBlue)
                    .frame(width: 34, height: 34)
                    .background((authentication.isAuthenticated ? Color.green : sweepBlue).opacity(0.10))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(authentication.isAuthenticated ? "Signed in with Auth0" : "Sign in to sync alerts")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(accountSubtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if authentication.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        Task {
                            if authentication.isAuthenticated {
                                await authentication.logout()
                            } else {
                                await authentication.login()
                            }
                        }
                    } label: {
                        Text(authentication.isAuthenticated ? "Log out" : "Log in")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(authentication.isAuthenticated ? Color.primary : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(authentication.isAuthenticated ? Color(.secondarySystemBackground) : sweepBlue)
                            .clipShape(Capsule())
                    }
                    .accessibilityIdentifier(authentication.isAuthenticated ? "logout-button" : "login-button")
                }
            }

            if let message = authentication.errorMessage {
                Divider()

                Text(message)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var accountSubtitle: String {
        guard authentication.isAuthenticated else {
            return "Use Auth0 to join crews and receive shared car updates."
        }

        if authentication.convexSynced {
            return "\(authentication.userName ?? authentication.userEmail ?? "Your account") is connected to \(carCrew.name)."
        }

        return "Auth0 is connected. Waiting to sync with Convex."
    }

    private var notificationSection: some View {
        settingsGroup(title: "Notifications") {
            Toggle("Street cleaning alerts", isOn: $preferences.pushAlerts)
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Divider()

            Toggle("Crew claim updates", isOn: $preferences.claimUpdates)
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("First reminder")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(sweepInk)

                HStack(spacing: 8) {
                    reminderButton(hours: 6)
                    reminderButton(hours: 12)
                    reminderButton(hours: 24)
                }
            }
        }
    }

    private var signedOutCrewSection: some View {
        settingsGroup(title: "Crew") {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(sweepBlue)
                    .frame(width: 34, height: 34)
                    .background(sweepBlue.opacity(0.10))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign in to manage cars")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("Crew names, invite links, cars, and push alerts are stored after login.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var crewSection: some View {
        settingsGroup(title: "Crew") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Group name")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(sweepMuted)

                HStack(spacing: 8) {
                    TextField("Crew name", text: $crewNameDraft)
                        .textInputAutocapitalization(.words)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button {
                        onRenameCrew(crewNameDraft)
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(sweepBlue)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Save crew name")
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Cars")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(sweepMuted)

                    Spacer()

                    Text("\(carCrew.cars.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(sweepMuted)
                }

                ForEach(carCrew.cars) { car in
                    HStack(spacing: 10) {
                        Image(systemName: car.activeSession == nil ? "car" : "car.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(car.tint)
                            .clipShape(Circle())

                        TextField(car.name, text: Binding(
                            get: { carNameDrafts[car.id] ?? car.name },
                            set: { carNameDrafts[car.id] = $0 }
                        ))
                        .textInputAutocapitalization(.words)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Button {
                            onRenameCar(car.id, carNameDrafts[car.id] ?? car.name)
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(sweepBlue)
                                .frame(width: 34, height: 34)
                                .background(sweepBlue.opacity(0.10))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Save \(car.name)")
                    }
                }

                HStack(spacing: 8) {
                    TextField("Add another car", text: $newCarName)
                        .textInputAutocapitalization(.words)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button {
                        let name = newCarName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        onAddCar(name)
                        newCarName = ""
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(sweepBlue)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Add car")
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Members")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(sweepInk)

                    Text("\(carCrew.members.count) members can receive alerts")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(sweepMuted)
                }

                Spacer()

                Button(action: onInviteCrew) {
                    Label("Invite", systemImage: "link")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(sweepBlue)
                }
                .accessibilityIdentifier("settings-invite-button")
            }

            Divider()

            ForEach(carCrew.members) { member in
                HStack(spacing: 10) {
                    Text(memberInitials(member.name))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(member.tint)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.isCurrentUser ? "\(member.name) (you)" : member.name)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(sweepInk)

                        Text(member.role)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(sweepMuted)
                    }

                    Spacer()
                }
            }
        }
    }

    private func syncDrafts() {
        crewNameDraft = carCrew.name
        for car in carCrew.cars {
            carNameDrafts[car.id] = car.name
        }
    }

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(.separator).opacity(0.25), lineWidth: 0.5)
            }
        }
    }

    private func reminderButton(hours: Double) -> some View {
        let selected = preferences.firstReminderHours == hours
        return Button {
            preferences.firstReminderHours = hours
        } label: {
            Text(formatReminderLeadTime(hours))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? .white : sweepInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(selected ? sweepBlue : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func syncNotificationPreferences(_ preferences: NotificationPreferences) {
        guard authentication.isAuthenticated else {
            return
        }

        Task {
            do {
                try await authentication.updateNotificationPreferences(preferences)
            } catch {
                authentication.errorMessage = "Notification settings sync failed: \(error.localizedDescription)"
            }
        }
    }
}

struct InviteSheet: View {
    let carCrew: SharedCarCrew
    let inviteURL: URL

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color(.systemGray3))
                .frame(width: 44, height: 5)
                .padding(.top, 10)

            Image(systemName: "person.badge.plus.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(sweepBlue)
                .frame(width: 70, height: 70)
                .background(sweepBlue.opacity(0.12))
                .clipShape(Circle())

            VStack(spacing: 6) {
                Text("Invite to \(carCrew.name)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(sweepInk)
                    .multilineTextAlignment(.center)

                Text("Anyone with the app can join this crew and help manage every car.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(sweepMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            ShareLink(item: inviteURL) {
                Label("Share invite link", systemImage: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(sweepBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 24)
            .accessibilityIdentifier("share-invite-link-button")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground))
    }
}

private func buildSweepRules(latitude: Double, longitude: Double, from now: Date) -> [SweepRule] {
    findNearbySegments(latitude: latitude, longitude: longitude)
        .map { nearby in
            let next = nextSweepOccurrence(for: nearby.segment, from: now)
            return SweepRule(
                segment: nearby.segment,
                distanceMeters: nearby.distanceMeters,
                sideScore: nearby.sideScore,
                nextOccurrence: next,
                hoursUntil: hoursUntil(next, from: now)
            )
        }
}

private func bestSide(in rules: [SweepRule]) -> String? {
    sideOptions(for: rulesForDetectedStreet(rules)).first
}

private func firstRule(in rules: [SweepRule], side: String?) -> SweepRule? {
    let streetRules = rulesForDetectedStreet(rules)
    guard let side else {
        return streetRules.first ?? rules.first
    }
    return streetRules.first { $0.segment.side == side } ?? streetRules.first ?? rules.first
}

private func rulesForSelectedSide(_ rules: [SweepRule], side: String?) -> [SweepRule] {
    let streetRules = rulesForDetectedStreet(rules)
    guard let side else {
        return streetRules
    }
    return streetRules.filter { $0.segment.side == side }
}

private func sideOptions(for rules: [SweepRule]) -> [String] {
    var bestScoreBySide: [String: Double] = [:]
    var nearestDistanceBySide: [String: CLLocationDistance] = [:]
    for rule in rulesForDetectedStreet(rules) {
        let currentScore = bestScoreBySide[rule.segment.side] ?? -.infinity
        let currentDistance = nearestDistanceBySide[rule.segment.side] ?? .infinity
        if rule.sideScore > currentScore || (rule.sideScore == currentScore && rule.distanceMeters < currentDistance) {
            bestScoreBySide[rule.segment.side] = rule.sideScore
            nearestDistanceBySide[rule.segment.side] = rule.distanceMeters
        }
    }

    return nearestDistanceBySide.keys.sorted {
        let leftScore = bestScoreBySide[$0] ?? -.infinity
        let rightScore = bestScoreBySide[$1] ?? -.infinity
        if abs(leftScore - rightScore) > 0.001 {
            return leftScore > rightScore
        }

        let leftDistance = nearestDistanceBySide[$0] ?? .infinity
        let rightDistance = nearestDistanceBySide[$1] ?? .infinity
        if leftDistance == rightDistance {
            return $0 < $1
        }
        return leftDistance < rightDistance
    }
}

private func rulesForDetectedStreet(_ rules: [SweepRule]) -> [SweepRule] {
    guard let key = bestStreetKey(in: rules) else {
        return rules
    }
    let streetRules = rules.filter { streetKey(for: $0) == key }
    return streetRules.isEmpty ? rules : streetRules
}

private func bestStreetKey(in rules: [SweepRule]) -> String? {
    var nearestDistanceByStreet: [String: CLLocationDistance] = [:]
    for rule in rules {
        let key = streetKey(for: rule)
        let current = nearestDistanceByStreet[key] ?? .infinity
        nearestDistanceByStreet[key] = min(current, rule.distanceMeters)
    }

    return nearestDistanceByStreet.keys.sorted {
        let leftDistance = nearestDistanceByStreet[$0] ?? .infinity
        let rightDistance = nearestDistanceByStreet[$1] ?? .infinity
        if leftDistance == rightDistance {
            return $0 < $1
        }
        return leftDistance < rightDistance
    }.first
}

private func streetKey(for rule: SweepRule) -> String {
    "\(rule.segment.corridor)|\(rule.segment.limits)"
}

private func findNearbySegments(latitude: Double, longitude: Double) -> [NearbySegment] {
    SweepDataStore.loadSegments()
        .compactMap { segment in
            let projection = projectionToLinestring(latitude: latitude, longitude: longitude, coords: segment.coords)
            guard projection.distanceMeters <= searchRadiusMeters else {
                return nil
            }
            return NearbySegment(
                segment: segment,
                distanceMeters: projection.distanceMeters,
                sideScore: sideScore(for: segment.side, projection: projection)
            )
        }
        .sorted {
            if $0.distanceMeters == $1.distanceMeters {
                return $0.sideScore > $1.sideScore
            }
            return $0.distanceMeters < $1.distanceMeters
        }
}

private func projectionToLinestring(latitude: Double, longitude: Double, coords: [[Double]]) -> LineProjection {
    guard let first = coords.first, first.count >= 2 else {
        return LineProjection(distanceMeters: .infinity, offsetX: 0, offsetY: 0)
    }

    if coords.count == 1 {
        let offset = meterOffset(
            fromLatitude: first[0],
            fromLongitude: first[1],
            toLatitude: latitude,
            toLongitude: longitude
        )
        return LineProjection(
            distanceMeters: hypot(offset.x, offset.y),
            offsetX: offset.x,
            offsetY: offset.y
        )
    }

    var best = LineProjection(distanceMeters: .infinity, offsetX: 0, offsetY: 0)
    for index in 0..<(coords.count - 1) {
        let start = coords[index]
        let end = coords[index + 1]
        guard start.count >= 2, end.count >= 2 else {
            continue
        }
        let projection = pointToSegmentProjection(
            latitude: latitude,
            longitude: longitude,
            startLatitude: start[0],
            startLongitude: start[1],
            endLatitude: end[0],
            endLongitude: end[1]
        )
        if projection.distanceMeters < best.distanceMeters {
            best = projection
        }
    }

    return best
}

private func pointToSegmentProjection(
    latitude: Double,
    longitude: Double,
    startLatitude: Double,
    startLongitude: Double,
    endLatitude: Double,
    endLongitude: Double
) -> LineProjection {
    let start = meterOffset(
        fromLatitude: latitude,
        fromLongitude: longitude,
        toLatitude: startLatitude,
        toLongitude: startLongitude
    )
    let end = meterOffset(
        fromLatitude: latitude,
        fromLongitude: longitude,
        toLatitude: endLatitude,
        toLongitude: endLongitude
    )
    let dx = end.x - start.x
    let dy = end.y - start.y
    let lengthSquared = dx * dx + dy * dy

    var t = 0.0
    if lengthSquared > 0 {
        t = (-(start.x * dx + start.y * dy)) / lengthSquared
        t = min(1.0, max(0.0, t))
    }

    let closestX = start.x + t * dx
    let closestY = start.y + t * dy
    let offsetX = -closestX
    let offsetY = -closestY
    return LineProjection(
        distanceMeters: hypot(offsetX, offsetY),
        offsetX: offsetX,
        offsetY: offsetY
    )
}

private func meterOffset(
    fromLatitude: Double,
    fromLongitude: Double,
    toLatitude: Double,
    toLongitude: Double
) -> (x: Double, y: Double) {
    let averageLatitude = degreesToRadians((fromLatitude + toLatitude) / 2)
    let x = degreesToRadians(toLongitude - fromLongitude) * cos(averageLatitude) * 6_371_000
    let y = degreesToRadians(toLatitude - fromLatitude) * 6_371_000
    return (x, y)
}

private func sideScore(for side: String, projection: LineProjection) -> Double {
    let distance = hypot(projection.offsetX, projection.offsetY)
    guard distance > 0.25, let sideVector = sideUnitVector(side) else {
        return 0
    }

    return (projection.offsetX / distance) * sideVector.x + (projection.offsetY / distance) * sideVector.y
}

private func sideUnitVector(_ side: String) -> (x: Double, y: Double)? {
    let rawVector: (x: Double, y: Double)
    switch side {
    case "North":
        rawVector = (0, 1)
    case "South":
        rawVector = (0, -1)
    case "East":
        rawVector = (1, 0)
    case "West":
        rawVector = (-1, 0)
    case "NorthEast":
        rawVector = (1, 1)
    case "NorthWest":
        rawVector = (-1, 1)
    case "SouthEast":
        rawVector = (1, -1)
    case "SouthWest":
        rawVector = (-1, -1)
    default:
        return nil
    }

    let length = hypot(rawVector.x, rawVector.y)
    return (rawVector.x / length, rawVector.y / length)
}

private func haversine(_ lat1: Double, _ lng1: Double, _ lat2: Double, _ lng2: Double) -> CLLocationDistance {
    let earthRadiusMeters = 6_371_000.0
    let dLat = degreesToRadians(lat2 - lat1)
    let dLng = degreesToRadians(lng2 - lng1)
    let a = pow(sin(dLat / 2), 2)
        + cos(degreesToRadians(lat1)) * cos(degreesToRadians(lat2)) * pow(sin(dLng / 2), 2)
    return 2 * earthRadiusMeters * asin(sqrt(a))
}

private func coordinateDistance(_ lhs: CLLocationCoordinate2D, _ rhs: CLLocationCoordinate2D) -> CLLocationDistance {
    haversine(lhs.latitude, lhs.longitude, rhs.latitude, rhs.longitude)
}

private func mapRegion(containing coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
    guard let first = coordinates.first else {
        return nil
    }

    var minLatitude = first.latitude
    var maxLatitude = first.latitude
    var minLongitude = first.longitude
    var maxLongitude = first.longitude

    for coordinate in coordinates.dropFirst() {
        minLatitude = min(minLatitude, coordinate.latitude)
        maxLatitude = max(maxLatitude, coordinate.latitude)
        minLongitude = min(minLongitude, coordinate.longitude)
        maxLongitude = max(maxLongitude, coordinate.longitude)
    }

    let latitudeDelta = max((maxLatitude - minLatitude) * 1.8, 0.01)
    let longitudeDelta = max((maxLongitude - minLongitude) * 1.8, 0.01)
    return MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        ),
        span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
    )
}

private func degreesToRadians(_ degrees: Double) -> Double {
    degrees * .pi / 180
}

private func nextSweepOccurrence(for segment: SweepSegment, from: Date = Date()) -> Date {
    let calendar = Calendar.current
    var candidate = calendar.date(bySetting: .second, value: 0, of: from) ?? from

    for _ in 0..<35 {
        let weekday = calendar.component(.weekday, from: candidate) - 1
        if weekday == segment.day && isActiveWeek(candidate, weeks: segment.weeks) {
            var components = calendar.dateComponents([.year, .month, .day], from: candidate)
            components.hour = segment.fromHour
            components.minute = 0
            components.second = 0

            if let sweep = calendar.date(from: components), sweep > from {
                return sweep
            }
        }

        candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        candidate = calendar.startOfDay(for: candidate)
    }

    return calendar.date(byAdding: .day, value: 7, to: from) ?? from
}

private func isActiveWeek(_ date: Date, weeks: [Int]) -> Bool {
    let calendar = Calendar.current
    let weekday = calendar.component(.weekday, from: date)
    let day = calendar.component(.day, from: date)
    let range = calendar.range(of: .day, in: .month, for: date) ?? 1..<32

    var occurrence = 0
    for monthDay in range where monthDay <= day {
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = monthDay
        guard let candidate = calendar.date(from: components) else { continue }
        if calendar.component(.weekday, from: candidate) == weekday {
            occurrence += 1
        }
    }

    return occurrence >= 1 && occurrence <= weeks.count && weeks[occurrence - 1] == 1
}

private func formatTimeWindow(fromHour: Int, toHour: Int) -> String {
    "\(formatHour(fromHour))-\(formatHour(toHour))"
}

private func formatDistance(_ meters: CLLocationDistance) -> String {
    let feet = meters * 3.28084
    if feet < 10 {
        return "at pin"
    }
    return "\(Int(feet.rounded())) ft"
}

private func ruleSummary(_ rule: SweepRule) -> String {
    "\(rule.segment.corridor) - \(formatSide(rule.segment.side)) side - \(formatTimeWindow(fromHour: rule.segment.fromHour, toHour: rule.segment.toHour))"
}

private func formatSide(_ side: String) -> String {
    switch side {
    case "NorthEast":
        return "Northeast"
    case "NorthWest":
        return "Northwest"
    case "SouthEast":
        return "Southeast"
    case "SouthWest":
        return "Southwest"
    default:
        return side
    }
}

private func memberInitials(_ name: String) -> String {
    let parts = name.split(separator: " ")
    let initials = parts.prefix(2).compactMap { $0.first }.map { String($0) }.joined()
    return initials.isEmpty ? "?" : initials.uppercased()
}

private func colorForCarName(_ name: String, fallbackIndex: Int) -> Color {
    switch name {
    case "blue":
        return sweepBlue
    case "green":
        return Color.green
    case "orange":
        return Color.orange
    case "purple":
        return Color.purple
    case "teal":
        return Color.teal
    default:
        let palette: [Color] = [sweepBlue, Color.green, Color.orange, Color.purple, Color.teal]
        return palette[fallbackIndex % palette.count]
    }
}

private func nextCarColorName(index: Int) -> String {
    let names = ["blue", "green", "orange", "purple", "teal"]
    return names[index % names.count]
}

private func formatReminderLeadTime(_ hours: Double) -> String {
    if hours == 1 {
        return "1h"
    }
    return "\(Int(hours))h"
}

private func relativeMoveTime(_ date: Date, now: Date = Date()) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    if seconds < 60 {
        return "just now"
    }

    let minutes = seconds / 60
    if minutes < 60 {
        return "\(minutes)m ago"
    }

    let hours = minutes / 60
    if hours < 24 {
        return "\(hours)h ago"
    }

    let days = hours / 24
    return "\(days)d ago"
}

private func formatHour(_ hour: Int) -> String {
    let suffix = hour < 12 ? "am" : "pm"
    let display: Int
    if hour == 0 {
        display = 12
    } else if hour > 12 {
        display = hour - 12
    } else {
        display = hour
    }
    return "\(display)\(suffix)"
}

private func hoursUntil(_ target: Date, from: Date = Date()) -> Double {
    target.timeIntervalSince(from) / 3_600
}

private func urgencyColor(_ hoursUntil: Double) -> Color {
    if hoursUntil < 12 { return Color.red }
    if hoursUntil < 48 { return Color.orange }
    return Color.green
}

private func urgencyLabel(_ target: Date, from now: Date = Date()) -> String {
    let remainingHours = hoursUntil(target, from: now)
    if remainingHours < 1 { return "Move your car NOW" }
    if remainingHours < 24 { return "Street cleaning in \(Int(remainingHours.rounded()))h" }

    let calendar = Calendar.current
    if calendar.isDateInTomorrow(target) {
        return "Street cleaning tomorrow"
    }

    let today = calendar.startOfDay(for: now)
    let targetDay = calendar.startOfDay(for: target)
    let dayDifference = calendar.dateComponents([.day], from: today, to: targetDay).day ?? 0
    if dayDifference > 1 && dayDifference < 7 {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return "Street cleaning \(formatter.string(from: target))"
    }

    return "Street cleaning \(formatDate(target))"
}

private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE, MMM d"
    return formatter.string(from: date)
}

private let localReminderNotificationIdentifier = "sweep-alert-next-rule"

private func scheduleNotification(for rule: SweepRule, crew: SharedCarCrew, preferences: NotificationPreferences) {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [localReminderNotificationIdentifier])

    center.getNotificationSettings { settings in
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            addNotification(for: rule, crew: crew, preferences: preferences)
        case .notDetermined:
            center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                if granted {
                    addNotification(for: rule, crew: crew, preferences: preferences)
                }
            }
        case .denied:
            break
        @unknown default:
            break
        }
    }
}

private func addNotification(for rule: SweepRule, crew: SharedCarCrew, preferences: NotificationPreferences) {
    let now = Date()
    let leadReminderDate = rule.nextOccurrence.addingTimeInterval(-preferences.firstReminderHours * 3_600)
    let latestUsefulReminderDate = max(rule.nextOccurrence.addingTimeInterval(-15 * 60), now.addingTimeInterval(60))
    let fireDate = leadReminderDate > now ? leadReminderDate : min(now.addingTimeInterval(15 * 60), latestUsefulReminderDate)

    guard fireDate > now, fireDate < rule.nextOccurrence else {
        return
    }

    let content = UNMutableNotificationContent()
    content.title = "\(crew.carName): street cleaning soon"
    content.body = "\(crew.members.count) people will be alerted \(formatReminderLeadTime(preferences.firstReminderHours)) before \(formatTimeWindow(fromHour: rule.segment.fromHour, toHour: rule.segment.toHour)) on \(rule.segment.corridor)."
    content.sound = .default

    let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
    let request = UNNotificationRequest(identifier: localReminderNotificationIdentifier, content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request)
}
