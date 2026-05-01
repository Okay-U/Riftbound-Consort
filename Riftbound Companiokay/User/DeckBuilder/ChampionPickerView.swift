//
//  ChampionPickerView.swift
//  Riftbound Companiokay
//

import SwiftUI

struct ChampionPickerView: View {
    @ObservedObject var state: DeckBuilderState
    @EnvironmentObject var cardStore: CardStore

    private let columns = [
        GridItem(.adaptive(minimum: 130), spacing: 12)
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
                ContentUnavailableView(
                    "No champions found",
                    systemImage: "person.crop.square.badge.exclamationmark",
                    description: Text("No cards match this legend by tag or name.")
                )
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
                Image(systemName: "crown.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Legend")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(legend.name)
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.thinMaterial)
            )
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
    }
}
