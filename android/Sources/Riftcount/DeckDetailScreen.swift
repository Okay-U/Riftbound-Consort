import SwiftUI

/// Deck detail, ported from the iOS DeckDetailView.
/// Parity: legality section, champion swap menu, per-slot sections with
/// count controls and copy-cap enforcement, rename + editor.
/// Deferred: export (DeckTextFormat), draw hand, stats links.
struct DeckDetailScreen: View {
    let deckID: UUID
    @Environment(DecklistStore.self) var store
    @Environment(CardStore.self) var cardStore
    @Environment(\.dismiss) var dismiss
    @State var confirmDelete = false
    @State var showEditor = false
    @State var showRename = false
    @State var showDrawHand = false
    @State var newName = ""

    enum StatsRoute: Hashable {
        case stats(UUID)
        case odds(UUID)
    }

    private var current: Decklist? {
        store.lists.first { $0.id == deckID }
    }

    var body: some View {
        Group {
            if let deck = current {
                detailList(deck)
            } else {
                Text("Deck deleted")
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { cardStore.loadIfNeeded() }
    }

    private func detailList(_ deck: Decklist) -> some View {
        let legality = DeckLegality.evaluate(deck)

        return List {
            legalitySection(legality)
            championSection(deck)
            singularSection(title: "Legend (1)",
                            entry: deck.legend,
                            slot: .legend,
                            deck: deck)
            multiSection(title: "Battlefields",
                         expected: "3",
                         entries: deck.battlefields,
                         slot: .battlefield,
                         deck: deck)
            multiSection(title: "Main deck",
                         expected: "39",
                         entries: deck.mainDeck,
                         slot: .mainDeck,
                         deck: deck)
            multiSection(title: "Side deck",
                         expected: "0 or 8",
                         entries: deck.sideDeck,
                         slot: .sideDeck,
                         deck: deck)
            multiSection(title: "Runes",
                         expected: "12",
                         entries: deck.runes,
                         slot: .rune,
                         deck: deck)

            Section("Stats") {
                NavigationLink(value: StatsRoute.stats(deck.id)) {
                    Text("Deck stats")
                }
                NavigationLink(value: StatsRoute.odds(deck.id)) {
                    Text("Draw odds")
                }
                NavigationLink(value: GameHistoryRoute(scope: .deck(deck.id), title: deck.name)) {
                    Text("Game history")
                }
                Button {
                    showDrawHand = true
                } label: {
                    HStack {
                        Text("Draw hand")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationDestination(for: StatsRoute.self) { route in
            switch route {
            case .stats(let id):
                if let d = store.lists.first(where: { $0.id == id }) {
                    DeckStatsView(deck: d)
                }
            case .odds(let id):
                if let d = store.lists.first(where: { $0.id == id }) {
                    DrawProbabilityView(deck: d)
                }
            }
        }
        .sheet(isPresented: $showDrawHand) {
            DrawHandView(deck: deck)
        }
        .navigationTitle(deck.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // Native share sheet instead of iOS clipboard export.
                ShareLink(item: DeckTextFormat.export(deck: deck,
                                                      cardPool: cardStore.allCards)) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEditor = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Rename") {
                    newName = deck.name
                    showRename = true
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { confirmDelete = true } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            DeckEditorSheet(deckId: deck.id)
        }
        .sheet(isPresented: $showRename) {
            RenameDeckSheet(name: $newName) { name in
                store.rename(deck, to: name)
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
    }

    // MARK: - Lookups & caps (ported from iOS)

    private func card(for entry: DecklistEntry) -> Card? {
        cardStore.allCards.first(where: { $0.id == entry.cardId })
    }

    private func mainSideIdentityCount(_ key: String, deck: Decklist) -> Int {
        let entries = deck.mainDeck + deck.sideDeck
        var n = entries
            .filter { e in
                guard let c = card(for: e) else { return false }
                return DeckBuilderState.identityKey(for: c) == key
            }
            .reduce(0) { $0 + $1.count }
        if let champEntry = deck.champion,
           let champCard = card(for: champEntry),
           DeckBuilderState.identityKey(for: champCard) == key {
            n += 1
        }
        return n
    }

    private func mainSideSignatureCount(deck: Decklist) -> Int {
        let entries = deck.mainDeck + deck.sideDeck
        return entries
            .filter { e in card(for: e)?.metadata?.signature == true }
            .reduce(0) { $0 + $1.count }
    }

    private func canIncrement(entry: DecklistEntry, slot: DeckSlot, deck: Decklist) -> Bool {
        guard let c = card(for: entry) else { return false }

        let mainTotal = deck.mainDeck.reduce(0) { $0 + $1.count }
        let sideTotal = deck.sideDeck.reduce(0) { $0 + $1.count }
        let bfTotal = deck.battlefields.reduce(0) { $0 + $1.count }
        let runeTotal = deck.runes.reduce(0) { $0 + $1.count }

        switch slot {
        case .mainDeck: if mainTotal >= 39 { return false }
        case .sideDeck: if sideTotal >= 8 { return false }
        case .battlefield: if bfTotal >= 3 { return false }
        case .rune: if runeTotal >= 12 { return false }
        case .champion, .legend: return false
        }

        if slot == .mainDeck || slot == .sideDeck {
            let key = DeckBuilderState.identityKey(for: c)
            if mainSideIdentityCount(key, deck: deck) >= DeckBuilderState.copyLimit { return false }
            if c.metadata?.signature == true,
               mainSideSignatureCount(deck: deck) >= DeckBuilderState.signatureLimit {
                return false
            }
        }
        return true
    }

    // MARK: - Champion swap

    private func championCandidates(_ deck: Decklist) -> [Card] {
        guard let chosenEntry = deck.champion,
              let chosenCard = card(for: chosenEntry) else { return [] }
        var found: [Card] = [chosenCard]
        var seen: Set<String> = [chosenCard.id]

        guard let legendEntry = deck.legend,
              let legendCard = card(for: legendEntry) else { return found }

        for entry in deck.mainDeck + deck.sideDeck {
            guard let c = card(for: entry),
                  c.isChampion,
                  c.matchesLegend(legendCard),
                  !seen.contains(c.id) else { continue }
            found.append(c)
            seen.insert(c.id)
        }
        return found.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func swapChampion(to newCard: Card, deck: Decklist) {
        guard let oldEntry = deck.champion,
              newCard.id != oldEntry.cardId else { return }
        guard let oldCard = card(for: oldEntry) else { return }

        let mainEntry = deck.mainDeck.first(where: { $0.cardId == newCard.id })
        let sideEntry = deck.sideDeck.first(where: { $0.cardId == newCard.id })

        let sourceSlot: DeckSlot
        let sourceEntry: DecklistEntry
        if let e = mainEntry { sourceSlot = .mainDeck; sourceEntry = e }
        else if let e = sideEntry { sourceSlot = .sideDeck; sourceEntry = e }
        else { return }

        // 1. Pull new card out of its source slot.
        store.decrement(sourceEntry, in: deck, slot: sourceSlot)
        // 2. Put old champion back into main deck.
        store.add(oldCard, to: deck, slot: .mainDeck)
        // 3. Replace champion slot with the new card.
        store.add(newCard, to: deck, slot: .champion)
    }

    // MARK: - Sections

    private func legalitySection(_ legality: DeckLegality) -> some View {
        Section {
            HStack(spacing: 10) {
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
                Text(legality.isLegal ? "Legal deck" : "Illegal deck")
                    .font(.headline)
            }
            if !legality.isLegal {
                ForEach(legality.issues, id: \.self) { issue in
                    Text(issue)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func championSection(_ deck: Decklist) -> some View {
        Section("Champion (1)") {
            if let entry = deck.champion {
                let candidates = championCandidates(deck)
                if candidates.count > 1 {
                    Menu {
                        ForEach(candidates, id: \.id) { c in
                            Button {
                                swapChampion(to: c, deck: deck)
                            } label: {
                                if c.id == entry.cardId {
                                    Text("✓ \(c.name)")
                                } else {
                                    Text(c.name)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(entry.cardName)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("⇅")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text(entry.cardName)
                }
            } else {
                Text("Not set")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func singularSection(title: String,
                                 entry: DecklistEntry?,
                                 slot: DeckSlot,
                                 deck: Decklist) -> some View {
        Section(title) {
            if let entry {
                HStack {
                    Text(entry.cardName)
                    Spacer()
                    Button {
                        store.remove(entry, from: deck, slot: slot)
                    } label: {
                        MinusCircleGlyph(enabled: true)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("Not set")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func multiSection(title: String,
                              expected: String,
                              entries: [DecklistEntry],
                              slot: DeckSlot,
                              deck: Decklist) -> some View {
        let total = entries.reduce(0) { $0 + $1.count }
        Section("\(title) (\(total)/\(expected))") {
            if entries.isEmpty {
                Text("Empty")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries, id: \.cardId) { entry in
                    entryRow(entry, slot: slot, deck: deck)
                }
            }
        }
    }

    private func entryRow(_ entry: DecklistEntry, slot: DeckSlot, deck: Decklist) -> some View {
        let plusEnabled = canIncrement(entry: entry, slot: slot, deck: deck)
        return HStack {
            Text(entry.cardName)
            Spacer()
            HStack(spacing: 10) {
                Button {
                    store.decrement(entry, in: deck, slot: slot)
                } label: {
                    MinusCircleGlyph(enabled: true)
                }
                .buttonStyle(.plain)

                Text("×\(entry.count)")
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 28)

                Button {
                    if let c = card(for: entry) {
                        store.add(c, to: deck, slot: slot)
                    }
                } label: {
                    PlusCircleGlyph(enabled: plusEnabled)
                }
                .buttonStyle(.plain)
                .disabled(!plusEnabled)
            }
        }
    }
}

// MARK: - Drawn ± glyphs (minus.circle / plus.circle are not in SkipUI's map)

struct MinusCircleGlyph: View {
    let enabled: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(enabled ? Color.primary : Color.secondary.opacity(0.4), lineWidth: 1.5)
                .frame(width: 22, height: 22)
            Capsule()
                .fill(enabled ? Color.primary : Color.secondary.opacity(0.4))
                .frame(width: 10, height: 2)
        }
    }
}

struct PlusCircleGlyph: View {
    let enabled: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(enabled ? Color.primary : Color.secondary.opacity(0.4), lineWidth: 1.5)
                .frame(width: 22, height: 22)
            Capsule()
                .fill(enabled ? Color.primary : Color.secondary.opacity(0.4))
                .frame(width: 10, height: 2)
            Capsule()
                .fill(enabled ? Color.primary : Color.secondary.opacity(0.4))
                .frame(width: 2, height: 10)
        }
    }
}

struct RenameDeckSheet: View {
    @Binding var name: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SheetHeader(title: "Rename Deck") { dismiss() }

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)

            Button {
                let trimmed = name.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                onSave(trimmed)
                dismiss()
            } label: {
                Text("Save")
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
