//
//  Settings.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 02.11.25.
//

import SwiftUI
#if os(iOS)
import ActivityKit
#endif

struct Settings: View {
    @AppStorage("batterySaver") private var batterySaver: Bool = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("soundsEnabled") private var soundsEnabled: Bool = false
    @AppStorage("diceShakeToRoll") private var diceShakeToRoll: Bool = true
    @AppStorage("liveActivityEnabled") private var liveActivityEnabled: Bool = false
    @AppStorage("matchModeEnabled") private var matchModeEnabled: Bool = true
    @AppStorage("didOnboard") private var didOnboard: Bool = false

    private var systemLiveActivitiesAuthorized: Bool {
        #if os(iOS)
        ActivityAuthorizationInfo().areActivitiesEnabled
        #else
        false
        #endif
    }
    @State private var showOnboarding: Bool = false
    @State private var showEventsOnboarding: Bool = false

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

                Section {
                    Toggle("Live Activity", isOn: $liveActivityEnabled)
                    if liveActivityEnabled, !systemLiveActivitiesAuthorized {
                        Label("Live Activities are disabled in iOS Settings. Enable them in Settings → Riftcount → Live Activities.",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Live Activity")
                } footer: {
                    Text("Shows scoreboard on Lock Screen and Dynamic Island while a 2-player game timer is running. Tap +/− on lock screen to update scores.")
                }

                Section {
                    Toggle("Match mode", isOn: $matchModeEnabled)
                } header: {
                    Text("Tournament")
                } footer: {
                    Text("When you're signed in to Events and playing a live tournament, the Scoreboard shows your table, opponent, and a Report button so you can score and submit the match in one place.")
                }

                Section("Help") {
                    Button {
                        showOnboarding = true
                    } label: {
                        Label("Show tour again", systemImage: "sparkles")
                    }
                    Button {
                        showEventsOnboarding = true
                    } label: {
                        Label("Events & tournaments tour", systemImage: "trophy")
                    }
                }

                Section("About") {
                    NavigationLink("Report Bug") { BugReportView() }
                    NavigationLink("Wish a Feature") { FeatureRequestView() }
                    ShareLink(
                        item: URL(string: "https://apps.apple.com/de/app/riftcount-score-tracker/id6755601459")!,
                        subject: Text("Riftcount: Score Tracker"),
                        message: Text("Score tracker for Riftbound TCG. Check it out!")
                    ) {
                        Label("Share this app with your friends!", systemImage: "square.and.arrow.up")
                    }
                    Link(destination: URL(string: "https://apps.apple.com/de/app/riftcount-score-tracker/id6755601459?action=write-review")!) {
                        Label("Leave a Rating", systemImage: "star.fill")
                    }
                    NavigationLink("Buy me a coffee") { DonationView() }
                    NavigationLink("Acknowledgments") { AcknowledgmentsView() }
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
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView()
            }
            .fullScreenCover(isPresented: $showEventsOnboarding) {
                EventsOnboardingView()
            }
        }
    }
}

extension Bundle {
    var appVersion: String { (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0" }
    var appBuild: String { (infoDictionary?["CFBundleVersion"] as? String) ?? "1" }
}
