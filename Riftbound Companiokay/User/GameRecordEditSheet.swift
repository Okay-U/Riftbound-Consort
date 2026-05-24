//
//  GameRecordEditSheet.swift
//  Riftbound Companiokay
//

import SwiftUI

struct GameRecordEditSheet: View {
    let record: GameRecord
    @EnvironmentObject var store: GameRecordStore
    @EnvironmentObject var decklistStore: DecklistStore
    @EnvironmentObject var cardStore: CardStore
    @Environment(\.dismiss) private var dismiss

    @State private var deckId: String
    @State private var opponent: String
    @State private var startedFirst: String

    init(record: GameRecord) {
        self.record = record
        _deckId = State(initialValue: record.deckId?.uuidString ?? "")
        _opponent = State(initialValue: record.opponent)
        let startVal: String
        switch record.startedFirst {
        case .some(true):  startVal = "first"
        case .some(false): startVal = "second"
        case .none:        startVal = ""
        }
        _startedFirst = State(initialValue: startVal)
    }

    private var legendNames: [String] { cardStore.legendNames }
    private var isLegendsLoading: Bool {
        cardStore.legendNames.isEmpty && cardStore.isLoading
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Deck") {
                    Picker("Deck", selection: $deckId) {
                        Text("None").tag("")
                        ForEach(decklistStore.lists) { deck in
                            Text(deck.name).tag(deck.id.uuidString)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Opponent's Legend") {
                    Picker("Legend", selection: $opponent) {
                        Text("None").tag("")
                        ForEach(legendNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(isLegendsLoading)

                    if isLegendsLoading {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Loading legends…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if legendNames.isEmpty {
                        Text("Open Cards tab once to fetch legends.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Turn Order") {
                    Picker("Going", selection: $startedFirst) {
                        Text("Unknown").tag("")
                        Text("First").tag("first")
                        Text("Second").tag("second")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Edit Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(isLegendsLoading)
                }
            }
            .onAppear { cardStore.loadIfNeeded() }
        }
    }

    private func save() {
        let newDeckUUID = UUID(uuidString: deckId)
        let newDeckName = decklistStore.lists.first { $0.id.uuidString == deckId }?.name
        let newStarted: Bool? = startedFirst == "first" ? true
            : startedFirst == "second" ? false
            : nil
        let unchanged = newDeckUUID == record.deckId
            && newDeckName == record.deckName
            && opponent == record.opponent
            && newStarted == record.startedFirst
        guard !unchanged else { return }
        let updated = GameRecord(
            id: record.id,
            date: record.date,
            deckId: newDeckUUID,
            deckName: newDeckName,
            opponent: opponent,
            result: record.result,
            durationSeconds: record.durationSeconds,
            events: record.events,
            startedFirst: newStarted
        )
        store.update(updated)
    }
}
