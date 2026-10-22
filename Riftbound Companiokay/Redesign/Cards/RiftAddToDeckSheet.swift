//
//  RiftAddToDeckSheet.swift
//  Riftbound Companiokay
//
//  Add to deck (Android `AddToDeckSheet.kt`): the shortlist, then copies of the card per deck with a stepper,
//  following the builder's rules: a legend replaces the legend, a champion that fits fills the chosen slot
//  first, three copies across printings, three signature cards, three battlefields, twelve runes, 39 cards.
//  Decks the card cannot join are greyed out with the reason.
//

import SwiftUI

struct RiftAddToDeckSheet: View {
    let card: Card
    @EnvironmentObject private var decks: DecklistStore
    @EnvironmentObject private var cards: CardStore
    @EnvironmentObject private var shortlist: ShortlistStore
    @EnvironmentObject private var builder: DeckBuilderModel
    @AppStorage("currentTab") private var currentTab: String = TabKey.score
    @Environment(\.dismiss) private var dismiss
    @State private var toast: BoardToast?

    var body: some View {
        let index = Dictionary(cards.allCards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(intro)
                        .font(RiftFont.text(13, .regular))
                        .lineSpacing(4)
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.bottom, 14)
                    shortlistRow
                    ForEach(decks.lists) { deck in DeckRow(card: card, deck: deck, cards: index, onPlus: { plus(deck, index) }, onMinus: { minus(deck) }) }
                    if card.isLegend || card.isChampionUnit || DeckRules.eligible(card, legendDomains: []) {
                        newDeckButton
                    }
                }
                .padding(16)
            }
            .navigationTitle("Add \(card.title)")
            .navigationBarTitleDisplayMode(.inline)
        }
        .overlay(alignment: .bottom) {
            if let toast {
                HalfToast(text: toast.text)
                    .padding(.bottom, 24)
                    .id(toast.id)
                    .task(id: toast.id) {
                        try? await Task.sleep(for: .seconds(2.2))
                        if self.toast?.id == toast.id { self.toast = nil }
                    }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// Starts the builder on the Decks tab; a legend starts the deck, any other card waits for a legend it fits.
    private var newDeckButton: some View {
        Button {
            dismiss()
            builder.start(with: card)
            currentTab = TabKey.user
        } label: {
            Text("+ New deck with this card")
                .font(RiftFont.text(14, .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .overlay(Capsule().stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                .contentShape(Capsule())
        }
        .buttonStyle(PressScale(scale: 0.97))
        .padding(.top, 10)
    }

    private var intro: String {
        if decks.lists.isEmpty { return "No decks yet. Build one on the Decks tab." }
        if card.isLegend { return "A deck has one legend. Its domains decide which cards fit." }
        let max = DeckRules.maxCopies(card)
        return "Up to \(max) \(max == 1 ? "copy" : "copies") per deck. Decks outside the card’s domains are greyed out."
    }

    /// Keeps the card in mind for a deck to come (the builder's Shortlist chip, the Cards filter).
    private var shortlistRow: some View {
        let on = shortlist.contains(card.id)
        return HStack(spacing: 12) {
            Image(systemName: on ? "star.fill" : "star")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(on ? Color.black : .white)
                .frame(width: 44, height: 44)
                .background(on ? RiftColor.you : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text("Shortlist").font(RiftFont.text(15, .bold)).foregroundStyle(.white)
                Text("Keep it in mind for a deck · \(shortlist.ids.count) on it").font(RiftFont.text(12.5)).foregroundStyle(.white.opacity(0.66))
            }
            Spacer(minLength: 8)
            Pill(text: on ? "Saved" : "Save", height: 36, fill: on ? RiftColor.you : .white.opacity(0.12), ink: on ? .black : .white) {
                shortlist.toggle(card.id)
                Haptics.light()
                toast = BoardToast(text: shortlist.contains(card.id) ? "On your shortlist · find it in the builder" : "Off your shortlist")
            }
        }
        .padding(.vertical, 10)
    }

    private func plus(_ deck: Decklist, _ index: [String: Card]) {
        let next = DeckRules.add(card, to: deck, cards: index)
        decks.replace(next)
        Haptics.light()
        toast = BoardToast(text: "Added to \(deck.name) · \(DeckRules.count(card, in: next)) of \(DeckRules.maxCopies(card))")
    }

    private func minus(_ deck: Decklist) {
        decks.replace(DeckRules.remove(card, from: deck))
        Haptics.medium()
    }
}

private struct DeckRow: View {
    let card: Card
    let deck: Decklist
    let cards: [String: Card]
    let onPlus: () -> Void
    let onMinus: () -> Void

    var body: some View {
        let count = DeckRules.count(card, in: deck)
        let legend = deck.legend.flatMap { cards[$0.cardId] }
        let slot = DeckRules.slot(for: card, in: deck, cards: cards)
        let fits = slot != .main || DeckRules.eligible(card, legendDomains: DeckRules.legendDomains(deck, cards: cards))
        let blocker = DeckRules.blocker(card, in: deck, cards: cards)
        let canAdd = fits && blocker == nil && !(slot == .legend && count > 0)
        let off = !fits && count == 0
        let colors = (legend?.domains ?? []).map { CardStyle.domainColor($0) }
        HStack(spacing: 12) {
            Text(String((legend?.title ?? deck.name).prefix(1)).uppercased())
                .font(RiftFont.display(20))
                .foregroundStyle(.black)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(colors: colors.isEmpty ? [.white.opacity(0.5), .white.opacity(0.25)] : colors.count == 1 ? colors + colors : colors,
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 14)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(deck.name).font(RiftFont.text(15, .bold)).foregroundStyle(.white).lineLimit(1)
                Text(subtitle(fits: fits, slot: slot, count: count, legend: legend, blocker: blocker))
                    .font(RiftFont.text(12.5))
                    .foregroundStyle(.white.opacity(0.66))
            }
            Spacer(minLength: 8)
            if !off {
                CountStepper(count: count, canAdd: canAdd, onMinus: onMinus, onPlus: onPlus)
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
        .opacity(off ? 0.42 : 1)
    }

    private func subtitle(fits: Bool, slot: DeckRules.Slot, count: Int, legend: Card?, blocker: String?) -> String {
        if !fits { return (["Not in \(legend?.title ?? "the legend")'s domains"] + (legend?.domains ?? [])).joined(separator: " · ") }
        switch slot {
        case .legend:
            if count > 0 { return "Legend of this deck" }
            return legend.map { "Replaces \($0.title) as legend" } ?? "Becomes the legend"
        default:
            if let blocker { return blocker }
            switch slot {
            case .champion: return "Becomes the chosen champion"
            case .battlefield: return "Adds to Battlefields · \(deck.battlefields.count) / \(DeckRules.battlefields)"
            case .rune: return "Adds to Runes · \(DeckRules.total(deck.runes)) / \(DeckRules.runes)"
            default: return "Adds to Main deck · \(DeckRules.total(deck.mainDeck)) / \(DeckRules.main)"
            }
        }
    }
}
