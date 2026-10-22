//
//  ShortlistView.swift
//  Riftbound Companiokay
//

import SwiftUI

/// The cards kept in mind (Okay, 2026-10-22, as on Android), grouped like a deck. A card opens its detail; the
/// star takes it off. A card taken off stays, dimmed, until the screen closes, so a second tap puts it back.
struct ShortlistView: View {
    @EnvironmentObject var shortlist: ShortlistStore
    @EnvironmentObject var cardStore: CardStore
    @EnvironmentObject var decklistStore: DecklistStore
    /// Taken when the screen opens, so taking a card off does not pull it out from under the finger.
    @State private var shown: [String]?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    private static let typeOrder = ["unit", "spell", "gear"]

    private var groups: [(label: String, cards: [Card])] {
        let byId = Dictionary(cardStore.allCards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let cards = (shown ?? shortlist.ids).compactMap { byId[$0] }
        let grouped = Dictionary(grouping: cards) { $0.classification?.type?.lowercased() ?? "" }
        func rank(_ type: String) -> Int { Self.typeOrder.firstIndex(of: type) ?? Self.typeOrder.count }
        return grouped.keys.sorted { (rank($0), $0) < (rank($1), $1) }.map { type in
            let sorted = grouped[type, default: []].sorted {
                ($0.attributes?.energy ?? Int.max, $0.name) < ($1.attributes?.energy ?? Int.max, $1.name)
            }
            return (Self.label(type), sorted)
        }
    }

    private static func label(_ type: String) -> String {
        switch type {
        case "unit": return "Units"
        case "spell": return "Spells"
        case "gear": return "Gear"
        case "": return "Other"
        default: return type.capitalized
        }
    }

    var body: some View {
        let groups = groups
        Group {
            if groups.isEmpty {
                ContentUnavailableView(
                    "No cards kept yet",
                    systemImage: "star",
                    description: Text("Save a card on its Add to Deck sheet in Cards. It waits here and in the deck builder.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(groups, id: \.label) { group in
                            HStack {
                                Text(group.label.uppercased())
                                Spacer()
                                Text("\(group.cards.count)")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(group.cards) { card in cell(card) }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 16)
                }
            }
        }
        .navigationTitle("Shortlist")
        .onAppear {
            cardStore.loadIfNeeded()
            if shown == nil { shown = shortlist.ids }
        }
    }

    private func cell(_ card: Card) -> some View {
        let on = shortlist.contains(card.id)
        return ZStack(alignment: .topTrailing) {
            NavigationLink {
                CardDetailView(card: card)
                    .environmentObject(decklistStore)
            } label: {
                CardGalleryCell(card: card)
            }
            .buttonStyle(.plain)
            .opacity(on ? 1 : 0.4)

            Button {
                shortlist.toggle(card.id)
                Haptics.selection()
            } label: {
                Image(systemName: on ? "star.fill" : "star")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(on ? Color.yellow : Color.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.black.opacity(0.65)))
            }
            .buttonStyle(.plain)
            .padding(6)
            .accessibilityLabel(on ? "Take \(card.name) off the shortlist" : "Put \(card.name) back on the shortlist")
        }
    }
}
