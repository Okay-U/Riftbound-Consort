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
