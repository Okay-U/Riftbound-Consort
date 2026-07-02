import SwiftUI

/// Decks tab, Wave 2c: deck list, create, delete, simple deck detail with
/// per-slot sections and count controls. Builder wizard, import/export, and
/// stats come in later waves.
struct DecksScreen: View {
    @Environment(DecklistStore.self) var store
    @State var showNewDeck = false
    @State var newDeckName = ""

    var body: some View {
        NavigationStack {
            Group {
                if store.lists.isEmpty {
                    VStack(spacing: 12) {
                        Text("No decks yet")
                            .font(.headline)
                        Text("Create a deck, then add cards from the Cards tab.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("New Deck") { showNewDeck = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(store.lists) { deck in
                            NavigationLink(value: deck.id) {
                                deckRow(deck)
                            }
                        }
                        .onDelete { offsets in
                            for offset in offsets {
                                store.delete(store.lists[offset])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Decks")
            .navigationDestination(for: UUID.self) { deckID in
                DeckDetailScreen(deckID: deckID)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showNewDeck = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewDeck) {
                NewDeckSheet(name: $newDeckName) { name in
                    store.create(name: name)
                }
            }
        }
    }

    private func deckRow(_ deck: Decklist) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(deck.name)
                .font(.headline)
            Text(deckSummary(deck))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func deckSummary(_ deck: Decklist) -> String {
        let mainCount = deck.mainDeck.reduce(0) { $0 + $1.count }
        var parts: [String] = []
        if let legend = deck.legend { parts.append(legend.cardName) }
        parts.append("\(mainCount) main")
        if !deck.runes.isEmpty {
            parts.append("\(deck.runes.reduce(0) { $0 + $1.count }) runes")
        }
        return parts.joined(separator: " · ")
    }
}

struct NewDeckSheet: View {
    @Binding var name: String
    let onCreate: (String) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SheetHeader(title: "New Deck") { dismiss() }

            TextField("Deck name", text: $name)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)

            Button {
                let trimmed = name.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                onCreate(trimmed)
                name = ""
                dismiss()
            } label: {
                Text("Create")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 16)

            Spacer()
        }
    }
}

// MARK: - Add to deck (from card detail)

struct AddToDeckSheet: View {
    let card: Card
    @Environment(DecklistStore.self) var store
    @Environment(\.dismiss) var dismiss
    @State var newDeckName = ""
    @State var showNewDeckField = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: "Add to Deck") { dismiss() }

            Text("Adds to: \(card.preferredSlot.displayName)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            List {
                if store.lists.isEmpty && !showNewDeckField {
                    Text("No decklists yet — create one below.")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.lists) { list in
                    Button {
                        store.add(card, to: list)
                        dismiss()
                    } label: {
                        HStack {
                            Text(list.name)
                            Spacer()
                            Image(systemName: "plus")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if showNewDeckField {
                    HStack {
                        TextField("Deck name", text: $newDeckName)
                        Button("Create") {
                            let name = newDeckName.trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty else { return }
                            let new = store.create(name: name)
                            store.add(card, to: new)
                            dismiss()
                        }
                        .disabled(newDeckName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } else {
                    Button("New Deck…") { showNewDeckField = true }
                }
            }
        }
    }
}

// MARK: - Deck detail

struct DeckDetailScreen: View {
    let deckID: UUID
    @Environment(DecklistStore.self) var store

    private var deck: Decklist? {
        store.lists.first { $0.id == deckID }
    }

    var body: some View {
        Group {
            if let deck {
                List {
                    if let legend = deck.legend {
                        Section("Legend") {
                            entryRow(legend, slot: .legend, deck: deck)
                        }
                    }
                    if let champion = deck.champion {
                        Section("Champion") {
                            entryRow(champion, slot: .champion, deck: deck)
                        }
                    }
                    if !deck.battlefields.isEmpty {
                        Section("Battlefields") {
                            ForEach(deck.battlefields, id: \.cardId) { entry in
                                entryRow(entry, slot: .battlefield, deck: deck)
                            }
                        }
                    }
                    if !deck.mainDeck.isEmpty {
                        Section("Main deck (\(deck.mainDeck.reduce(0) { $0 + $1.count }))") {
                            ForEach(deck.mainDeck, id: \.cardId) { entry in
                                entryRow(entry, slot: .mainDeck, deck: deck)
                            }
                        }
                    }
                    if !deck.sideDeck.isEmpty {
                        Section("Side deck") {
                            ForEach(deck.sideDeck, id: \.cardId) { entry in
                                entryRow(entry, slot: .sideDeck, deck: deck)
                            }
                        }
                    }
                    if !deck.runes.isEmpty {
                        Section("Runes (\(deck.runes.reduce(0) { $0 + $1.count }))") {
                            ForEach(deck.runes, id: \.cardId) { entry in
                                entryRow(entry, slot: .rune, deck: deck)
                            }
                        }
                    }
                }
                .navigationTitle(deck.name)
            } else {
                Text("Deck deleted")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func entryRow(_ entry: DecklistEntry, slot: DeckSlot, deck: Decklist) -> some View {
        HStack {
            Text(entry.cardName)
            Spacer()
            if slot != .legend && slot != .champion {
                Button {
                    store.decrement(entry, in: deck, slot: slot)
                } label: {
                    Text("−")
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                }
                .buttonStyle(.plain)

                Text("×\(entry.count)")
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 32)

                Button {
                    // Re-adding by entry: count bump only needs id/name.
                    store.add(placeholderCard(for: entry), to: deck, slot: slot)
                } label: {
                    Text("+")
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    store.remove(entry, from: deck, slot: slot)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Minimal Card stand-in so slot-aware add() can bump counts without a
    /// CardStore lookup. Only id and name are read on this path.
    private func placeholderCard(for entry: DecklistEntry) -> Card {
        Card(id: entry.cardId,
             name: entry.cardName,
             riftboundId: nil,
             collectorNumber: nil,
             attributes: nil,
             classification: nil,
             text: nil,
             set: nil,
             media: nil,
             tags: nil,
             orientation: nil,
             metadata: nil)
    }
}
