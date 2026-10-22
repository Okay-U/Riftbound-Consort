//
//  TableSheets.swift
//  Riftbound Companiokay
//
//  Sheets the Decks table opens (Android `DeckDialogs.kt`, `ShortlistSheet.kt`): edit a logged game, import
//  a deck from text, the shortlist. Native sheets with the mocks' chips.
//

import SwiftUI

private struct FieldLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .caps(10.5)
            .foregroundStyle(.white.opacity(0.6))
            .padding(.top, 16)
            .padding(.bottom, 8)
    }
}

private struct SheetNote: View {
    let text: String
    var color: Color = .white.opacity(0.7)

    var body: some View {
        Text(text).font(RiftFont.text(13, .regular)).lineSpacing(4).foregroundStyle(color)
    }
}

/// Result, turn order, deck and opponent of a logged game; deleting asks twice.
struct EditGameSheet: View {
    let game: GameRecord
    let decks: [Decklist]
    let legends: [String]
    let onSave: (GameRecord) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var won: Bool
    @State private var first: Bool?
    @State private var deckId: UUID?
    @State private var opponent: String
    @State private var query = ""
    @State private var confirm = false

    init(game: GameRecord, decks: [Decklist], legends: [String], onSave: @escaping (GameRecord) -> Void, onDelete: @escaping () -> Void) {
        self.game = game
        self.decks = decks
        self.legends = legends
        self.onSave = onSave
        self.onDelete = onDelete
        _won = State(initialValue: game.result == .won)
        _first = State(initialValue: game.startedFirst)
        _deckId = State(initialValue: game.deckId)
        _opponent = State(initialValue: game.opponent)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    FieldLabel(text: "Result").padding(.top, -16)
                    FlowLayout(spacing: 6) {
                        OnOffChip(label: "Won", on: won, color: RiftColor.you) { won = true }
                        OnOffChip(label: "Lost", on: !won, color: RiftColor.opponent) { won = false }
                    }
                    FieldLabel(text: "Turn order")
                    FlowLayout(spacing: 6) {
                        OnOffChip(label: "Went first", on: first == true) { first = true }
                        OnOffChip(label: "Went second", on: first == false) { first = false }
                        OnOffChip(label: "Unknown", on: first == nil) { first = nil }
                    }
                    FieldLabel(text: "Deck")
                    deckChips
                    FieldLabel(text: "Opponent legend")
                    RiftSearchField(text: $query, placeholder: "Search legends")
                    opponentChips.padding(.top, 10)
                    Button {
                        if confirm { onDelete() } else { confirm = true }
                    } label: {
                        Text(confirm ? "Tap again to delete this game" : "Delete game")
                            .font(RiftFont.text(14, .semibold))
                            .foregroundStyle(RiftColor.danger)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .padding(.top, 20)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Edit game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var deckChips: some View {
        // A deck deleted since the game: its name stays on the game unless another deck is picked.
        let gone: String? = game.deckId != nil && !decks.contains { $0.id == game.deckId } ? game.deckName : nil
        return FlowLayout(spacing: 6) {
            OnOffChip(label: "None", on: deckId == nil, color: RiftColor.you) { deckId = nil }
            ForEach(decks) { deck in
                OnOffChip(label: deck.name, on: deckId == deck.id, color: RiftColor.you) { deckId = deck.id }
            }
            if let gone {
                OnOffChip(label: "\(gone) (deleted)", on: deckId == game.deckId, color: RiftColor.you) { deckId = game.deckId }
            }
        }
    }

    private var opponentChips: some View {
        let needle = query.trimmingCharacters(in: .whitespaces)
        let matches = legends.filter { needle.isEmpty || $0.localizedCaseInsensitiveContains(needle) }
        let shown = Array(([opponent].filter { !$0.isEmpty } + matches.filter { $0 != opponent }).prefix(24))
        let shortCount = Dictionary(legends.map { (MatchLog.opponentShort($0), 1) }, uniquingKeysWith: +)
        return FlowLayout(spacing: 6) {
            OnOffChip(label: "Unknown", on: opponent.isEmpty, color: RiftColor.opponent) { opponent = "" }
            ForEach(shown, id: \.self) { name in
                let short = MatchLog.opponentShort(name)
                OnOffChip(label: (shortCount[short] ?? 0) > 1 ? name : short, on: name == opponent, color: RiftColor.opponent) { opponent = name }
            }
        }
    }

    private func save() {
        let deck = decks.first { $0.id == deckId }
        let keepsGone = deckId == game.deckId && deck == nil
        onSave(GameRecord(
            id: game.id, date: game.date,
            deckId: keepsGone ? game.deckId : deck?.id, deckName: keepsGone ? game.deckName : deck?.name,
            opponent: opponent, result: won ? .won : .lost, durationSeconds: game.durationSeconds,
            events: game.events, startedFirst: first
        ))
    }
}

/// Paste a list in the deckbuilder text format. Paste fills the field without the system's paste prompt;
/// lines no card matches are listed after the import.
struct ImportDeckSheet: View {
    let onImport: (DeckTextFormat.ParsedDeck) -> Void
    @EnvironmentObject private var cards: CardStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var empty = false
    @State private var unresolved: [String]?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let unresolved { result(unresolved) } else { form }
                }
                .padding(16)
            }
            .navigationTitle(unresolved == nil ? "Import a deck" : "Deck imported")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if unresolved == nil {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(cards.allCards.isEmpty ? "Loading cards…" : "Import", action: importText)
                            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || cards.allCards.isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { cards.loadIfNeeded() }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                SheetNote(text: "Paste a deck list. One card per line with its count.")
                Spacer(minLength: 8)
                PasteButton(payloadType: String.self) { strings in
                    guard let clip = strings.first else { return }
                    text = clip
                    empty = false
                }
                .buttonBorderShape(.capsule)
                .labelStyle(.titleAndIcon)
                .tint(RiftColor.you)
            }
            let shape = RoundedRectangle(cornerRadius: 16)
            TextEditor(text: $text)
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(.white)
                .tint(RiftColor.you)
                .scrollContentBackground(.hidden)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(8)
                .frame(height: 220)
                .background(Color(hex: "0A0A0A"), in: shape)
                .overlay(shape.stroke(.white.opacity(0.16), lineWidth: 1))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Legend:\n1 Jinx, Loose Cannon\n\nMainDeck:\n3 Get Excited!")
                            .font(.system(size: 12.5, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                .onChange(of: text) { empty = false }
                .accessibilityLabel("Deck list")
            if empty { SheetNote(text: "No cards found in this text.", color: RiftColor.gold) }
        }
    }

    private func result(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SheetNote(text: "\(lines.count) \(lines.count == 1 ? "line matched" : "lines matched") no card. Open the pile to finish the deck.")
            Text(lines.prefix(12).joined(separator: "\n"))
                .font(.system(size: 12, design: .monospaced))
                .lineSpacing(5)
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(hex: "0A0A0A"), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func importText() {
        let parsed = DeckTextFormat.parse(text, cardPool: cards.allCards)
        let found = parsed.legend != nil || parsed.champion != nil || !parsed.battlefields.isEmpty
            || !parsed.mainDeck.isEmpty || !parsed.sideDeck.isEmpty || parsed.runeCounts.values.contains { $0 > 0 }
        guard found else {
            empty = true
            Haptics.warning()
            return
        }
        onImport(parsed)
        Haptics.success()
        if parsed.unresolvedLines.isEmpty { dismiss() } else { unresolved = parsed.unresolvedLines }
    }
}

/// The cards kept in mind, grouped like a deck's gallery. The star takes a card off; it stays until the sheet
/// closes, dimmed, so a second tap puts it back.
struct RiftShortlistSheet: View {
    @EnvironmentObject private var cards: CardStore
    @EnvironmentObject private var shortlist: ShortlistStore
    @State private var shown: [Card]?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    let kept = shown ?? []
                    SheetNote(text: kept.isEmpty
                              ? "Save a card on its Add to deck sheet in Cards. It waits here and in the builder."
                              : "\(shortlist.ids.count) kept in mind · the star takes a card off")
                    ForEach(DeckGallery.groups(kept.map { ($0, 1) }, byEnergy: false), id: \.label) { group in
                        GroupHeader(label: group.label, count: group.cards.count)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(group.cards, id: \.0.id) { card, _ in KeptTile(card: card) }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Shortlist")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            cards.loadIfNeeded()
            if shown == nil { keep() }
        }
        .onChange(of: cards.allCards.count) { if shown?.isEmpty ?? true { keep() } }
    }

    private func keep() {
        let index = Dictionary(cards.allCards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        shown = shortlist.ids.compactMap { index[$0] }
    }
}

private struct KeptTile: View {
    let card: Card
    @EnvironmentObject private var shortlist: ShortlistStore

    var body: some View {
        let on = shortlist.contains(card.id)
        CardTile(card: card, errata: false, imageWidth: 120)
            .aspectRatio(cardAspect, contentMode: .fit)
            .opacity(on ? 1 : 0.4)
            .animation(.easeInOut(duration: 0.3), value: on)
            .overlay(alignment: .topTrailing) {
                Button {
                    shortlist.toggle(card.id)
                    Haptics.selection()
                } label: {
                    Image(systemName: on ? "star.fill" : "star")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(on ? Color.black : .white)
                        .frame(width: 30, height: 30)
                        .background(on ? RiftColor.you : .black.opacity(0.72), in: Circle())
                        .padding(5)
                        .contentShape(Circle())
                }
                .buttonStyle(PressScale())
                .accessibilityLabel(on ? "Take \(card.name) off the shortlist" : "Put \(card.name) back on the shortlist")
            }
    }
}
