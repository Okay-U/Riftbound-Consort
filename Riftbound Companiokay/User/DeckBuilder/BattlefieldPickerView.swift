//
//  BattlefieldPickerView.swift
//  Riftbound Companiokay
//

import SwiftUI

struct BattlefieldPickerView: View {
    @ObservedObject var state: DeckBuilderState
    @EnvironmentObject var cardStore: CardStore
    @State private var query: String = ""

    private let columns = [
        GridItem(.adaptive(minimum: 200), spacing: 12)
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
            counterBar
            searchField

            if battlefields.isEmpty {
                Spacer()
                ContentUnavailableView("No battlefields",
                                       systemImage: "map")
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

    private var counterBar: some View {
        let target = DeckBuilderState.battlefieldTarget
        let current = state.battlefields.count
        return HStack {
            Image(systemName: "map.fill")
                .foregroundStyle(.secondary)
            Text("Battlefields")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(current) / \(target)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(current == target ? .green : .secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.thinMaterial)
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search battlefields", text: $query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled(true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.thinMaterial)
        )
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }
}
