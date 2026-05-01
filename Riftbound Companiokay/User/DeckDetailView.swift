//
//  DeckDetailView.swift
//  Riftbound Companiokay
//

import SwiftUI
import UIKit

struct DeckDetailView: View {
    let deck: Decklist
    @EnvironmentObject var store: DecklistStore
    @EnvironmentObject var cardStore: CardStore
    @State private var showRenameAlert: Bool = false
    @State private var newName: String = ""
    @State private var showEditor: Bool = false
    @State private var showExportToast: Bool = false
    @State private var showDrawHand: Bool = false

    private var current: Decklist {
        store.lists.first(where: { $0.id == deck.id }) ?? deck
    }
    private var legality: DeckLegality { DeckLegality.evaluate(current) }

    private func card(for entry: DecklistEntry) -> Card? {
        cardStore.allCards.first(where: { $0.id == entry.cardId })
    }

    private func mainSideIdentityCount(_ key: String) -> Int {
        let entries = current.mainDeck + current.sideDeck
        var n = entries
            .filter { e in
                guard let c = card(for: e) else { return false }
                return DeckBuilderState.identityKey(for: c) == key
            }
            .reduce(0) { $0 + $1.count }
        if let champEntry = current.champion,
           let champCard = card(for: champEntry),
           DeckBuilderState.identityKey(for: champCard) == key {
            n += 1
        }
        return n
    }

    private func mainSideSignatureCount() -> Int {
        let entries = current.mainDeck + current.sideDeck
        return entries
            .filter { e in card(for: e)?.metadata?.signature == true }
            .reduce(0) { $0 + $1.count }
    }

    private func canIncrement(entry: DecklistEntry, slot: DeckSlot) -> Bool {
        guard let c = card(for: entry) else { return false }

        let mainTotal = current.mainDeck.reduce(0) { $0 + $1.count }
        let sideTotal = current.sideDeck.reduce(0) { $0 + $1.count }
        let bfTotal   = current.battlefields.reduce(0) { $0 + $1.count }
        let runeTotal = current.runes.reduce(0) { $0 + $1.count }

        switch slot {
        case .mainDeck:    if mainTotal >= 39 { return false }
        case .sideDeck:    if sideTotal >= 8  { return false }
        case .battlefield: if bfTotal   >= 3  { return false }
        case .rune:        if runeTotal >= 12 { return false }
        case .champion, .legend: return false
        }

        if slot == .mainDeck || slot == .sideDeck {
            let key = DeckBuilderState.identityKey(for: c)
            if mainSideIdentityCount(key) >= DeckBuilderState.copyLimit { return false }
            if c.metadata?.signature == true,
               mainSideSignatureCount() >= DeckBuilderState.signatureLimit {
                return false
            }
        }
        return true
    }

    var body: some View {
        List {
            legalitySection
            championSection
            singularSection(title: "Legend (1)",
                            entry: current.legend,
                            slot: .legend)
            multiSection(title: "Battlefields",
                         expected: "3",
                         entries: current.battlefields,
                         slot: .battlefield)
            multiSection(title: "Main deck",
                         expected: "39",
                         entries: current.mainDeck,
                         slot: .mainDeck)
            multiSection(title: "Side deck",
                         expected: "0 or 8",
                         entries: current.sideDeck,
                         slot: .sideDeck)
            multiSection(title: "Runes",
                         expected: "12",
                         entries: current.runes,
                         slot: .rune)
            statsPlaceholderSection
        }
        .navigationTitle(current.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showDrawHand = true
                } label: {
                    Image(systemName: "rectangle.portrait.on.rectangle.portrait")
                }
                Button {
                    exportToClipboard()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                Button("Edit") {
                    showEditor = true
                }
                Button("Rename") {
                    newName = current.name
                    showRenameAlert = true
                }
            }
        }
        .alert("Copied",
               isPresented: $showExportToast) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Decklist copied to clipboard.")
        }
        .sheet(isPresented: $showEditor) {
            DeckEditorSheet(deckId: current.id)
        }
        .sheet(isPresented: $showDrawHand) {
            DrawHandView(deck: current)
                .environmentObject(cardStore)
        }
        .alert("Rename Deck", isPresented: $showRenameAlert) {
            TextField("Name", text: $newName)
            Button("Save") {
                let trimmed = newName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                store.rename(current, to: trimmed)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Sections

    private var legalitySection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: legality.isLegal
                      ? "checkmark.seal.fill"
                      : "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(legality.isLegal ? .green : .orange)
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

    private func exportToClipboard() {
        let text = DeckTextFormat.export(deck: current,
                                         cardPool: cardStore.allCards)
        UIPasteboard.general.string = text
        showExportToast = true
    }

    // MARK: - Champion swap

    private var championCandidates: [Card] {
        guard let chosenEntry = current.champion,
              let chosenCard  = card(for: chosenEntry) else { return [] }
        var found: [Card] = [chosenCard]
        var seen: Set<String> = [chosenCard.id]

        guard let legendEntry = current.legend,
              let legendCard  = card(for: legendEntry) else { return found }

        for entry in current.mainDeck + current.sideDeck {
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

    private func swapChampion(to newCard: Card) {
        guard let oldEntry = current.champion,
              newCard.id != oldEntry.cardId else { return }
        guard let oldCard = card(for: oldEntry) else { return }

        let mainEntry = current.mainDeck.first(where: { $0.cardId == newCard.id })
        let sideEntry = current.sideDeck.first(where: { $0.cardId == newCard.id })

        let sourceSlot: DeckSlot
        let sourceEntry: DecklistEntry
        if let e = mainEntry { sourceSlot = .mainDeck; sourceEntry = e }
        else if let e = sideEntry { sourceSlot = .sideDeck; sourceEntry = e }
        else { return }

        // 1. Pull new card out of its source slot.
        store.decrement(sourceEntry, in: current, slot: sourceSlot)
        // 2. Put old champion back into main deck.
        store.add(oldCard, to: current, slot: .mainDeck)
        // 3. Replace champion slot with the new card.
        store.add(newCard, to: current, slot: .champion)
    }

    @ViewBuilder
    private var championSection: some View {
        Section("Champion (1)") {
            if let entry = current.champion {
                let candidates = championCandidates
                if candidates.count > 1 {
                    Menu {
                        ForEach(candidates, id: \.id) { c in
                            Button {
                                swapChampion(to: c)
                            } label: {
                                if c.id == entry.cardId {
                                    Label(c.name, systemImage: "checkmark")
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
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    HStack {
                        Text(entry.cardName)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                Text("Not set")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func singularSection(title: String,
                                 entry: DecklistEntry?,
                                 slot: DeckSlot) -> some View {
        Section(title) {
            if let entry {
                HStack {
                    Text(entry.cardName)
                    Spacer()
                    Button(role: .destructive) {
                        store.remove(entry, from: current, slot: slot)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("Not set")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func multiSection(title: String,
                              expected: String,
                              entries: [DecklistEntry],
                              slot: DeckSlot) -> some View {
        let total = entries.reduce(0) { $0 + $1.count }
        Section("\(title) (\(total)/\(expected))") {
            if entries.isEmpty {
                Text("Empty")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(entries, id: \.cardId) { entry in
                    HStack {
                        Text(entry.cardName)
                        Spacer()
                        HStack(spacing: 10) {
                            Button {
                                store.decrement(entry, in: current, slot: slot)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            Text("×\(entry.count)")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 28)
                            Button {
                                if let c = card(for: entry) {
                                    store.add(c, to: current, slot: slot)
                                }
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                            .buttonStyle(.plain)
                            .disabled(!canIncrement(entry: entry, slot: slot))
                            .foregroundStyle(canIncrement(entry: entry, slot: slot)
                                             ? .primary
                                             : Color.secondary.opacity(0.4))
                        }
                    }
                }
                .onDelete { offsets in
                    offsets.forEach {
                        store.remove(entries[$0], from: current, slot: slot)
                    }
                }
            }
        }
    }

    private var statsPlaceholderSection: some View {
        Section("Stats") {
            NavigationLink {
                DeckStatsView(deck: current)
            } label: {
                Label("Deck stats", systemImage: "chart.bar.fill")
            }
            NavigationLink {
                DrawProbabilityView(deck: current)
            } label: {
                Label("Draw odds", systemImage: "die.face.5")
            }
            NavigationLink {
                GameHistoryView(scope: .deck(current.id), title: current.name)
            } label: {
                Label("Game history", systemImage: "clock.arrow.circlepath")
            }
        }
    }
}
