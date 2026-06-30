//
//  WaypointMissionView.swift
//  GetFly
//

import SwiftUI

struct WaypointMissionView: View {
    @ObservedObject var viewModel: DroneViewModel

    var body: some View {
        GetFlyCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("\(viewModel.waypoints.count) waypoint\(viewModel.waypoints.count == 1 ? "" : "s")")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        viewModel.addWaypoint()
                    } label: {
                        Label("Add Target", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(GetFlyTheme.accent)
                }

                if viewModel.waypoints.isEmpty {
                    ContentUnavailableView {
                        Label("No Waypoints Yet", systemImage: "mappin.and.ellipse")
                    } description: {
                        Text("Tap the map or add your current target to build a mission route.")
                    } actions: {
                        Button("Add Current Target") {
                            viewModel.addWaypoint()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(minHeight: 160)
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(viewModel.waypoints.enumerated()), id: \.element.id) { index, waypoint in
                            waypointRow(index: index, waypoint: waypoint)
                        }
                    }

                    GetFlyActionButton(
                        title: viewModel.isNavigating ? "Mission Running…" : "Run Mission",
                        icon: viewModel.isNavigating ? "airplane" : "play.fill",
                        style: .primary,
                        isDisabled: viewModel.isBusy || !viewModel.isConnected || viewModel.isNavigating
                    ) {
                        Task { await viewModel.sendMission() }
                    }
                }
            }
        }
    }

    private func waypointRow(index: Int, waypoint: Waypoint) -> some View {
        let isActive = viewModel.activeWaypointIndex == index
        let isCompleted = (viewModel.activeWaypointIndex ?? -1) > index

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isActive ? GetFlyTheme.warning.gradient : GetFlyTheme.accent.gradient)
                    .frame(width: 36, height: 36)
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Waypoint \(index + 1)")
                        .font(.subheadline.weight(.semibold))
                    if isActive {
                        Text("ACTIVE")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(GetFlyTheme.warning.opacity(0.2), in: Capsule())
                            .foregroundStyle(GetFlyTheme.warning)
                    }
                }
                Text(waypoint.coordinate.formatted)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                if let idx = viewModel.waypoints.firstIndex(where: { $0.id == waypoint.id }) {
                    viewModel.removeWaypoint(at: IndexSet(integer: idx))
                }
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(GetFlyTheme.danger)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isNavigating)
        }
        .padding(12)
        .background(
            isActive ? GetFlyTheme.warning.opacity(0.08) : Color(.tertiarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isActive ? GetFlyTheme.warning.opacity(0.35) : .clear, lineWidth: 1)
        )
    }
}

#Preview {
    WaypointMissionView(viewModel: DroneViewModel())
        .padding()
        .getFlyScreenBackground()
}
