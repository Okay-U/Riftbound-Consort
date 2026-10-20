//
//  DeckEditorSheet.swift
//  Riftbound Companiokay
//

import SwiftUI

struct DeckEditorSheet: View {
    let deckId: UUID
    @EnvironmentObject var decklistStore: DecklistStore
    @EnvironmentObject var cardStore: CardStore
    @StateObject private var state = DeckBuilderState()
    @Environment(\.dismiss) private var dismiss

    @State private var section: EditorSection = .mainDeck
    @State private var didLoad: Bool = false

    enum EditorSection: String, CaseIterable, Identifiable {
        case mainDeck     = "Main"
        case sideDeck     = "Side"
        case runes        = "Runes"
        case battlefields = "Battlefields"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $section) {
                    ForEach(EditorSection.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

                if didLoad {
                    pageForSection
                } else {
                    loadingCards
                }
            }
            .navigationTitle("Edit Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        state.commitEdits(toDeckId: deckId,
                                          in: decklistStore,
                                          runePool: cardStore.allCards)
                        dismiss()
                    }
                    // Saving before the deck was read against the card list would drop its
                    // battlefields and runes.
                    .disabled(!didLoad)
                }
            }
            .onAppear { cardStore.loadIfNeeded() }
            // The deck is read once the card list is there, and after old card ids were
            // remapped (first start of 3.5): editing old ids would write them back.
            .task(id: cardStore.allCards.isEmpty) {
                guard !didLoad, !cardStore.allCards.isEmpty else { return }
                await decklistStore.migrateLegacyIDs(to: cardStore.allCards)
                if let deck = decklistStore.lists.first(where: { $0.id == deckId }) {
                    state.loadFromExisting(deck, cardPool: cardStore.allCards)
                }
                didLoad = true
            }
        }
        .interactiveDismissDisabled(true)
    }

    private var loadingCards: some View {
        VStack(spacing: 10) {
            if let error = cardStore.loadError {
                Text("The card list couldn't be loaded, so the deck can't be edited yet.")
                    .font(.subheadline.weight(.semibold))
                Text(error).font(.footnote).foregroundStyle(.secondary)
            } else {
                ProgressView("Loading cards…")
            }
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var pageForSection: some View {
        switch section {
        case .mainDeck:     CardPoolPickerView(state: state, slot: .mainDeck)
        case .sideDeck:     CardPoolPickerView(state: state, slot: .sideDeck)
        case .runes:        RunePoolPickerView(state: state)
        case .battlefields: BattlefieldPickerView(state: state)
        }
    }
}
