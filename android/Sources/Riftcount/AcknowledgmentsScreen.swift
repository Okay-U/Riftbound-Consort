import SwiftUI

/// Acknowledgments, ported from the iOS AcknowledgmentsView. One addition:
/// Photon/OpenStreetMap credit — the Android build geocodes store searches
/// with Photon (iOS uses Apple's CLGeocoder there).
struct AcknowledgmentsScreen: View {
    var body: some View {
        Form {
            Section("Card data") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Riftcodex")
                        .font(.headline)
                    Text("Card database powered by api.riftcodex.com")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let url = URL(string: "https://riftcodex.com") {
                        Link("riftcodex.com", destination: url)
                            .font(.footnote)
                    }
                }
            }

            Section("Player stats") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("eloshowdown")
                        .font(.headline)
                    Text("Profile stats, ELO ratings and Summoner's DNA powered by eloshowdown.com.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let url = URL(string: "https://eloshowdown.com") {
                        Link("eloshowdown.com", destination: url)
                            .font(.footnote)
                    }
                }
            }

            Section("Domain icons") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("riftboundfaq")
                        .font(.headline)
                    Text("Domain rune icons by Christian Ivicevic, used under CC BY-SA 4.0.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let url = URL(string: "https://github.com/ChristianIvicevic/riftboundfaq") {
                        Link("github.com/ChristianIvicevic/riftboundfaq", destination: url)
                            .font(.footnote)
                    }
                    if let url = URL(string: "https://creativecommons.org/licenses/by-sa/4.0/") {
                        Link("CC BY-SA 4.0", destination: url)
                            .font(.footnote)
                    }
                }
            }

            Section("Geocoding") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Photon / OpenStreetMap")
                        .font(.headline)
                    Text("Store search locations by Photon (komoot), data © OpenStreetMap contributors.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let url = URL(string: "https://photon.komoot.io") {
                        Link("photon.komoot.io", destination: url)
                            .font(.footnote)
                    }
                    if let url = URL(string: "https://www.openstreetmap.org/copyright") {
                        Link("openstreetmap.org/copyright", destination: url)
                            .font(.footnote)
                    }
                }
            }

            Section {
                Text("Riftbound is a trademark of Riot Games. This app is an unofficial fan project and is not affiliated with Riot Games.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Acknowledgments")
    }
}
