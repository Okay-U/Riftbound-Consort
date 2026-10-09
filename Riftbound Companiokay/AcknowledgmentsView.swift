//
//  AcknowledgmentsView.swift
//  Riftbound Companiokay
//

import SwiftUI

struct AcknowledgmentsView: View {
    var body: some View {
        Form {
            Section("Card data") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Riot Games")
                        .font(.headline)
                    Text("Card data and images from the official Riftbound card gallery. Riftcount was created under Riot Games' \"Legal Jibber Jabber\" policy using assets owned by Riot Games. Riot Games does not endorse or sponsor this project.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link("playriftbound.com", destination: URL(string: "https://playriftbound.com/en-us/card-gallery/")!)
                        .font(.footnote)
                }
            }

            Section("Player stats") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("eloshowdown")
                        .font(.headline)
                    Text("Profile stats, ELO ratings and Summoner's DNA powered by eloshowdown.com.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link("eloshowdown.com", destination: URL(string: "https://eloshowdown.com")!)
                        .font(.footnote)
                }
            }

            Section("Domain icons") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("riftboundfaq")
                        .font(.headline)
                    Text("Domain rune icons by Christian Ivicevic, used under CC BY-SA 4.0.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link("github.com/ChristianIvicevic/riftboundfaq",
                         destination: URL(string: "https://github.com/ChristianIvicevic/riftboundfaq")!)
                        .font(.footnote)
                    Link("CC BY-SA 4.0",
                         destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!)
                        .font(.footnote)
                }
            }

            Section {
                Text("Riftbound is a trademark of Riot Games. This app is an unofficial fan project and is not affiliated with Riot Games.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Acknowledgments")
        .navigationBarTitleDisplayMode(.inline)
    }
}
