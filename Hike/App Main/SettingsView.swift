//
//  SettingsView.swift
//  GetFly
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    Image(systemName: "airplane.circle.fill")
                        .font(.system(size: 72, weight: .bold))
                    VStack(spacing: -4) {
                        Text("GetFly")
                            .font(.system(size: 66, weight: .black))
                        Text("Drone Control")
                            .fontWeight(.medium)
                    }
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 56, weight: .bold))
                    Spacer()
                }
                .foregroundStyle(GetFlyTheme.heroGradient)
                .padding(.top, 8)

                VStack(spacing: 8) {
                    Text("Fly smarter.\nControl your quadcopter.")
                        .font(.title2)
                        .fontWeight(.heavy)
                    Text("Connect to your ESP32 controller over Wi‑Fi, plan waypoint missions on OpenStreetMap, and pilot your drone from your iPhone.")
                        .font(.footnote)
                        .italic()
                    Text("Ready for takeoff.")
                        .fontWeight(.heavy)
                        .foregroundStyle(GetFlyTheme.accent)
                }
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity)
            }
            .listRowSeparator(.hidden)

            Section(
                header: Text("ABOUT THE APP"),
                footer:
                    HStack {
                        Spacer()
                        Text("Copyright © All rights reserved.")
                        Spacer()
                    }
                    .padding(.vertical, 8)
            ) {
                CustomListRowView(rowLabel: "Application", rowIcon: "apps.iphone", rowContent: "GetFly", rowTintColor: .blue)
                CustomListRowView(rowLabel: "Compatability", rowIcon: "info.circle", rowContent: "iOS, iPadOS", rowTintColor: .red)
                CustomListRowView(rowLabel: "Technology", rowIcon: "swift", rowContent: "Swift", rowTintColor: .orange)
                CustomListRowView(rowLabel: "Version", rowIcon: "gear", rowContent: "1.0", rowTintColor: .purple)
                CustomListRowView(rowLabel: "Developer", rowIcon: "ellipsis.curlybraces", rowContent: "ADIL ZAHOOR MALIK", rowTintColor: .mint)
                CustomListRowView(rowLabel: "LinkedIn", rowIcon: "globe", rowTintColor: .pink, rowLinkLabel: "ADIL ZAHOOR MALIK", rowLinkDestination: "https://www.linkedin.com/in/adilzahoormalik/")
            }
        }
    }
}

#Preview {
    SettingsView()
}
