//
//  GameSetupSheet.swift
//  Riftbound Companiokay
//

import SwiftUI

struct GameSetupSheet: View {
    @EnvironmentObject var decklistStore: DecklistStore
    @EnvironmentObject var cardStore: CardStore
    @AppStorage("activeDeckId")  private var activeDeckId: String = ""
    @AppStorage("activeOpponent") private var activeOpponent: String = ""
    @AppStorage("activeStartedFirst") private var activeStartedFirst: String = ""
    @Environment(\.dismiss) private var dismiss

    private var legendNames: [String] { cardStore.legendNames }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Deck") {
                    Picker("Deck", selection: $activeDeckId) {
                        Text("None").tag("")
                        ForEach(decklistStore.lists) { deck in
                            Text(deck.name).tag(deck.id.uuidString)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Opponent's Legend") {
                    Picker("Legend", selection: $activeOpponent) {
                        Text("None").tag("")
                        ForEach(legendNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)

                    if legendNames.isEmpty {
                        Text("Legends loading… open Cards tab once to fetch.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Turn Order") {
                    Picker("Going", selection: $activeStartedFirst) {
                        Text("Unknown").tag("")
                        Text("First").tag("first")
                        Text("Second").tag("second")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Game Setup")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { cardStore.loadIfNeeded() }
        }
    }
}
