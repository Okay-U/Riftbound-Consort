//
//  BuilderPages.swift
//  Riftbound Companiokay
//
//  The builder's seven pages (Android `BuilderView.kt`): legend tiles, champions, battlefields with their art,
//  the main and side pools as a gallery (a tap adds a copy, the minus takes one back), the rune pool and the
//  name with the deck check.
//

import SwiftUI

/// Three to a row on a phone, more on a wider screen.
private let threeColumns = [GridItem(.adaptive(minimum: 100, maximum: 170), spacing: 8)]

/// "23 / 39" with a caption or the signature tag on the right.
private struct CountHead: View {
    let n: Int
    let of: Int
    let right: String
    var tag = false

    var body: some View {
        HStack {
            Text("\(Text("\(n)").font(RiftFont.display(40)).foregroundStyle(.white))\(Text(" / \(of)").font(RiftFont.display(20)).foregroundStyle(.white.opacity(0.55)))")
            Spacer(minLength: 8)
            if tag {
                Text(right)
                    .caps(11, tracking: 0.08, weight: .bold)
                    .foregroundStyle(Color(hex: "C08BFF"))
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .overlay(Capsule().stroke(Color(hex: "C08BFF").opacity(0.5), lineWidth: 1))
            } else if !right.isEmpty {
                Text(right.uppercased()).caps(11.5).foregroundStyle(.white.opacity(0.62))
            }
        }
        .padding(.top, 2)
        .padding(.bottom, 10)
        .accessibilityElement(children: .combine)
    }
}

private struct Progress: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.1))
                RoundedRectangle(cornerRadius: 3)
                    .fill(RiftColor.you)
                    .frame(width: geo.size.width * min(max(fraction, 0), 1))
                    .shadow(color: RiftColor.you.opacity(0.8), radius: 5)
            }
        }
        .frame(height: 5)
        .padding(.bottom, 10)
        .animation(.rift(0.5), value: fraction)
    }
}

private struct PageNote: View {
    let text: String

    var body: some View {
        Text(text).font(RiftFont.text(13, .regular)).lineSpacing(4).foregroundStyle(.white.opacity(0.7))
    }
}

// MARK: - Legend

struct LegendPage: View {
    let draft: Draft
    let pool: [Card]
    let onPick: (Card) -> Void
    @State private var query = ""

    var body: some View {
        let all = Builder.legends(pool)
        let needle = query.trimmingCharacters(in: .whitespaces)
        let shown = all.filter { needle.isEmpty || $0.name.localizedCaseInsensitiveContains(needle) }
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                RiftSearchField(text: $query, placeholder: "Search legends").padding(.bottom, 4)
                if shown.isEmpty { PageNote(text: all.isEmpty ? "Loading the card list…" : "No legend matches.") }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 260), spacing: 10)], spacing: 10) {
                    ForEach(shown) { legend in
                        LegendTile(legend: legend, on: draft.legend?.id == legend.id) { onPick(legend) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
    }
}

private struct LegendTile: View {
    let legend: Card
    let on: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22)
        // "Scorn of the Moon · Overnumbered": two printings of one legend look alike otherwise.
        let line = [legend.subtitle, legend.printing].compactMap { $0 }.joined(separator: " · ")
        Button(action: action) {
            ArtBox(card: legend, imageWidth: 200, initialSize: 90)
                .overlay { BottomShade(from: 0.25) }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(legend.title).font(RiftFont.display(22)).tracking(0.4).foregroundStyle(.white).lineLimit(1)
                        if !line.isEmpty {
                            Text(line).font(RiftFont.text(11.5, .semibold)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                        }
                        Text(legend.domains.joined(separator: " · ").uppercased())
                            .caps(10, tracking: 0.12)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.top, 4)
                    }
                    .padding(12)
                }
                .frame(height: 118)
                .clipShape(shape)
                .overlay(shape.stroke(on ? .white : .white.opacity(0.1), lineWidth: on ? 2 : 1))
                .shadow(color: on ? .white.opacity(0.35) : .clear, radius: 12)
                .contentShape(shape)
        }
        .buttonStyle(PressScale(scale: 0.97))
        .accessibilityLabel(legend.name)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - Champion

struct ChampionPage: View {
    let draft: Draft
    let champions: [Card]
    let onPick: (Card) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if champions.isEmpty {
                    PageNote(text: draft.legend.map { "No champion card matches \($0.title). Skip this step." } ?? "Pick a legend first.")
                }
                ForEach(champions) { champion in
                    PickRow(title: champion.name, sub: champion.unitLine, on: draft.champion?.id == champion.id) {
                        MiniCard(card: champion)
                    } action: {
                        onPick(champion)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Battlefields

/// The battlefields as the Cards tab shows them, three to a row (Okay: building without art is hard).
struct FieldsPage: View {
    let draft: Draft
    let pool: [Card]
    let onToast: (String) -> Void
    let onChange: (Draft) -> Void
    @State private var query = ""

    var body: some View {
        let needle = query.trimmingCharacters(in: .whitespaces)
        let fields = Builder.battlefields(pool).filter { needle.isEmpty || $0.name.localizedCaseInsensitiveContains(needle) }
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CountHead(n: draft.battlefields.count, of: DeckRules.battlefields, right: draft.keepBattlefields ? "Kept as they are" : "Pick three")
                if draft.keepBattlefields {
                    PageNote(text: "This deck's battlefields are not all in today's card list, so they stay as they are.")
                } else {
                    RiftSearchField(text: $query, placeholder: "Search battlefields").padding(.bottom, 14)
                    LazyVGrid(columns: threeColumns, spacing: 8) {
                        ForEach(fields) { field in
                            let on = draft.battlefields.contains { $0.id == field.id }
                            FieldPick(card: field, on: on) {
                                if !on && draft.battlefields.count >= DeckRules.battlefields {
                                    onToast("Three battlefields, remove one first")
                                } else {
                                    onChange(Builder.toggleBattlefield(draft, field))
                                    Haptics.selection()
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
    }
}

/// A battlefield in the builder: its art, ringed and ticked once it is one of the three.
private struct FieldPick: View {
    let card: Card
    let on: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10)
        Button(action: action) {
            CardTile(card: card, errata: false, imageWidth: 120)
                .aspectRatio(cardAspect, contentMode: .fit)
                .overlay { if on { shape.stroke(RiftColor.you, lineWidth: 2) } }
                .overlay(alignment: .topTrailing) {
                    if on {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 26, height: 26)
                            .background(RiftColor.you, in: Circle())
                            .padding(6)
                    }
                }
                .shadow(color: on ? RiftColor.you.opacity(0.5) : .clear, radius: 9)
        }
        .buttonStyle(PressScale(scale: 0.95))
        .accessibilityLabel(card.name + (on ? ", chosen" : ""))
        .accessibilityHint(on ? "Removes the battlefield" : "Picks the battlefield")
    }
}

// MARK: - Main and side

/// Main or side: the cards the legend allows as a gallery (classic `CardPoolPickerView`, Okay asked for the art):
/// a tap adds a copy, the minus on a card takes one back; search and type chips on top.
struct PoolPage: View {
    let draft: Draft
    let pile: Pile
    let pool: [Card]
    let cards: [String: Card]
    let onToast: (String) -> Void
    let onChange: (Draft) -> Void
    @EnvironmentObject private var shortlist: ShortlistStore
    @State private var query = ""
    @State private var types: Set<String> = []
    @State private var shortlisted = false

    var body: some View {
        let kept = Set(shortlist.ids)
        // Only the kept cards this legend may play count, so the chip never promises cards it cannot show.
        let keptHere = Builder.pool(draft, pool).filter { kept.contains($0.id) }.count
        let shown = Builder.pool(draft, pool, query: query, types: types).filter { !shortlisted || kept.contains($0.id) }
        let main = pile == .main
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if main {
                    CountHead(n: draft.mainCount, of: DeckRules.main, right: "SIG \(Builder.signatures(draft, cards: cards)) / \(DeckRules.signatureLimit)", tag: true)
                } else {
                    CountHead(n: draft.sideCount, of: DeckRules.sideMax, right: "Optional · up to 10")
                }
                Progress(fraction: main ? Double(draft.mainCount) / Double(DeckRules.main) : Double(draft.sideCount) / Double(DeckRules.sideMax))
                RiftSearchField(text: $query)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(["Unit", "Spell", "Gear"], id: \.self) { type in
                            OnOffChip(label: type, on: types.contains(type), color: RiftColor.you) { types.toggleMember(type) }
                        }
                        // The cards kept in mind from the Cards tab, so they need no searching.
                        if keptHere > 0 {
                            OnOffChip(label: "Shortlist \(keptHere)", on: shortlisted, color: RiftColor.you) { shortlisted.toggle() }
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 12)
                if draft.legend == nil { PageNote(text: "Pick a legend first: its domains decide the cards.").padding(.vertical, 12) }
                LazyVGrid(columns: threeColumns, spacing: 8) {
                    ForEach(shown) { card in
                        let blocker = Builder.blocker(draft, pile, card, cards: cards)
                        PickTile(card: card, count: draft.count(pile, card), blocked: blocker != nil) {
                            if let blocker {
                                onToast(blocker)
                                Haptics.warning()
                            } else {
                                onChange(Builder.add(draft, pile, card))
                                Haptics.light()
                            }
                        } onRemove: {
                            onChange(Builder.remove(draft, pile, card))
                            Haptics.light()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
    }
}

/// The builder's pool card: a tap adds a copy (or says why not), the minus takes one back. A card that cannot
/// go in any more dims.
private struct PickTile: View {
    let card: Card
    let count: Int
    let blocked: Bool
    let onAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button(action: onAdd) {
            CardTile(card: card, errata: false, imageWidth: 120)
                .aspectRatio(cardAspect, contentMode: .fit)
                .overlay(alignment: .topTrailing) { if count > 0 { CountBadge(count: count, filled: true) } }
        }
        .buttonStyle(PressScale(scale: 0.95))
        .opacity(blocked && count == 0 ? 0.45 : 1)
        .animation(.easeInOut(duration: 0.3), value: blocked && count == 0)
        .overlay(alignment: .topLeading) {
            if count > 0 {
                Button(action: onRemove) {
                    Text("−")
                        .font(RiftFont.text(17, .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.black.opacity(0.72), in: Circle())
                        .padding(5)
                        .contentShape(Circle())
                }
                .buttonStyle(PressScale(scale: 0.9))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.name), \(count) in the deck")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onAdd() }
        .accessibilityAction(named: "Take one out") { if count > 0 { onRemove() } }
    }
}

// MARK: - Runes

struct RunesPage: View {
    let draft: Draft
    let onChange: (Draft) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    CountHead(n: draft.runeCount, of: DeckRules.runes, right: "")
                    Button("Split evenly") {
                        var next = draft
                        next.runes = Builder.evenSplit(draft.domains)
                        onChange(next)
                        Haptics.selection()
                    }
                    .font(RiftFont.text(14, .semibold))
                    .foregroundStyle(RiftColor.you)
                    .disabled(draft.keepRunes || draft.domains.isEmpty)
                }
                if draft.keepRunes {
                    PageNote(text: "This deck's runes are not all in today's card list or the legend's domains, so they stay as they are.")
                } else {
                    RunePool(domains: draft.domains, count: { draft.runes[$0.lowercased()] ?? 0 }, total: draft.runeCount) { domain, delta in
                        onChange(Builder.rune(draft, domain, delta))
                        Haptics.light()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Save

struct SavePage: View {
    let draft: Draft
    let issues: [String]
    let onName: (String) -> Void

    var body: some View {
        let rows: [(String, String)] = [
            ("Legend", draft.legend?.title ?? draft.unknownLegend?.cardName ?? "—"),
            ("Champion", draft.champion?.name ?? draft.unknownChampion?.cardName ?? "—"),
            ("Battlefields", "\(draft.battlefields.count) / \(DeckRules.battlefields)"),
            ("Main deck", "\(draft.mainCount) / \(DeckRules.main)"),
            ("Sideboard", "\(draft.sideCount) / \(DeckRules.sideMax)"),
            ("Runes", "\(draft.runeCount) / \(DeckRules.runes)"),
        ]
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CapsLabel(text: "Deck name")
                NameField(text: Binding(get: { draft.name }, set: onName))
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                ForEach(rows, id: \.0) { key, value in
                    HStack {
                        Text(key).font(RiftFont.text(14, .regular)).foregroundStyle(.white)
                        Spacer(minLength: 8)
                        Text(value).font(RiftFont.text(14, .semibold)).foregroundStyle(.white).lineLimit(1)
                    }
                    .frame(height: 44)
                    .overlay(alignment: .bottom) { Hairline(opacity: 0.07) }
                    .accessibilityElement(children: .combine)
                }
                ForEach(issues, id: \.self) { issue in Notice(text: issue, color: RiftColor.gold, symbol: "exclamationmark.triangle") }
                if issues.isEmpty { Notice(text: "Tournament legal", color: RiftColor.you, symbol: "checkmark.circle") }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
