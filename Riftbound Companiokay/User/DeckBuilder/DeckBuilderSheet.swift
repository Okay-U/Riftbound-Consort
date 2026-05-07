//
//  DeckBuilderSheet.swift
//  Riftbound Companiokay
//

import SwiftUI

struct DeckBuilderSheet: View {
    @EnvironmentObject var decklistStore: DecklistStore
    @EnvironmentObject var cardStore: CardStore
    @StateObject private var state = DeckBuilderState()
    @Environment(\.dismiss) private var dismiss

    @State private var step: DeckBuilderState.Step = .legend
    @AppStorage("didSeeBuilderTip") private var didSeeBuilderTip: Bool = false
    @State private var showBuilderTip: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                pageForCurrentStep

                if showBuilderTip {
                    BuilderTipOverlay {
                        withAnimation { showBuilderTip = false }
                        didSeeBuilderTip = true
                    }
                    .zIndex(10)
                }
            }
            .navigationTitle(step.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(primaryLabel) { advance() }
                        .disabled(!canAdvance)
                }
            }
            .onAppear {
                cardStore.loadIfNeeded()
                if !didSeeBuilderTip {
                    withAnimation { showBuilderTip = true }
                }
            }
        }
        .interactiveDismissDisabled(true)
    }

    // MARK: - Step routing

    @ViewBuilder
    private var pageForCurrentStep: some View {
        switch step {
        case .legend:      LegendPickerView(state: state)
        case .champion:    ChampionPickerView(state: state)
        case .battlefield: BattlefieldPickerView(state: state)
        case .mainDeck:    CardPoolPickerView(state: state, slot: .mainDeck)
        case .sideDeck:    CardPoolPickerView(state: state, slot: .sideDeck)
        case .runePool:    RunePoolPickerView(state: state)
        case .finalize:    BuilderFinalizeView(state: state)
        }
    }

    private var canAdvance: Bool {
        switch step {
        case .legend:      return state.canAdvanceFromLegend
        case .champion:    return state.canAdvanceFromChampion
        case .battlefield: return state.canAdvanceFromBattlefield
        case .mainDeck:    return state.canAdvanceFromMain
        case .sideDeck:    return state.canAdvanceFromSide
        case .runePool:    return state.canAdvanceFromRunes
        case .finalize:    return state.canSave
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

// MARK: - Placeholders (replaced in later steps)

private struct LegendPickerPlaceholder: View {
    var body: some View {
        ContentUnavailableView("Legend picker (Step 3)",
                               systemImage: "crown")
    }
}

private struct ChampionPickerPlaceholder: View {
    var body: some View {
        ContentUnavailableView("Champion picker (Step 4)",
                               systemImage: "person.crop.square")
    }
}

private struct BattlefieldPickerPlaceholder: View {
    var body: some View {
        ContentUnavailableView("Battlefield picker (Step 5)",
                               systemImage: "map")
    }
}

private struct MainDeckPickerPlaceholder: View {
    var body: some View {
        ContentUnavailableView("Main deck builder (Step 6)",
                               systemImage: "rectangle.stack")
    }
}

private struct SideDeckPickerPlaceholder: View {
    var body: some View {
        ContentUnavailableView("Sideboard builder (Step 6)",
                               systemImage: "rectangle.stack.badge.plus")
    }
}

private struct FinalizePlaceholder: View {
    var body: some View {
        ContentUnavailableView("Save form (Step 7)",
                               systemImage: "square.and.arrow.down")
    }
}
