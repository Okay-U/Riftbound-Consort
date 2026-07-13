import SwiftUI

/// Settings, ported from the iOS Settings view. Omitted on Android:
/// shake-to-roll (no accelerometer bridge), Live Activity (iOS-only),
/// share/rating links (no Play Store listing yet).
struct SettingsScreen: View {
    @Environment(MatchModeStore.self) var matchMode
    @AppStorage("hapticsEnabled") var hapticsEnabled: Bool = true
    @State var showOnboarding = false
    @State var showEventsOnboarding = false

    private static let supportEmail = "contact-okaydev@proton.me"

    var body: some View {
        NavigationStack {
            Form {
                Section("Interaction") {
                    Toggle("Haptics", isOn: $hapticsEnabled)
                }

                Section("Tournament") {
                    // Bound through the store, not @AppStorage: the store only
                    // reads the persisted flag at init, so an external defaults
                    // write would leave its published state stale.
                    Toggle("Match mode", isOn: Binding(
                        get: { matchMode.enabled },
                        set: { matchMode.enabled = $0 }
                    ))
                    Text("When you're signed in to Events and playing a live tournament, the Scoreboard shows your table, opponent, and a Report button so you can score and submit the match in one place.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Help") {
                    Button {
                        showOnboarding = true
                    } label: {
                        Text("Show General Tutorial")
                    }
                    Button {
                        showEventsOnboarding = true
                    } label: {
                        Text("Show Events tour again")
                    }
                }

                Section("About") {
                    NavigationLink("Acknowledgments") { AcknowledgmentsScreen() }
                    if let bugURL = mailURL(subject: "Riftcount Android – Bug Report") {
                        Link(destination: bugURL) {
                            Text("Report Bug")
                        }
                    }
                    if let wishURL = mailURL(subject: "Riftcount Android – Feature Request") {
                        Link(destination: wishURL) {
                            Text("Wish a Feature")
                        }
                    }
                    if let kofi = URL(string: "https://ko-fi.com/okayunal") {
                        Link(destination: kofi) {
                            Text("Buy me a coffee")
                        }
                    }
                    if let privacyURL = URL(string: "https://lopsided-waxflower-e3a.notion.site/Riftscore-Support-and-Privacy-2b2d4130908a805f8211ce98d9d93a36") {
                        Link(destination: privacyURL) {
                            Text("Support & Privacy")
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Riftcount: Score Tracker")
                            .font(.headline)
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                            Text("Version \(version) (\(build))")
                                .foregroundStyle(.secondary)
                        }
                        Text("Unofficial companion, not affiliated with Riot Games or UVS Games.")
                            .font(.footnote)
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

    private func mailURL(subject: String) -> URL? {
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        return URL(string: "mailto:\(Self.supportEmail)?subject=\(encoded)")
    }
}
