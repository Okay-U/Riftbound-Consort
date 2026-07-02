import SwiftUI

/// Decks tab, Wave 2c: deck list, create, delete, simple deck detail with
/// per-slot sections and count controls. Builder wizard, import/export, and
/// stats come in later waves.
struct DecksScreen: View {
    @Environment(DecklistStore.self) var store
    @State var showNewDeck = false

    var body: some View {
        NavigationStack {
            Group {
                if store.lists.isEmpty {
                    VStack(spacing: 12) {
                        Text("No decks yet")
                            .font(.title3.weight(.semibold))
                        Text("Tap + to create your first deck.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("New Deck") { showNewDeck = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(store.lists) { deck in
                                NavigationLink(value: deck.id) {
                                    DeckRowCard(deck: deck)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
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
                DeckBuilderSheet()
            }
        }
    }

}

/// iOS-parity deck row: gradient card, name + legend, legality badge.
/// (Win-rate bar returns with the game-records port.)
struct DeckRowCard: View {
    let deck: Decklist

    private var legality: DeckLegality { DeckLegality.evaluate(deck) }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(deck.name)
                    .font(.headline)
                Text(deck.legend?.cardName ?? "No legend selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            legalityBadge
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .cardSurface()
    }

    private var summary: String {
        let mainCount = deck.mainDeck.reduce(0) { $0 + $1.count }
        var parts = ["\(mainCount) main"]
        if !deck.runes.isEmpty {
            parts.append("\(deck.runes.reduce(0) { $0 + $1.count }) runes")
        }
        return parts.joined(separator: " · ")
    }

    private var legalityBadge: some View {
        // checkmark.circle.fill is mapped; drawn triangle for issues.
        Group {
            if legality.isLegal {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            } else {
                Text("!")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.black)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.orange))
            }
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
    @Environment(\.dismiss) var dismiss
    @State var confirmDelete = false

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
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { confirmDelete = true } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
                .confirmationDialog("Delete this deck?",
                                    isPresented: $confirmDelete,
                                    titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        store.delete(deck)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                }
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
