//
//  DroneViewModel.swift
//  GetFly
//

import Foundation

@MainActor
final class DroneViewModel: ObservableObject {
    @Published var status: DroneStatus = .disconnected
    @Published private(set) var displayPosition = Coordinate3D(x: 0, y: 0, z: 0)
    @Published private(set) var flightTrail: [Coordinate3D] = []
    @Published private(set) var isNavigating = false
    @Published private(set) var activeWaypointIndex: Int?
    @Published private(set) var navigationLabel = "Ready"

    @Published var isConnected = false
    @Published var isBusy = false
    @Published var connectionError: String?
    @Published var lastError: String?
    @Published var lastSuccessMessage: String?

    @Published var targetCoordinate = Coordinate3D(x: 0, y: 0, z: 1.5)
    @Published var waypoints: [Waypoint] = []

    let settings = DroneConnectionSettings()
    private let client = ESP32Client()
    private var pollingTask: Task<Void, Never>?
    private var animationTask: Task<Void, Never>?
    private var simulatedFlightTask: Task<Void, Never>?

    var isFlying: Bool {
        status.flying || isNavigating
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await refreshStatus()
                let interval = settings.pollIntervalSeconds
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        animationTask?.cancel()
        simulatedFlightTask?.cancel()
    }

    func refreshStatus() async {
        guard let baseURL = settings.baseURL else {
            isConnected = false
            connectionError = ESP32ClientError.invalidURL.localizedDescription
            return
        }

        do {
            let newStatus = try await client.fetchStatus(baseURL: baseURL)
            applyStatusUpdate(newStatus)
            isConnected = true
            connectionError = nil
        } catch {
            isConnected = false
            status = .disconnected
            connectionError = error.localizedDescription
        }
    }

    func sendAction(_ action: DroneAction) async {
        if action == .land || action == .disarm || action == .emergencyStop {
            stopSimulatedFlight()
        }
        await send(payload: .action(action))
    }

    func sendGoto() async {
        beginNavigation(to: targetCoordinate, label: "Flying to target")
        await send(payload: .goto(targetCoordinate))
    }

    func sendMission() async {
        guard !waypoints.isEmpty else {
            lastError = "Add at least one waypoint to the mission."
            return
        }
        beginMissionSimulation()
        await send(payload: .mission(waypoints))
    }

    func addWaypoint(from coordinate: Coordinate3D? = nil) {
        let point = coordinate ?? targetCoordinate
        waypoints.append(Waypoint(coordinate: point))
    }

    func removeWaypoint(at offsets: IndexSet) {
        waypoints.remove(atOffsets: offsets)
    }

    func moveWaypoint(from source: IndexSet, to destination: Int) {
        waypoints.move(fromOffsets: source, toOffset: destination)
    }

    func clearFlightTrail() {
        flightTrail.removeAll()
    }

    private func send(payload: DroneCommandPayload) async {
        guard let baseURL = settings.baseURL else {
            lastError = ESP32ClientError.invalidURL.localizedDescription
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let response = try await client.sendCommand(payload, baseURL: baseURL)
            lastSuccessMessage = response.message ?? "Command sent."
            lastError = nil
            await refreshStatus()
        } catch {
            lastError = error.localizedDescription
            stopSimulatedFlight()
        }
    }

    private func applyStatusUpdate(_ newStatus: DroneStatus) {
        let previous = status
        status = newStatus

        let reported = newStatus.position
        let moved = distance2D(previous.position, reported) > 0.05
            || abs(previous.position.z - reported.z) > 0.05

        if moved || previous == .disconnected {
            animateDisplayPosition(to: reported, duration: max(0.35, settings.pollIntervalSeconds * 0.85))
        } else if !isNavigating {
            displayPosition = reported
        }

        updateNavigationState(from: newStatus)

        if newStatus.mode == .idle && !newStatus.flying {
            isNavigating = false
            activeWaypointIndex = nil
            navigationLabel = "Ready"
        }
    }

    private func beginNavigation(to target: Coordinate3D, label: String) {
        isNavigating = true
        navigationLabel = label
        runSimulatedPath(points: [displayPosition, target], labels: [label])
    }

    private func beginMissionSimulation() {
        guard !waypoints.isEmpty else { return }

        isNavigating = true
        activeWaypointIndex = 0
        navigationLabel = "Mission started"

        simulatedFlightTask?.cancel()
        simulatedFlightTask = Task {
            for index in waypoints.indices {
                guard !Task.isCancelled else { return }
                activeWaypointIndex = index
                navigationLabel = "Flying to waypoint \(index + 1) of \(waypoints.count)"

                let from = index == 0 ? displayPosition : waypoints[index - 1].coordinate
                let to = waypoints[index].coordinate
                await animateSegment(from: from, to: to, duration: segmentDuration(from: from, to: to))
            }

            guard !Task.isCancelled else { return }
            activeWaypointIndex = waypoints.count
            navigationLabel = "Mission complete"
            try? await Task.sleep(for: .seconds(1.5))
            if status.mode != .mission {
                isNavigating = false
                activeWaypointIndex = nil
                navigationLabel = "Ready"
            }
        }
    }

    private func runSimulatedPath(points: [Coordinate3D], labels: [String]) {
        simulatedFlightTask?.cancel()
        simulatedFlightTask = Task {
            for index in 1..<points.count {
                guard !Task.isCancelled else { return }
                if index - 1 < labels.count {
                    navigationLabel = labels[index - 1]
                }
                await animateSegment(
                    from: points[index - 1],
                    to: points[index],
                    duration: segmentDuration(from: points[index - 1], to: points[index])
                )
            }
        }
    }

    private func animateSegment(from start: Coordinate3D, to end: Coordinate3D, duration: TimeInterval) async {
        let steps = max(20, Int(duration * 30))
        for step in 1...steps {
            guard !Task.isCancelled else { return }
            let progress = easeInOut(Double(step) / Double(steps))
            let point = interpolate(from: start, to: end, progress: progress)
            displayPosition = point
            appendTrailPoint(point)
            try? await Task.sleep(for: .seconds(duration / Double(steps)))
        }
        displayPosition = end
        appendTrailPoint(end)
    }

    private func animateDisplayPosition(to target: Coordinate3D, duration: TimeInterval) {
        animationTask?.cancel()
        let start = displayPosition
        animationTask = Task {
            let steps = max(12, Int(duration * 30))
            for step in 1...steps {
                guard !Task.isCancelled else { return }
                let progress = easeInOut(Double(step) / Double(steps))
                let point = interpolate(from: start, to: target, progress: progress)
                displayPosition = point
                appendTrailPoint(point)
                try? await Task.sleep(for: .seconds(duration / Double(steps)))
            }
            displayPosition = target
            appendTrailPoint(target)
        }
    }

    private func updateNavigationState(from newStatus: DroneStatus) {
        guard newStatus.flying else { return }

        switch newStatus.mode {
        case .mission:
            isNavigating = true
            if let index = nearestUpcomingWaypointIndex(for: newStatus.position) {
                activeWaypointIndex = index
                navigationLabel = "En route to waypoint \(index + 1)"
            }
        case .flying:
            if isNavigating {
                navigationLabel = "Flying to target"
            }
        default:
            break
        }
    }

    private func nearestUpcomingWaypointIndex(for position: Coordinate3D) -> Int? {
        for (index, waypoint) in waypoints.enumerated() {
            if distance2D(position, waypoint.coordinate) > 0.4 {
                return index
            }
        }
        return waypoints.isEmpty ? nil : waypoints.count - 1
    }

    private func stopSimulatedFlight() {
        simulatedFlightTask?.cancel()
        simulatedFlightTask = nil
        isNavigating = false
        activeWaypointIndex = nil
        navigationLabel = "Ready"
    }

    private func appendTrailPoint(_ point: Coordinate3D) {
        guard status.flying || isNavigating else { return }
        if let last = flightTrail.last, distance2D(last, point) < 0.15 {
            return
        }
        flightTrail.append(point)
        if flightTrail.count > 120 {
            flightTrail.removeFirst(flightTrail.count - 120)
        }
    }

    private func segmentDuration(from: Coordinate3D, to: Coordinate3D) -> TimeInterval {
        min(8, max(1.8, distance3D(from, to) * 0.9))
    }

    private func interpolate(from: Coordinate3D, to: Coordinate3D, progress: Double) -> Coordinate3D {
        Coordinate3D(
            x: from.x + (to.x - from.x) * progress,
            y: from.y + (to.y - from.y) * progress,
            z: from.z + (to.z - from.z) * progress
        )
    }

    private func distance2D(_ a: Coordinate3D, _ b: Coordinate3D) -> Double {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func distance3D(_ a: Coordinate3D, _ b: Coordinate3D) -> Double {
        hypot(hypot(a.x - b.x, a.y - b.y), a.z - b.z)
    }

    private func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}
