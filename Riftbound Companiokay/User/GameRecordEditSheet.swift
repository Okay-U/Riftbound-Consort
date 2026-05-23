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

    init(record: GameRecord) {
        self.record = record
        _deckId = State(initialValue: record.deckId?.uuidString ?? "")
        _opponent = State(initialValue: record.opponent)
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
        let unchanged = newDeckUUID == record.deckId
            && newDeckName == record.deckName
            && opponent == record.opponent
        guard !unchanged else { return }
        let updated = GameRecord(
            id: record.id,
            date: record.date,
            deckId: newDeckUUID,
            deckName: newDeckName,
            opponent: opponent,
            result: record.result,
            durationSeconds: record.durationSeconds
        )
        store.update(updated)
    }
}
