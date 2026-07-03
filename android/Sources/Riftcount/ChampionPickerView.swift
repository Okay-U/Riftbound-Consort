import SwiftUI

struct ChampionPickerView: View {
    let state: DeckBuilderState
    @Environment(CardStore.self) var cardStore

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var champions: [Card] {
        guard let legend = state.legend else { return [] }
        let pool = cardStore.allCards.filter {
            $0.isChampion && $0.matchesLegend(legend)
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

    var body: some View {
        VStack(spacing: 0) {
            legendHeader

            if champions.isEmpty {
                Spacer()
                EmptyStateView(title: "No champions found",
                               message: "No cards match this legend by tag or name.")
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(champions) { card in
                            Button {
                                state.setChampion(card)
                            } label: {
                                CardThumbCell(
                                    card: card,
                                    isSelected: state.champion?.id == card.id
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

    @ViewBuilder
    private var legendHeader: some View {
        if let legend = state.legend {
            HStack(spacing: 10) {
                Text("Legend")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(legend.name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.15))
            )
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
    }
}
