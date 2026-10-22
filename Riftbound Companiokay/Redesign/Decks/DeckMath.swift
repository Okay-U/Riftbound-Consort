//
//  DeckMath.swift
//  Riftbound Companiokay
//
//  The deck tools' numbers (Android `DeckMath.kt`, classic `DrawProbabilityView`, `DeckStatsView`,
//  `DrawHandView`): draw odds, the stats sheet, the test hand with its mulligan. Checked by
//  tools/check-decks/run.sh.
//

import Foundation

/// Hypergeometric draw odds: P(at least k of K copies in n cards of N).
enum Odds {
    static func binomial(_ n: Int, _ k: Int) -> Double {
        guard k >= 0, k <= n else { return 0 }
        var r = 1.0
        for i in 0..<min(k, n - k) { r = r * Double(n - i) / Double(i + 1) }
        return r
    }

    static func atLeast(deck: Int, copies: Int, drawn: Int, k: Int) -> Double {
        guard deck > 0, copies >= 0, drawn >= 0, k >= 0, drawn <= deck, copies <= deck else { return 0 }
        let top = min(copies, drawn)
        guard k <= top else { return 0 }
        let hits = (k...top).reduce(0.0) { $0 + binomial(copies, $1) * binomial(deck - copies, drawn - $1) }
        return hits / binomial(deck, drawn)
    }
}

/// The stats sheet: energy curve 0…7+, power per domain, card types, average energy.
struct DeckStats {
    struct Share: Equatable {
        let name: String
        let count: Int
    }

    let curve: [Int]
    let power: [Share]
    let types: [Share]
    let averageEnergy: Double?

    private static let domainOrder = ["fury", "calm", "mind", "body", "chaos", "order"]

    /// Curve, types and average count the main deck and the chosen champion; power also the sideboard (classic).
    static func of(_ deck: Decklist, cards: [String: Card]) -> DeckStats {
        func resolved(_ entries: [DecklistEntry]) -> [(card: Card, count: Int)] {
            entries.compactMap { entry in cards[entry.cardId].map { ($0, entry.count) } }
        }
        let champion = deck.champion.flatMap { cards[$0.cardId] }.map { [(card: $0, count: 1)] } ?? []
        let main = resolved(deck.mainDeck) + champion
        var curve = Array(repeating: 0, count: 8)
        var energy = 0
        var costed = 0
        for (card, n) in main {
            guard let e = card.attributes?.energy else { continue }
            curve[min(max(e, 0), 7)] += n
            energy += e * n
            costed += n
        }
        var power: [String: Int] = [:]
        for (card, n) in main + resolved(deck.sideDeck) {
            let p = card.attributes?.power ?? 0
            guard p > 0 else { continue }
            for domain in card.domains { power[domain.lowercased(), default: 0] += p * n }
        }
        func count(of type: String) -> Int {
            let ofType = main.filter { $0.card.typeName.caseInsensitiveCompare(type) == .orderedSame }
            return ofType.reduce(0) { $0 + $1.count }
        }
        let types = ["Unit", "Spell", "Gear"].map { Share(name: $0, count: count(of: $0)) }
        return DeckStats(
            curve: curve,
            power: domainOrder.compactMap { d in power[d].map { Share(name: d.capitalized, count: $0) } },
            types: types,
            averageEnergy: costed > 0 ? Double(energy) / Double(costed) : nil
        )
    }
}

/// A test hand with the mock's rules: four cards, one mulligan of up to two cards that go to the bottom of the
/// deck, draw one at a time up to eight.
struct Hand: Equatable {
    struct HandCard: Equatable, Identifiable {
        let id: Int
        let cardId: String
    }

    static let opening = 4
    static let mulliganMax = 2
    static let max = 8

    let pile: [String]
    let cards: [HandCard]
    let marked: Set<Int>
    let mulliganUsed: Bool
    /// Ids go on across hands, so a new hand's cards are new cards to the screen.
    let nextId: Int

    var canDraw: Bool { !pile.isEmpty && cards.count < Self.max }
    var canMulligan: Bool { !mulliganUsed && !marked.isEmpty }

    /// The hand with the card marked or unmarked, or unchanged with the reason.
    func toggle(_ id: Int) -> (hand: Hand, note: String?) {
        if mulliganUsed { return (self, "One mulligan per game") }
        if cards.count > Self.opening { return (self, "Only the opening hand can be mulliganed") }
        if marked.contains(id) { return (with(marked: marked.subtracting([id])), nil) }
        if marked.count >= Self.mulliganMax { return (self, "Mulligan up to 2 cards") }
        return (with(marked: marked.union([id])), nil)
    }

    func mulligan() -> Hand {
        guard canMulligan else { return self }
        var next = nextId
        var top = ArraySlice(pile)
        var back: [String] = []
        let kept = cards.map { card -> HandCard in
            guard marked.contains(card.id), let drawn = top.first else { return card }
            back.append(card.cardId)
            top = top.dropFirst()
            let fresh = HandCard(id: next, cardId: drawn)
            next += 1
            return fresh
        }
        return Hand(pile: Array(top) + back, cards: kept, marked: [], mulliganUsed: true, nextId: next)
    }

    func draw() -> Hand {
        guard canDraw, let top = pile.first else { return self }
        return Hand(pile: Array(pile.dropFirst()), cards: cards + [HandCard(id: nextId, cardId: top)], marked: [], mulliganUsed: mulliganUsed, nextId: nextId + 1)
    }

    private func with(marked: Set<Int>) -> Hand {
        Hand(pile: pile, cards: cards, marked: marked, mulliganUsed: mulliganUsed, nextId: nextId)
    }

    /// A fresh shuffle of the main deck.
    static func deal<G: RandomNumberGenerator>(_ deck: Decklist, firstId: Int = 0, using random: inout G) -> Hand {
        let all = deck.mainDeck.flatMap { Array(repeating: $0.cardId, count: $0.count) }.shuffled(using: &random)
        let first = all.prefix(opening)
        return Hand(
            pile: Array(all.dropFirst(first.count)),
            cards: first.enumerated().map { HandCard(id: firstId + $0.offset, cardId: $0.element) },
            marked: [], mulliganUsed: false, nextId: firstId + first.count
        )
    }

    static func deal(_ deck: Decklist, firstId: Int = 0) -> Hand {
        var random = SystemRandomNumberGenerator()
        return deal(deck, firstId: firstId, using: &random)
    }
}
