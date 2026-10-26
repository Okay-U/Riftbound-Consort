//
//  GameSetupSheets.swift
//  Riftbound Companiokay
//
//  The game setup behind a half's name (Android `GameSetup.kt`, classic `GameSetupSheet`): your deck and
//  the turn order, or the opponent's legend. Native sheets (Liquid Glass on iOS 26) with the mock's rows.
//

import SwiftUI

enum SetupSheet: String, Identifiable {
    case deck, opponent
    var id: String { rawValue }
}

/// Your deck and the turn order: the deck's legend names your half and the game goes into its match log.
struct DeckPickSheet: View {
    @ObservedObject var c: ScoreController
    @EnvironmentObject private var decks: DecklistStore
    @EnvironmentObject private var cards: CardStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    SheetText("Its legend names your half; finished games go into its match log.")
                    LegendArtSwitch()
                    PickRow(title: "No deck", sub: "Games count for all decks only", on: c.deckId.isEmpty) {
                        c.pickDeck("")
                        dismiss()
                    }
                    ForEach(decks.lists) { deck in deckRow(deck) }
                    if decks.lists.isEmpty { SheetText("No decks yet: build one on the Decks tab.") }
                    Text("TURN ORDER")
                        .caps(10.5)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 10)
                    HStack(spacing: 6) {
                        OnOffChip(label: "Unknown", on: c.turnOrder.isEmpty) { c.pickTurnOrder("") }
                        OnOffChip(label: "Going first", on: c.turnOrder == "first") { c.pickTurnOrder("first") }
                        OnOffChip(label: "Going second", on: c.turnOrder == "second") { c.pickTurnOrder("second") }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Your deck")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { cards.loadIfNeeded() }
    }

    private func deckRow(_ deck: Decklist) -> some View {
        let legendId = deck.legend?.cardId
        let legend: Card? = legendId.flatMap { id in cards.allCards.first { $0.id == id } }
        let chosen = c.deckId.caseInsensitiveCompare(deck.id.uuidString) == .orderedSame
        return PickRow(title: deck.name, sub: legend?.name ?? "No legend yet", on: chosen) {
            MiniCard(card: legend)
        } action: {
            c.pickDeck(deck.id.uuidString)
            dismiss()
        }
    }
}

/// The opponent's legend, searchable; one row per legend (printings folded, like the classic picker).
struct OpponentPickSheet: View {
    @ObservedObject var c: ScoreController
    @EnvironmentObject private var cards: CardStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            ScrollView { list.padding(16) }
                .navigationTitle("Opponent's legend")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search legends")
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { cards.loadIfNeeded() }
    }

    private var list: some View {
        let needle = query.trimmingCharacters(in: .whitespaces)
        let names: [String] = cards.legendNames.filter { needle.isEmpty || $0.localizedCaseInsensitiveContains(needle) }
        let art = legendArt
        return VStack(alignment: .leading, spacing: 8) {
            SheetText("Names their half and the game in the match log.")
            if needle.isEmpty {
                LegendArtSwitch()
                PickRow(title: "Unknown", on: c.opponent.trimmingCharacters(in: .whitespaces).isEmpty) {
                    c.pickOpponent("")
                    dismiss()
                }
            }
            if cards.legendNames.isEmpty { SheetText("Loading the card list…") }
            ForEach(names, id: \.self) { name in legendRow(name, card: art[name]) }
        }
    }

    /// The rare printing of each legend, for its art.
    private var legendArt: [String: Card] {
        var art: [String: Card] = [:]
        for card in cards.allCards where card.classification?.type?.lowercased() == "legend" && card.classification?.rarity?.lowercased() == "rare" {
            if art[card.name] == nil { art[card.name] = card }
        }
        return art
    }

    private func legendRow(_ name: String, card: Card?) -> some View {
        PickRow(title: name, sub: card?.classification?.domain?.joined(separator: " · "), on: c.opponent == name) {
            MiniCard(card: card)
        } action: {
            c.pickOpponent(name)
            dismiss()
        }
    }
}

/// Legend art, the same switch as the Settings tile: off by default.
private struct LegendArtSwitch: View {
    @AppStorage("legendArt") private var legendArt = false

    var body: some View {
        SettingsGroup {
            ToggleRow(title: "Legend art", symbol: "photo.artframe", sub: "The legends' splash art behind their halves", divider: false, isOn: $legendArt)
        }
        .padding(.bottom, 4)
    }
}

private struct SheetText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(RiftFont.text(13, .regular))
            .lineSpacing(4)
            .foregroundStyle(.white.opacity(0.7))
            .padding(.bottom, 4)
    }
}

/// The mock's pick row: art or text, a check on the right when chosen.
struct PickRow<Leading: View>: View {
    let title: String
    var sub: String? = nil
    let on: Bool
    /// The check on the right; off where the row's sub line says it (the champion swap).
    var check = true
    @ViewBuilder var leading: () -> Leading
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                leading()
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(RiftFont.text(15, .semibold)).foregroundStyle(.white)
                    if let sub {
                        Text(sub).font(RiftFont.text(12, .regular)).foregroundStyle(.white.opacity(0.6)).lineLimit(3)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if check {
                    ZStack {
                        Circle().fill(on ? RiftColor.you : .clear)
                        Circle().stroke(on ? RiftColor.you : .white.opacity(0.3), lineWidth: 1.5)
                        if on { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.black) }
                    }
                    .frame(width: 26, height: 26)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            .background(Color(hex: "171717"), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(on ? RiftColor.you : .white.opacity(0.12), lineWidth: 1))
            .shadow(color: on ? RiftColor.you.opacity(0.25) : .clear, radius: 9)
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(PressScale(scale: 0.98))
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

extension PickRow where Leading == EmptyView {
    init(title: String, sub: String? = nil, on: Bool, action: @escaping () -> Void) {
        self.init(title: title, sub: sub, on: on, leading: { EmptyView() }, action: action)
    }
}

/// A small card (54 × 76) with its energy, as the pickers show it.
struct MiniCard: View {
    let card: Card?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8)
        ZStack(alignment: .topLeading) {
            CachedRemoteImage(url: card?.media?.imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.white.opacity(0.06)
            }
            .frame(width: 54, height: 76)
            .clipShape(shape)
            if let energy = card?.attributes?.energy {
                Text("\(energy)")
                    .font(RiftFont.display(13))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(.black.opacity(0.7), in: Circle())
                    .padding(5)
            }
        }
        .frame(width: 54, height: 76)
        .overlay(shape.stroke(.white.opacity(0.16), lineWidth: 1))
        .accessibilityHidden(true)
    }
}

/// The mocks' on/off chip.
struct OnOffChip: View {
    let label: String
    let on: Bool
    var color: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(RiftFont.text(12.5, .semibold))
                .foregroundStyle(on ? Color.black : .white)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(on ? color : .white.opacity(0.04), in: Capsule())
                .overlay(Capsule().stroke(on ? color : .white.opacity(0.16), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(PressScale(scale: 0.95))
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
