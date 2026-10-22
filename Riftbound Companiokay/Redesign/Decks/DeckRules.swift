//
//  DeckRules.swift
//  Riftbound Companiokay
//
//  Riftbound deck rules for the redesign (Android `DeckRules.kt`, which follows the classic builder,
//  `DeckLegality` and `CardClassifier`): where a card goes, why another copy cannot, adding and taking out.
//  Pure functions over `Decklist`; checked by tools/check-decks/run.sh.
//

import Foundation

enum DeckRules {
    static let main = 39
    static let copyLimit = 3
    static let signatureLimit = 3
    static let battlefields = 3
    static let runes = 12
    /// Tournament Rules 601.1.c.1: a sideboard of 10 or fewer cards.
    static let sideMax = 10

    enum Slot { case legend, champion, battlefield, main, side, rune }

    private static let variantSuffixes = [" showcase", " promo", " foil", " alt art", " alternate art", " overnumbered", " signature"]

    /// One identity per card across printings: "Seal of Insight (Showcase)" counts as "seal of insight".
    static func identityKey(_ card: Card) -> String {
        var t = (card.metadata?.cleanName.flatMap { $0.isEmpty ? nil : $0 } ?? card.name).lowercased()
        t = t.replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
        var changed = true
        while changed {
            changed = false
            for suffix in variantSuffixes where t.hasSuffix(suffix) {
                t.removeLast(suffix.count)
                changed = true
                break
            }
        }
        return "name:" + t.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Main deck cards: no legend, battlefield, rune or token; colourless always, else all domains in the legend's.
    static func eligible(_ card: Card, legendDomains: Set<String>) -> Bool {
        if card.isLegend || card.isBattlefield || card.isRune || card.isToken { return false }
        // The feed writes "Colorless" as a domain; it is the absence of one.
        let mine = Set(card.domains.map { $0.lowercased() }.filter { $0 != "colorless" })
        return mine.isEmpty || legendDomains.isEmpty || mine.isSubset(of: legendDomains)
    }

    /// Where "Add" puts a card: a champion becomes the chosen one only while that slot is empty.
    static func slot(for card: Card, in deck: Decklist, cards: [String: Card]) -> Slot {
        if card.isLegend { return .legend }
        if card.isBattlefield { return .battlefield }
        if card.isRune { return .rune }
        if card.isChampionUnit && deck.champion == nil {
            let legend = deck.legend.flatMap { cards[$0.cardId] }
            if legend.map({ card.matchesLegend($0) }) != false { return .champion }
        }
        return .main
    }

    static func legendDomains(_ deck: Decklist, cards: [String: Card]) -> Set<String> {
        Set(deck.legend.flatMap { cards[$0.cardId] }?.domains.map { $0.lowercased() } ?? [])
    }

    /// Copies of the card's identity in main + side, plus the champion as one.
    static func copies(of card: Card, in deck: Decklist, cards: [String: Card]) -> Int {
        let key = identityKey(card)
        let listed = (deck.mainDeck + deck.sideDeck)
            .filter { entry in cards[entry.cardId].map { identityKey($0) } == key }
            .reduce(0) { $0 + $1.count }
        let champion = deck.champion.flatMap { cards[$0.cardId] }.map { identityKey($0) == key ? 1 : 0 } ?? 0
        return listed + champion
    }

    static func signatures(_ deck: Decklist, cards: [String: Card]) -> Int {
        (deck.mainDeck + deck.sideDeck).filter { cards[$0.cardId]?.isSignature == true }.reduce(0) { $0 + $1.count }
    }

    /// Why another copy cannot go in, or nil when it can.
    static func blocker(_ card: Card, in deck: Decklist, cards: [String: Card]) -> String? {
        switch slot(for: card, in: deck, cards: cards) {
        case .legend, .champion:
            return nil
        case .battlefield:
            if deck.battlefields.contains(where: { $0.cardId == card.id }) { return "Already a battlefield" }
            return deck.battlefields.count >= battlefields ? "3 battlefields already" : nil
        case .rune:
            return total(deck.runes) >= runes ? "12 runes already" : nil
        case .main, .side:
            if !eligible(card, legendDomains: legendDomains(deck, cards: cards)) { return "Outside the legend's domains" }
            if !card.signatureFits(legend: deck.legend.flatMap { cards[$0.cardId] }) { return "Signature card of another champion" }
            if copies(of: card, in: deck, cards: cards) >= copyLimit { return "3 copies already" }
            if card.isSignature && signatures(deck, cards: cards) >= signatureLimit { return "3 signature cards already" }
            if total(deck.mainDeck) >= main { return "Main deck is full" }
            return nil
        }
    }

    static func add(_ card: Card, to deck: Decklist, cards: [String: Card], at now: Date = Date()) -> Decklist {
        let entry = DecklistEntry(cardId: card.id, cardName: card.name, count: 1)
        func plus(_ list: [DecklistEntry]) -> [DecklistEntry] {
            guard list.contains(where: { $0.cardId == card.id }) else { return list + [entry] }
            return list.map { $0.cardId == card.id ? DecklistEntry(cardId: $0.cardId, cardName: $0.cardName, count: $0.count + 1) : $0 }
        }
        var next = deck
        switch slot(for: card, in: deck, cards: cards) {
        case .legend: next.legend = entry
        case .champion: next.champion = entry
        case .battlefield: next.battlefields = plus(deck.battlefields)
        case .rune: next.runes = plus(deck.runes)
        case .main: next.mainDeck = plus(deck.mainDeck)
        case .side: next.sideDeck = plus(deck.sideDeck)
        }
        next.updatedAt = now
        return next
    }

    /// Takes one copy out: main deck first, then side, then the battlefield, rune, champion or legend slot.
    static func remove(_ card: Card, from deck: Decklist, at now: Date = Date()) -> Decklist {
        func minus(_ list: [DecklistEntry]) -> [DecklistEntry] {
            list.compactMap { $0.cardId != card.id ? $0 : $0.count > 1 ? DecklistEntry(cardId: $0.cardId, cardName: $0.cardName, count: $0.count - 1) : nil }
        }
        var next = deck
        if deck.mainDeck.contains(where: { $0.cardId == card.id }) {
            next.mainDeck = minus(deck.mainDeck)
        } else if deck.sideDeck.contains(where: { $0.cardId == card.id }) {
            next.sideDeck = minus(deck.sideDeck)
        } else if deck.battlefields.contains(where: { $0.cardId == card.id }) {
            next.battlefields = minus(deck.battlefields)
        } else if deck.runes.contains(where: { $0.cardId == card.id }) {
            next.runes = minus(deck.runes)
        } else if deck.champion?.cardId == card.id {
            next.champion = nil
        } else if deck.legend?.cardId == card.id {
            next.legend = nil
        } else {
            return deck
        }
        next.updatedAt = now
        return next
    }

    /// Copies of exactly this printing in the deck (all slots).
    static func count(_ card: Card, in deck: Decklist) -> Int {
        let listed = (deck.mainDeck + deck.sideDeck + deck.battlefields + deck.runes).filter { $0.cardId == card.id }.reduce(0) { $0 + $1.count }
        return listed + [deck.champion, deck.legend].filter { $0?.cardId == card.id }.count
    }

    /// Per-deck limit of a card: one legend or battlefield, twelve runes, three copies of anything else.
    static func maxCopies(_ card: Card) -> Int {
        if card.isLegend || card.isBattlefield { return 1 }
        return card.isRune ? runes : copyLimit
    }

    /// The classic `DeckLegality` texts, plus the copy and signature limits and cards outside the legend's
    /// domains, which an imported or re-legended list can break.
    static func issues(_ deck: Decklist, cards: [String: Card] = [:]) -> [String] {
        var out = DeckLegality.evaluate(deck).issues
        guard !cards.isEmpty else { return out }
        let listed = (deck.mainDeck + deck.sideDeck).compactMap { entry in cards[entry.cardId].map { ($0, entry.count) } }
            + [deck.champion.flatMap { cards[$0.cardId] }.map { ($0, 1) }].compactMap { $0 }
        for rows in Dictionary(grouping: listed, by: { identityKey($0.0) }).values.sorted(by: { $0[0].0.name < $1[0].0.name }) {
            let n = rows.reduce(0) { $0 + $1.1 }
            if n > copyLimit { out.append("\(rows[0].0.title): \(n) copies (max \(copyLimit))") }
        }
        let signed = signatures(deck, cards: cards)
        if signed > signatureLimit { out.append("Signature cards: \(signed)/\(signatureLimit)") }
        guard let legend = deck.legend.flatMap({ cards[$0.cardId] }) else { return out }
        var seen = Set<String>()
        let listedCards = (deck.mainDeck + deck.sideDeck).compactMap { cards[$0.cardId] }.filter { seen.insert($0.id).inserted }
        let domains = legendDomains(deck, cards: cards)
        for card in listedCards where !eligible(card, legendDomains: domains) { out.append("\(card.name): outside \(legend.title)'s domains") }
        for card in listedCards where !card.signatureFits(legend: legend) { out.append("\(card.name): signature card of another champion") }
        return out
    }

    /// The pile's chip: Legal, Draft while the main deck is under 30 cards, else the number of issues.
    static func status(_ deck: Decklist, cards: [String: Card]) -> String {
        let n = issues(deck, cards: cards).count
        if n == 0 { return "Legal" }
        if total(deck.mainDeck) < 30 { return "Draft" }
        return n == 1 ? "1 issue" : "\(n) issues"
    }

    static func total(_ entries: [DecklistEntry]) -> Int { entries.reduce(0) { $0 + $1.count } }
}
