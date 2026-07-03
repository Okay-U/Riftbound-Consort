import SwiftUI

/// Edit a logged game, ported from iOS. Deck/legend use SelectRow
/// (menu-style Picker crashes on Android).
struct GameRecordEditSheet: View {
    let record: GameRecord
    @Environment(GameRecordStore.self) var store
    @Environment(DecklistStore.self) var decklistStore
    @Environment(CardStore.self) var cardStore
    @Environment(\.dismiss) var dismiss

    @State var deckId: String
    @State var opponent: String
    @State var startedFirst: String
    @State var deckExpanded = false
    @State var legendExpanded = false

    init(record: GameRecord) {
        self.record = record
        _deckId = State(initialValue: record.deckId?.uuidString ?? "")
        _opponent = State(initialValue: record.opponent)
        let startVal: String
        switch record.startedFirst {
        case .some(true): startVal = "first"
        case .some(false): startVal = "second"
        case .none: startVal = ""
        }
        _startedFirst = State(initialValue: startVal)
    }

    private var legendNames: [String] { cardStore.legendNames }

    private var deckName: String {
        decklistStore.lists.first { $0.id.uuidString == deckId }?.name ?? "None"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SheetHeader(title: "Edit Game") { dismiss() }

                sectionTitle("Your Deck")
                SelectRow(value: deckName, isExpanded: $deckExpanded) {
                    selectOption(label: "None", selected: deckId.isEmpty) {
                        deckId = ""
                        deckExpanded = false
                    }
                    ForEach(decklistStore.lists) { deck in
                        selectOption(label: deck.name,
                                     selected: deckId == deck.id.uuidString) {
                            deckId = deck.id.uuidString
                            deckExpanded = false
                        }
                    }
                }

                sectionTitle("Opponent's Legend")
                SelectRow(value: opponent.isEmpty ? "None" : opponent,
                          isExpanded: $legendExpanded) {
                    selectOption(label: "None", selected: opponent.isEmpty) {
                        opponent = ""
                        legendExpanded = false
                    }
                    ForEach(legendNames, id: \.self) { name in
                        selectOption(label: name, selected: opponent == name) {
                            opponent = name
                            legendExpanded = false
                        }
                    }
                }

                if legendNames.isEmpty {
                    Text("Legends loading… open Cards tab once to fetch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }

                sectionTitle("Turn Order")
                SegmentedControl(selection: $startedFirst,
                                 options: [("Unknown", ""), ("First", "first"), ("Second", "second")])
                .padding(.horizontal, 16)

                Button {
                    save()
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 16)

                Spacer(minLength: 24)
            }
        }
        .onAppear { cardStore.loadIfNeeded() }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
    }

    private func selectOption(label: String,
                              selected: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
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
