import SwiftUI

struct BattlefieldPickerView: View {
    let state: DeckBuilderState
    @Environment(CardStore.self) var cardStore
    @State var query: String = ""

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var battlefields: [Card] {
        var pool = cardStore.allCards.filter { $0.isBattlefield }
        let q = query.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            pool = pool.filter { $0.name.localizedCaseInsensitiveContains(q) }
        }
        var seen: Set<String> = []
        var deduped: [Card] = []
        for card in pool {
            if seen.insert(card.id).inserted { deduped.append(card) }
        }
        return deduped.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func isSelected(_ card: Card) -> Bool {
        state.battlefields.contains(where: { $0.id == card.id })
    }

    var body: some View {
        VStack(spacing: 0) {
            BuilderCounterBar(
                title: "Battlefields",
                trailing: "\(state.battlefields.count) / \(DeckBuilderState.battlefieldTarget)",
                complete: state.battlefields.count == DeckBuilderState.battlefieldTarget
            )
            BuilderSearchField(prompt: "Search battlefields", query: $query)

            if battlefields.isEmpty {
                Spacer()
                EmptyStateView(title: "No battlefields")
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(battlefields) { card in
                            Button {
                                state.toggleBattlefield(card)
                            } label: {
                                CardThumbCell(
                                    card: card,
                                    isSelected: isSelected(card),
                                    dimmed: !isSelected(card)
                                        && state.battlefields.count >= DeckBuilderState.battlefieldTarget
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
                }
            }
        }
    }
}
