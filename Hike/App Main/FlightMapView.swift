//
//  FlightMapView.swift
//  GetFly
//

import CoreLocation
import SwiftUI

enum FlightMapLayout {
    case preview
    case standard
    case expanded

    var height: CGFloat {
        switch self {
        case .preview: return 240
        case .standard: return 380
        case .expanded: return 520
        }
    }
}

struct FlightMapView: View {
    let homeCoordinate: CLLocationCoordinate2D
    let dronePosition: Coordinate3D
    let targetPosition: Coordinate3D
    let waypoints: [Waypoint]
    let flightTrail: [Coordinate3D]
    let isFlying: Bool
    let followDrone: Bool
    let activeWaypointIndex: Int?
    let navigationLabel: String
    let layout: FlightMapLayout
    var onMapTap: ((Coordinate3D) -> Void)?

    init(
        homeCoordinate: CLLocationCoordinate2D,
        dronePosition: Coordinate3D,
        targetPosition: Coordinate3D,
        waypoints: [Waypoint],
        flightTrail: [Coordinate3D] = [],
        isFlying: Bool = false,
        followDrone: Bool = false,
        activeWaypointIndex: Int? = nil,
        navigationLabel: String = "Ready",
        layout: FlightMapLayout = .standard,
        onMapTap: ((Coordinate3D) -> Void)? = nil
    ) {
        self.homeCoordinate = homeCoordinate
        self.dronePosition = dronePosition
        self.targetPosition = targetPosition
        self.waypoints = waypoints
        self.flightTrail = flightTrail
        self.isFlying = isFlying
        self.followDrone = followDrone
        self.activeWaypointIndex = activeWaypointIndex
        self.navigationLabel = navigationLabel
        self.layout = layout
        self.onMapTap = onMapTap
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            OpenStreetMapView(
                homeCoordinate: homeCoordinate,
                dronePosition: dronePosition,
                targetPosition: targetPosition,
                waypoints: waypoints,
                flightTrail: flightTrail,
                isFlying: isFlying,
                followDrone: followDrone,
                activeWaypointIndex: activeWaypointIndex,
                onMapTap: onMapTap
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(GetFlyTheme.accent.opacity(0.18), lineWidth: 1.5)
            )

            VStack(alignment: .leading, spacing: 8) {
                if isFlying {
                    HStack(spacing: 8) {
                        Image(systemName: "airplane")
                            .symbolEffect(.pulse, isActive: true)
                        Text(navigationLabel)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(GetFlyTheme.success.gradient, in: Capsule())
                }

                HStack(spacing: 8) {
                    legendItem(color: GetFlyTheme.success, text: "Drone")
                    legendItem(color: GetFlyTheme.warning, text: "Target")
                    legendItem(color: GetFlyTheme.accent, text: "Route")
                }
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())

                Spacer()

                HStack {
                    Label("Tap map to set target", systemImage: "hand.tap.fill")
                        .font(.caption2.weight(.medium))
                    Spacer()
                    Text("© OpenStreetMap")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: layout.height)
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }
}

#Preview {
    FlightMapView(
        homeCoordinate: CLLocationCoordinate2D(latitude: 33.6844, longitude: 73.0479),
        dronePosition: Coordinate3D(x: 0, y: 0, z: 1),
        targetPosition: Coordinate3D(x: 2, y: 1.5, z: 1.5),
        waypoints: [
            Waypoint(coordinate: Coordinate3D(x: 1, y: 0, z: 1.5)),
            Waypoint(coordinate: Coordinate3D(x: 2, y: 1.5, z: 1.5))
        ],
        isFlying: true,
        followDrone: true,
        navigationLabel: "Flying to waypoint 2",
        layout: .expanded
    )
    .padding()
}
