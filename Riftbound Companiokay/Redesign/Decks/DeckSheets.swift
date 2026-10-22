//
//  DeckSheets.swift
//  Riftbound Companiokay
//
//  The deck screen's sheets (Android `DeckSheets.kt`): draw odds, stats, the champion swap, battlefields,
//  export, the deck menu and the deck check. Native sheets with the mocks' content.
//

import SwiftUI
import UIKit

/// A native sheet with a scrolling column and an inline title.
struct RiftSheet<Content: View>: View {
    let title: String
    var detents: Set<PresentationDetent> = [.medium, .large]
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) { content() }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
    }
}

private struct SheetCaps: View {
    let text: String

    var body: some View {
        CapsLabel(text: text).padding(.top, 16).padding(.bottom, 8)
    }
}

// MARK: - Odds

/// Draw odds over the main deck; several cards can be picked, the chance counts any of them.
struct OddsSheet: View {
    let deck: Decklist
    let cards: [String: Card]
    @State private var picked: Set<String>
    @State private var draws: Int
    @State private var k = 1

    init(deck: Decklist, cards: [String: Card]) {
        self.deck = deck
        self.cards = cards
        _picked = State(initialValue: Set([deck.mainDeck.max { $0.count < $1.count }?.cardId].compactMap { $0 }))
        _draws = State(initialValue: min(6, max(DeckRules.total(deck.mainDeck), 1)))
    }

    var body: some View {
        let n = max(DeckRules.total(deck.mainDeck), 1)
        let copies = deck.mainDeck.filter { picked.contains($0.cardId) }.reduce(0) { $0 + $1.count }
        let atLeast = min(max(k, 1), max(copies, 1))
        let seen = min(draws, n)
        let p = Odds.atLeast(deck: n, copies: copies, drawn: seen, k: atLeast)
        let pct = Int((p * 100).rounded())
        RiftSheet(title: "Draw odds", detents: [.large]) {
            SheetLead(text: "Pick cards. The chance counts the main deck.").padding(.bottom, 12)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(deck.mainDeck.sorted { $0.count > $1.count }, id: \.cardId) { entry in
                        let on = picked.contains(entry.cardId)
                        OnOffChip(label: "\(cards[entry.cardId]?.title ?? entry.cardName) ×\(entry.count)", on: on, color: RiftColor.you) {
                            picked = on ? picked.subtracting([entry.cardId]) : picked.union([entry.cardId])
                        }
                    }
                }
            }
            ZStack {
                Text("\(pct)%")
                    .font(RiftFont.display(108))
                    .foregroundStyle(pct >= 75 ? RiftColor.you : pct >= 40 ? .white : RiftColor.gold)
                    .fixedSize()
                    .id(pct)
                    .transition(.scoreMorph(height: 118, inDuration: 0.62, outDuration: 0.42))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 118)
            .animation(.rift(0.62), value: pct)
            .padding(.top, 6)
            .accessibilityLabel("\(pct) percent")
            OddsBar(fraction: p)
            Text(sentence(atLeast: atLeast, copies: copies, seen: seen))
                .font(RiftFont.text(13.5, .regular))
                .lineSpacing(4)
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 4)
            HStack(spacing: 10) {
                StepBox(label: "Cards seen") {
                    GhostStepper(count: draws, what: "card seen", minus: draws > 1, plus: draws < n, size: 32,
                                 onMinus: { draws -= 1 }, onPlus: { draws += 1 })
                }
                StepBox(label: "At least") {
                    GhostStepper(count: atLeast, what: "copy", minus: atLeast > 1, plus: atLeast < copies, size: 32,
                                 onMinus: { k = atLeast - 1 }, onPlus: { k = atLeast + 1 })
                }
            }
            .padding(.top, 14)
        }
    }

    private func sentence(atLeast: Int, copies: Int, seen: Int) -> String {
        let what: String
        switch picked.count {
        case 0: return "Pick a card above."
        case 1:
            let id = picked.first ?? ""
            what = cards[id]?.title ?? deck.mainDeck.first { $0.cardId == id }?.cardName ?? "the card"
        default: what = "any of \(picked.count) picked cards"
        }
        return "Chance to see at least \(atLeast) \(atLeast == 1 ? "copy" : "copies") of \(what) (\(copies) in deck) in the first \(seen) cards."
    }
}

private struct OddsBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.12))
                RoundedRectangle(cornerRadius: 3)
                    .fill(RiftColor.you)
                    .frame(width: geo.size.width * fraction)
                    .shadow(color: RiftColor.you.opacity(0.8), radius: 6)
            }
        }
        .frame(height: 6)
        .animation(.rift(0.7), value: fraction)
    }
}

private struct StepBox<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20)
        VStack(spacing: 8) {
            CapsLabel(text: label)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.05), in: shape)
        .overlay(shape.stroke(.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Stats

/// Energy curve, power by domain, card types, average energy.
struct StatsSheet: View {
    let deck: Decklist
    let cards: [String: Card]

    var body: some View {
        let s = DeckStats.of(deck, cards: cards)
        RiftSheet(title: "Deck stats", detents: [.large]) {
            SheetCaps(text: "Energy curve · main deck").padding(.top, -16)
            let top = max(s.curve.max() ?? 0, 1)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(s.curve.enumerated()), id: \.offset) { i, n in
                    CurveBar(index: i, count: n, top: top)
                }
            }
            .frame(height: 128, alignment: .bottom)
            .padding(.top, 22)
            SheetCaps(text: "Power by domain")
            if s.power.isEmpty {
                SheetLead(text: "No cards with power yet.")
            } else {
                PowerBar(power: s.power)
            }
            SheetCaps(text: "Card types").padding(.bottom, -6)
            let tmax = max(s.types.map(\.count).max() ?? 0, 1)
            ForEach(s.types, id: \.name) { type in
                HStack(spacing: 0) {
                    Text(type.name == "Gear" ? "Gear" : "\(type.name)s")
                        .font(RiftFont.text(13, .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 58, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.08))
                            RoundedRectangle(cornerRadius: 4).fill(.white).frame(width: geo.size.width * CGFloat(type.count) / CGFloat(tmax))
                        }
                    }
                    .frame(height: 8)
                    Text("\(type.count)").font(RiftFont.display(16)).foregroundStyle(.white).frame(width: 28, alignment: .trailing)
                }
                .padding(.top, 10)
                .accessibilityElement(children: .combine)
            }
            HStack {
                Text("AVERAGE ENERGY").caps(12, tracking: 0.12).foregroundStyle(.white.opacity(0.62))
                Spacer()
                Text(s.averageEnergy.map { String(format: "%.1f", $0) } ?? "–").font(RiftFont.display(30)).foregroundStyle(.white)
            }
            .padding(.top, 12)
            .overlay(alignment: .top) { Hairline(opacity: 0.08) }
            .padding(.top, 16)
        }
    }
}

private struct CurveBar: View {
    let index: Int
    let count: Int
    let top: Int
    @State private var grown = false

    var body: some View {
        VStack(spacing: 6) {
            Text("\(count)").font(RiftFont.display(16)).foregroundStyle(.white)
            UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 3, bottomTrailingRadius: 3, topTrailingRadius: 8)
                .fill(RiftColor.you)
                .frame(height: 72 * CGFloat(count) / CGFloat(top))
                .shadow(color: RiftColor.you.opacity(count > 0 ? 0.45 : 0), radius: 7)
                .scaleEffect(x: 1, y: grown ? 1 : 0.001, anchor: .bottom)
            Text(index == 7 ? "7+" : "\(index)").font(RiftFont.text(11, .semibold)).foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(index == 7 ? "7 or more" : "\(index)") energy: \(count)")
        .onAppear { withAnimation(.rift(0.9).delay(Double(index) * 0.06)) { grown = true } }
    }
}

private struct PowerBar: View {
    let power: [DeckStats.Share]

    var body: some View {
        let total = max(power.reduce(0) { $0 + $1.count }, 1)
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                let room = geo.size.width - CGFloat(power.count - 1) * 2
                HStack(spacing: 2) {
                    ForEach(power, id: \.name) { share in
                        RoundedRectangle(cornerRadius: 7)
                            .fill(CardStyle.domainColor(share.name))
                            .frame(width: room * CGFloat(share.count) / CGFloat(total))
                    }
                }
            }
            .frame(height: 14)
            FlowLayout(spacing: 14) {
                ForEach(power, id: \.name) { share in
                    HStack(spacing: 6) {
                        Circle().fill(CardStyle.domainColor(share.name)).frame(width: 8, height: 8)
                        Text("\(share.name) · \(share.count)").font(RiftFont.text(12, .semibold)).foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Champion

/// Swap the chosen champion: every champion of the legend; one from the main deck trades places.
struct ChampionSheet: View {
    let deck: Decklist
    let cards: [String: Card]
    let pool: [Card]
    let onPick: (Card) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let legend = deck.legend.flatMap { cards[$0.cardId] }
        let options = Builder.champions(legend: legend, pool: pool)
        RiftSheet(title: "Chosen champion") {
            SheetLead(text: "The champion starts in its own zone. Copies in the main deck count toward the limit of three.")
                .padding(.bottom, 12)
            if options.isEmpty {
                SheetLead(text: legend.map { "No champion card matches \($0.title)." } ?? "Pick a legend first.")
            }
            VStack(spacing: 8) {
                ForEach(options) { champion in
                    let on = champion.id == deck.champion?.cardId
                    PickRow(title: champion.name, sub: champion.unitLine + (on ? " · chosen" : ""), on: on, check: false) {
                        MiniCard(card: champion)
                    } action: {
                        onPick(champion)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Battlefields

/// Three battlefields, each player brings their own.
struct FieldsSheet: View {
    let deck: Decklist
    let pool: [Card]
    /// false when three are chosen already.
    let onToggle: (Card) -> Bool
    @State private var query = ""
    @State private var toast: BoardToast?

    var body: some View {
        let needle = query.trimmingCharacters(in: .whitespaces)
        let fields = Builder.battlefields(pool).filter { needle.isEmpty || $0.name.localizedCaseInsensitiveContains(needle) }
        RiftSheet(title: "Battlefields · \(deck.battlefields.count) / \(DeckRules.battlefields)", detents: [.large]) {
            SheetLead(text: "Pick three. Each player brings their own.").padding(.bottom, 12)
            RiftSearchField(text: $query, placeholder: "Search battlefields")
            VStack(spacing: 8) {
                ForEach(fields) { field in
                    PickRow(title: field.name, sub: field.summary, on: deck.battlefields.contains { $0.cardId == field.id }) {
                        if onToggle(field) {
                            Haptics.selection()
                        } else {
                            toast = BoardToast(text: "Three battlefields, remove one first")
                        }
                    }
                }
            }
            .padding(.top, 12)
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
    }
}

// MARK: - Export

/// The deck as text for other deck sites and the import.
struct ExportSheet: View {
    let deck: Decklist
    let pool: [Card]
    let onCopied: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let text = DeckTextFormat.export(deck: deck, cardPool: pool).trimmingCharacters(in: .whitespacesAndNewlines)
        let shape = RoundedRectangle(cornerRadius: 16)
        RiftSheet(title: "Export \(deck.name)") {
            SheetLead(text: "Plain text that the Riftcount import and most deck sites read.").padding(.bottom, 12)
            ScrollView {
                Text(text.isEmpty ? "This deck is empty." : text)
                    .font(.system(size: 12, design: .monospaced))
                    .lineSpacing(6)
                    .foregroundStyle(.white.opacity(0.86))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxHeight: 300)
            .background(Color(hex: "0A0A0A"), in: shape)
            .overlay(shape.stroke(.white.opacity(0.1), lineWidth: 1))
            WideButton(text: "Copy text", fill: RiftColor.you, ink: .black, enabled: !text.isEmpty) {
                UIPasteboard.general.string = text
                Haptics.success()
                onCopied()
                dismiss()
            }
            .padding(.top, 12)
        }
    }
}

// MARK: - Menu

/// Rename, edit in the builder, delete (tap twice).
struct DeckMenuSheet: View {
    let deck: Decklist
    let onRename: (String) -> Void
    let onEdit: (() -> Void)?
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var confirm = false

    init(deck: Decklist, onRename: @escaping (String) -> Void, onEdit: (() -> Void)?, onDelete: @escaping () -> Void) {
        self.deck = deck
        self.onRename = onRename
        self.onEdit = onEdit
        self.onDelete = onDelete
        _name = State(initialValue: deck.name)
    }

    var body: some View {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        RiftSheet(title: deck.name) {
            CapsLabel(text: "Name").padding(.bottom, 8)
            NameField(text: $name)
            WideButton(text: "Save name", fill: RiftColor.you, ink: .black, enabled: !trimmed.isEmpty && trimmed != deck.name) {
                onRename(trimmed)
                dismiss()
            }
            .padding(.top, 10)
            if let onEdit {
                WideButton(text: "Edit in the builder") {
                    dismiss()
                    onEdit()
                }
                .padding(.top, 10)
            }
            WideButton(text: confirm ? "Tap again to delete \(deck.name)" : "Delete deck",
                       fill: RiftColor.danger.opacity(confirm ? 1 : 0.16), ink: confirm ? .black : RiftColor.danger) {
                if confirm {
                    dismiss()
                    onDelete()
                } else {
                    confirm = true
                    Haptics.warning()
                }
            }
            .padding(.top, 10)
        }
    }
}

/// The builder's and the menu's name input (52pt, green ring while typing).
struct NameField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18)
        TextField("", text: $text, prompt: Text("Deck name").foregroundStyle(.white.opacity(0.4)))
            .font(RiftFont.text(17, .semibold))
            .foregroundStyle(.white)
            .tint(RiftColor.you)
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
            .focused($focused)
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color(hex: "0B0B0B"), in: shape)
            .overlay(shape.stroke(focused ? RiftColor.you.opacity(0.6) : .white.opacity(0.16), lineWidth: 1))
            .animation(.easeInOut(duration: 0.3), value: focused)
            .onChange(of: text) { _, value in if value.count > 40 { text = String(value.prefix(40)) } }
            .accessibilityLabel("Deck name")
    }
}

// MARK: - Deck check

/// What the deck still needs to be tournament legal (classic `DeckLegality`).
struct IssuesSheet: View {
    let deck: Decklist
    let cards: [String: Card]

    var body: some View {
        let issues = DeckRules.issues(deck, cards: cards)
        RiftSheet(title: issues.isEmpty ? "Tournament legal" : "Not legal yet") {
            SheetLead(text: issues.isEmpty
                      ? "Legend, champion, three battlefields, 39 cards, 12 runes: all there."
                      : "Saved decks may be drafts; this is what a tournament checks.")
                .padding(.bottom, 4)
            ForEach(issues, id: \.self) { issue in Notice(text: issue, color: RiftColor.gold, symbol: "exclamationmark.triangle") }
            if issues.isEmpty { Notice(text: "Tournament legal", color: RiftColor.you, symbol: "checkmark.circle") }
        }
    }
}
