import SwiftUI

/// Deck-builder wizard host. Custom top bar instead of navigation toolbar
/// (toolbar placement inside Android bottom sheets is unreliable).
struct DeckBuilderSheet: View {
    @Environment(DecklistStore.self) var decklistStore
    @Environment(CardStore.self) var cardStore
    @Environment(\.dismiss) var dismiss
    @State var state = DeckBuilderState()
    @State var step: DeckBuilderState.Step = .legend
    @AppStorage("didSeeBuilderTip") var didSeeBuilderTip: Bool = false
    @State var showBuilderTip: Bool = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topBar
                pageForCurrentStep
            }

            if showBuilderTip {
                BuilderTipOverlay {
                    withAnimation { showBuilderTip = false }
                    didSeeBuilderTip = true
                }
                .zIndex(10)
            }
        }
        .onAppear {
            cardStore.loadIfNeeded()
            if !didSeeBuilderTip {
                showBuilderTip = true
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                if let prev = DeckBuilderState.Step(rawValue: step.rawValue - 1) {
                    step = prev
                } else {
                    dismiss()
                }
            } label: {
                Text(step == .legend ? "Cancel" : "Back")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(step.title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .lineLimit(1)

            Spacer()

            Button {
                advance()
            } label: {
                Text(primaryLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(canAdvance ? Color.accentColor : Color.secondary)
            }
            .disabled(!canAdvance)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    // MARK: - Step routing

    @ViewBuilder
    private var pageForCurrentStep: some View {
        switch step {
        case .legend: LegendPickerView(state: state)
        case .champion: ChampionPickerView(state: state)
        case .battlefield: BattlefieldPickerView(state: state)
        case .mainDeck: CardPoolPickerView(state: state, slot: .mainDeck)
        case .sideDeck: CardPoolPickerView(state: state, slot: .sideDeck)
        case .runePool: RunePoolPickerView(state: state)
        case .finalize: BuilderFinalizeView(state: state)
        }
    }

    private var canAdvance: Bool {
        switch step {
        case .legend: return state.canAdvanceFromLegend
        case .champion: return state.canAdvanceFromChampion
        case .battlefield: return state.canAdvanceFromBattlefield
        case .mainDeck: return state.canAdvanceFromMain
        case .sideDeck: return state.canAdvanceFromSide
        case .runePool: return state.canAdvanceFromRunes
        case .finalize: return state.canSave
        }
    }

    private var primaryLabel: String {
        step == .finalize ? "Save" : "Next"
    }

    private func advance() {
        if step == .finalize {
            state.finalize(into: decklistStore, runePool: cardStore.allCards)
            dismiss()
            return
        }
        if let next = DeckBuilderState.Step(rawValue: step.rawValue + 1) {
            step = next
        }
    }
}
