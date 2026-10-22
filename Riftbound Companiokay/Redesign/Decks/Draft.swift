//
//  Draft.swift
//  Riftbound Companiokay
//
//  The builder's deck in the making (Android `Draft.kt`, classic `DeckBuilderState`): nothing reaches the
//  store before it is saved, every change returns a new draft. Checked by tools/check-decks/run.sh.
//

import Foundation

/// The builder rail's seven stops, labelled like the mock.
enum BuildStep: Int, CaseIterable {
    case legend, champion, fields, main, side, runes, save

    var label: String {
        switch self {
        case .legend: return "Legend"
        case .champion: return "Champion"
        case .fields: return "Fields"
        case .main: return "Main"
        case .side: return "Side"
        case .runes: return "Runes"
        case .save: return "Save"
        }
    }

    var title: String {
        switch self {
        case .legend: return "Pick a legend"
        case .champion: return "Pick your champion"
        case .fields: return "Three battlefields"
        case .main: return "Main deck"
        case .side: return "Sideboard"
        case .runes: return "Rune pool"
        case .save: return "Name and save"
        }
    }
}

struct Draft: Equatable {
    var legend: Card?
    var champion: Card?
    var battlefields: [Card] = []
    var main: [DecklistEntry] = []
    var side: [DecklistEntry] = []
    /// Domain (lower case) to rune count, 12 in all.
    var runes: [String: Int] = [:]
    var name = ""
    /// The deck being edited; nil for a new one.
    var editing: Decklist?
    /// Battlefields or runes the pickers cannot show in full (a card the feed lacks, a rune outside the
    /// legend): saved as they are.
    var keepBattlefields = false
    var keepRunes = false
    /// The edited deck's legend or champion when the card list does not know it: kept unless replaced.
    var unknownLegend: DecklistEntry?
    var unknownChampion: DecklistEntry?

    var domains: [String] { legend?.domains.filter { $0.lowercased() != "colorless" } ?? [] }
    var mainCount: Int { DeckRules.total(main) }
    var sideCount: Int { DeckRules.total(side) }
    var runeCount: Int { runes.values.reduce(0, +) }

    func entries(_ pile: Pile) -> [DecklistEntry] { pile == .main ? main : side }
    func count(_ pile: Pile, _ card: Card) -> Int { entries(pile).first { $0.cardId == card.id }?.count ?? 0 }
}

enum Builder {
    private static func unique(_ cards: [Card]) -> [Card] {
        var seen = Set<String>()
        return cards.filter { seen.insert($0.id).inserted }.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    static func legends(_ pool: [Card]) -> [Card] { unique(pool.filter { $0.isRareLegend }) }

    static func champions(legend: Card?, pool: [Card]) -> [Card] {
        guard let legend else { return [] }
        return unique(pool.filter { $0.isChampionUnit && $0.matchesLegend(legend) })
    }

    /// Token battlefields (Baron Pit) only come up during a game.
    static func battlefields(_ pool: [Card]) -> [Card] { unique(pool.filter { $0.isBattlefield && !$0.isToken }) }

    /// Cards the legend allows, the legend's first domain first, then by energy and name (classic pool order).
    static func pool(_ draft: Draft, _ pool: [Card], query: String = "", types: Set<String> = []) -> [Card] {
        let domains = draft.domains.map { $0.lowercased() }
        let needle = query.trimmingCharacters(in: .whitespaces)
        func rank(_ card: Card) -> Int { card.domains.compactMap { domains.firstIndex(of: $0.lowercased()) }.min() ?? Int.max }
        var seen = Set<String>()
        return pool
            .filter { DeckRules.eligible($0, legendDomains: Set(domains)) && $0.signatureFits(legend: draft.legend) }
            .filter { needle.isEmpty || $0.name.localizedCaseInsensitiveContains(needle) }
            .filter { card in types.isEmpty || types.contains { $0.caseInsensitiveCompare(card.typeName) == .orderedSame } }
            .filter { seen.insert($0.id).inserted }
            .sorted { a, b in
                let (ra, rb) = (rank(a), rank(b))
                if ra != rb { return ra < rb }
                let (ea, eb) = (a.attributes?.energy ?? Int.max, b.attributes?.energy ?? Int.max)
                return ea != eb ? ea < eb : a.name.lowercased() < b.name.lowercased()
            }
    }

    /// A new legend clears what depended on the old one and splits the runes evenly (classic `setLegend`).
    static func pickLegend(_ draft: Draft, _ card: Card) -> Draft {
        if draft.legend?.id == card.id { return draft }
        let autoName = draft.name.trimmingCharacters(in: .whitespaces).isEmpty || draft.name == defaultName(draft.legend)
        return Draft(
            legend: card,
            runes: evenSplit(card.domains.filter { $0.lowercased() != "colorless" }),
            name: autoName && draft.editing == nil ? defaultName(card) : draft.name,
            editing: draft.editing
        )
    }

    static func defaultName(_ legend: Card?) -> String { legend.map { "\($0.title) deck" } ?? "" }

    static func evenSplit(_ domains: [String]) -> [String: Int] {
        guard !domains.isEmpty else { return [:] }
        let base = DeckRules.runes / domains.count
        let extra = DeckRules.runes % domains.count
        return Dictionary(domains.enumerated().map { ($0.element.lowercased(), base + ($0.offset < extra ? 1 : 0)) }, uniquingKeysWith: +)
    }

    static func toggleBattlefield(_ draft: Draft, _ card: Card) -> Draft {
        var next = draft
        if draft.battlefields.contains(where: { $0.id == card.id }) {
            next.battlefields = draft.battlefields.filter { $0.id != card.id }
        } else if draft.battlefields.count < DeckRules.battlefields {
            next.battlefields = draft.battlefields + [card]
        }
        return next
    }

    static func pickChampion(_ draft: Draft, _ card: Card) -> Draft {
        var next = draft
        next.champion = card
        next.unknownChampion = nil
        return next
    }

    /// Copies of the card's identity across main, side and the chosen champion.
    static func copies(_ draft: Draft, _ card: Card, cards: [String: Card]) -> Int {
        let key = DeckRules.identityKey(card)
        let listed = (draft.main + draft.side).filter { entry in cards[entry.cardId].map { DeckRules.identityKey($0) } == key }.reduce(0) { $0 + $1.count }
        return listed + (draft.champion.map { DeckRules.identityKey($0) == key ? 1 : 0 } ?? 0)
    }

    static func signatures(_ draft: Draft, cards: [String: Card]) -> Int {
        (draft.main + draft.side).filter { cards[$0.cardId]?.isSignature == true }.reduce(0) { $0 + $1.count }
    }

    /// Why one more copy cannot go on the pile, or nil when it can (classic `canAdd` plus the pile sizes).
    static func blocker(_ draft: Draft, _ pile: Pile, _ card: Card, cards: [String: Card]) -> String? {
        if pile == .main && draft.mainCount >= DeckRules.main { return "Main deck is full" }
        if pile == .side && draft.sideCount >= DeckRules.sideMax { return "Sideboard is full" }
        if copies(draft, card, cards: cards) >= DeckRules.copyLimit { return "3 copies already" }
        if card.isSignature && signatures(draft, cards: cards) >= DeckRules.signatureLimit { return "3 signature cards already" }
        return nil
    }

    static func add(_ draft: Draft, _ pile: Pile, _ card: Card) -> Draft {
        let list = draft.entries(pile)
        let plus = list.contains { $0.cardId == card.id }
            ? list.map { $0.cardId == card.id ? DecklistEntry(cardId: $0.cardId, cardName: $0.cardName, count: $0.count + 1) : $0 }
            : list + [DecklistEntry(cardId: card.id, cardName: card.name, count: 1)]
        return with(draft, pile, plus)
    }

    static func remove(_ draft: Draft, _ pile: Pile, _ card: Card) -> Draft {
        let minus = draft.entries(pile).compactMap { entry -> DecklistEntry? in
            guard entry.cardId == card.id else { return entry }
            return entry.count > 1 ? DecklistEntry(cardId: entry.cardId, cardName: entry.cardName, count: entry.count - 1) : nil
        }
        return with(draft, pile, minus)
    }

    private static func with(_ draft: Draft, _ pile: Pile, _ list: [DecklistEntry]) -> Draft {
        var next = draft
        if pile == .main { next.main = list } else { next.side = list }
        return next
    }

    /// A full pool of a two-domain legend stays full: a rune more of one domain is one fewer of the other (Okay).
    static func rune(_ draft: Draft, _ domain: String, _ delta: Int) -> Draft {
        let key = domain.lowercased()
        let count = (draft.runes[key] ?? 0) + delta
        guard count >= 0 else { return draft }
        let full = draft.runeCount >= DeckRules.runes
        let others = draft.domains.map { $0.lowercased() }.filter { $0 != key }
        var next = draft
        if full, draft.domains.count == 2, others.count == 1, let other = others.first {
            let rest = (draft.runes[other] ?? 0) - delta
            guard rest >= 0 else { return draft }
            next.runes[key] = count
            next.runes[other] = rest
            return next
        }
        if delta > 0 && full { return draft }
        next.runes[key] = count
        return next
    }

    /// The draft as a deck: new, or the edited one with its id and creation date. Runes are each domain's
    /// rune card.
    static func toDeck(_ draft: Draft, pool: [Card], at now: Date) -> Decklist {
        let trimmed = draft.name.trimmingCharacters(in: .whitespaces)
        var deck = draft.editing ?? Decklist(name: trimmed)
        if draft.editing == nil { deck.createdAt = now }
        let runes: [DecklistEntry] = draft.domains.compactMap { domain in
            let count = draft.runes[domain.lowercased()] ?? 0
            guard count > 0, let rune = Card.runeCard(forDomain: domain, in: pool) else { return nil }
            return DecklistEntry(cardId: rune.id, cardName: rune.name, count: count)
        }
        func entry(_ card: Card) -> DecklistEntry { DecklistEntry(cardId: card.id, cardName: card.name, count: 1) }
        deck.name = trimmed.isEmpty ? deck.name : trimmed
        deck.updatedAt = now
        deck.legend = draft.legend.map(entry) ?? draft.unknownLegend
        deck.champion = draft.champion.map(entry) ?? draft.unknownChampion
        if !draft.keepBattlefields { deck.battlefields = draft.battlefields.map(entry) }
        deck.mainDeck = draft.main
        deck.sideDeck = draft.side
        if !draft.keepRunes { deck.runes = runes }
        return deck
    }

    /// An existing deck in the builder (classic `loadFromExisting`): what the pickers cannot show stays untouched.
    static func fromDeck(_ deck: Decklist, cards: [String: Card]) -> Draft {
        let legend = deck.legend.flatMap { cards[$0.cardId] }
        let fields = deck.battlefields.compactMap { entry in entry.count == 1 ? cards[entry.cardId] : nil }
        let domains = (legend?.domains ?? []).map { $0.lowercased() }.filter { $0 != "colorless" }
        var runes = Dictionary(domains.map { ($0, 0) }, uniquingKeysWith: { first, _ in first })
        var keepRunes = false
        for entry in deck.runes {
            if let domain = cards[entry.cardId]?.domains.first?.lowercased(), domains.contains(domain) {
                runes[domain, default: 0] += entry.count
            } else {
                keepRunes = true
            }
        }
        let champion = deck.champion.flatMap { cards[$0.cardId] }
        return Draft(
            legend: legend, champion: champion, battlefields: fields, main: deck.mainDeck, side: deck.sideDeck,
            runes: runes, name: deck.name, editing: deck,
            keepBattlefields: fields.count != deck.battlefields.count, keepRunes: keepRunes,
            unknownLegend: legend == nil ? deck.legend : nil, unknownChampion: champion == nil ? deck.champion : nil
        )
    }
}
