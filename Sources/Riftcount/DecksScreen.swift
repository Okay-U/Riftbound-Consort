import SwiftUI

/// Decks tab, Wave 2c: deck list, create, delete, simple deck detail with
/// per-slot sections and count controls. Builder wizard, import/export, and
/// stats come in later waves.
struct DecksScreen: View {
    @Environment(DecklistStore.self) var store
    @Environment(CardStore.self) var cardStore
    @State var showNewDeck = false
    @State var showImport = false

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

                            NavigationLink(value: GameHistoryRoute(scope: .all, title: "All Games")) {
                                historyRow
                            }
                            .buttonStyle(.plain)
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
            .navigationDestination(for: GameHistoryRoute.self) { route in
                GameHistoryView(scope: route.scope, title: route.title)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showImport = true } label: {
                        // square.and.arrow.down is unmapped; arrow rotated
                        // to point down reads as import.
                        Image(systemName: "arrow.forward")
                            .rotationEffect(Angle(degrees: 90))
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showNewDeck = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewDeck) {
                DeckBuilderSheet()
            }
            .sheet(isPresented: $showImport) {
                ImportDeckSheet()
            }
            .onAppear { cardStore.loadIfNeeded() }
        }
    }

    @Environment(GameRecordStore.self) var recordStore

    private var historyRow: some View {
        let wins = recordStore.records.filter { $0.result == .won }.count
        let losses = recordStore.records.filter { $0.result == .lost }.count
        let total = wins + losses
        let pct = total == 0 ? 0 : Int(Double(wins) / Double(total) * 100)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(total == 0 ? "Game History" : "\(total) games")
                    .font(.subheadline.weight(.semibold))
                if total > 0 {
                    Text("\(wins)W – \(losses)L · \(pct)% winrate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .cardSurface()
    }

}

/// iOS-parity deck row: gradient card, name + legend, win-rate bar,
/// legality badge.
struct DeckRowCard: View {
    let deck: Decklist
    @Environment(GameRecordStore.self) var gameRecordStore

    private var legality: DeckLegality { DeckLegality.evaluate(deck) }

    private var wins: Int { gameRecordStore.winLoss(for: deck.id).wins }
    private var losses: Int { gameRecordStore.winLoss(for: deck.id).losses }
    private var totalGames: Int { wins + losses }
    private var winRate: Double {
        totalGames == 0 ? 0 : Double(wins) / Double(totalGames)
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(deck.name)
                    .font(.headline)
                Text(deck.legend?.cardName ?? "No legend selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                winRateBar
            }
            Spacer()
            legalityBadge
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .cardSurface()
    }

    private var winRateBar: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text("\(wins)–\(losses)")
                    .font(.caption)
                Text("·")
                    .foregroundStyle(.secondary)
                Text(totalGames == 0 ? "no games" : "\(Int(winRate * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                    Capsule()
                        .fill(Color.green)
                        .frame(width: geo.size.width * CGFloat(winRate))
                }
            }
            .frame(height: 4)
        }
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
