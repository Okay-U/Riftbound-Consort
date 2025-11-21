//
//  Settings.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 02.11.25.
//

import SwiftUI

struct Settings: View {
    @AppStorage("batterySaver") private var batterySaver: Bool = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("soundsEnabled") private var soundsEnabled: Bool = false
    @AppStorage("diceShakeToRoll") private var diceShakeToRoll: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Display & Power") {
                    Toggle("Battery saver visuals", isOn: $batterySaver)
                        .help("Reduces glow/blur and disables 7-point particles to save power.")
                }

                Section("Interaction") {
                    Toggle("Haptics", isOn: $hapticsEnabled)
                    Toggle("Shake to roll dice", isOn: $diceShakeToRoll)
                }

                Section("About") {
                    NavigationLink("Report Bug") { BugReportView() }
                    NavigationLink("Wish a Feature") { FeatureRequestView() }
                    NavigationLink("Roadmap") { RoadmapView() }
                    NavigationLink("Buy me a coffee") { DonationView() }
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Riftcount: Score Tracker")
                            .font(.headline)
                        Text("Version \(Bundle.main.appVersion) (\(Bundle.main.appBuild))")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

extension Bundle {
    var appVersion: String { (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0" }
    var appBuild: String { (infoDictionary?["CFBundleVersion"] as? String) ?? "1" }
}
