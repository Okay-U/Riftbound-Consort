import SwiftUI

/// Edit-deck sheet reusing the wizard pickers, ported from iOS.
/// Custom top bar instead of navigation toolbar (sheet-toolbar lesson).
struct DeckEditorSheet: View {
    let deckId: UUID
    @Environment(DecklistStore.self) var decklistStore
    @Environment(CardStore.self) var cardStore
    @Environment(\.dismiss) var dismiss
    @State var state = DeckBuilderState()
    @State var section: EditorSection = .mainDeck
    @State var didLoad: Bool = false

    enum EditorSection: String, CaseIterable, Identifiable {
        case mainDeck = "Main"
        case sideDeck = "Side"
        case runes = "Runes"
        case battlefields = "Battlefields"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Edit Deck")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                Button {
                    state.commitEdits(toDeckId: deckId,
                                      in: decklistStore,
                                      runePool: cardStore.allCards)
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Picker("Section", selection: $section) {
                ForEach(EditorSection.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

            pageForSection
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

    @ViewBuilder
    private var pageForSection: some View {
        switch section {
        case .mainDeck: CardPoolPickerView(state: state, slot: .mainDeck)
        case .sideDeck: CardPoolPickerView(state: state, slot: .sideDeck)
        case .runes: RunePoolPickerView(state: state)
        case .battlefields: BattlefieldPickerView(state: state)
        }
    }
}
