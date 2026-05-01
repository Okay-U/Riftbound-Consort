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

                pageForSection
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
                }
            }
            .onAppear {
                cardStore.loadIfNeeded()
                if !didLoad {
                    if let deck = decklistStore.lists.first(where: { $0.id == deckId }) {
                        state.loadFromExisting(deck, cardPool: cardStore.allCards)
                    }
                    didLoad = true
                }
            }
        }
        .interactiveDismissDisabled(true)
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
