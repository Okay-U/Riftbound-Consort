//
//  LegendPickerView.swift
//  Riftbound Companiokay
//

import SwiftUI

struct LegendPickerView: View {
    @ObservedObject var state: DeckBuilderState
    @EnvironmentObject var cardStore: CardStore
    @State private var query: String = ""

    private let columns = [
        GridItem(.adaptive(minimum: 130), spacing: 12)
    ]

    private var legends: [Card] {
        var pool = cardStore.allCards.filter { $0.isRareLegend }
        let q = query.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            pool = pool.filter {
                $0.name.localizedCaseInsensitiveContains(q)
            }
        }
        return pool.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField

            if cardStore.isLoading && legends.isEmpty {
                Spacer()
                ProgressView("Loading cards…")
                Spacer()
            } else if legends.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No legends",
                    systemImage: "magnifyingglass",
                    description: Text("Open the Cards tab once to fetch the database.")
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(legends) { card in
                            Button {
                                state.setLegend(card)
                            } label: {
                                CardThumbCell(
                                    card: card,
                                    isSelected: state.legend?.id == card.id
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

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search legends", text: $query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.thinMaterial)
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}
