//
//  DeckEdits.swift
//  Riftbound Companiokay
//
//  Changes made from the deck screen's sheets (Android `DeckEdits.kt`): the champion swap and the
//  battlefields, each returning the new deck. Checked by tools/check-decks/run.sh.
//

import Foundation

enum Pile { case main, side }

enum DeckEdits {
    static func entries(_ deck: Decklist, _ pile: Pile) -> [DecklistEntry] { pile == .main ? deck.mainDeck : deck.sideDeck }

    static func step(_ deck: Decklist, _ pile: Pile, cardId: String, delta: Int, at now: Date) -> Decklist {
        let list = entries(deck, pile).compactMap { entry -> DecklistEntry? in
            guard entry.cardId == cardId else { return entry }
            let count = entry.count + delta
            return count > 0 ? DecklistEntry(cardId: entry.cardId, cardName: entry.cardName, count: count) : nil
        }
        var next = deck
        if pile == .main { next.mainDeck = list } else { next.sideDeck = list }
        next.updatedAt = now
        return next
    }

    /// A domain's runes across printings.
    static func runeCount(_ deck: Decklist, domain: String, cards: [String: Card]) -> Int {
        func isOf(_ entry: DecklistEntry) -> Bool {
            let domains = cards[entry.cardId]?.domains ?? []
            return domains.contains { $0.caseInsensitiveCompare(domain) == .orderedSame }
        }
        return deck.runes.filter(isOf).reduce(0) { $0 + $1.count }
    }

    /// A new chosen champion. One already in the main or side deck swaps places with the old one (classic
    /// `swapChampion`, the card count stays); any other replaces it.
    static func champion(_ deck: Decklist, _ card: Card, at now: Date) -> Decklist {
        let old = deck.champion
        if old?.cardId == card.id { return deck }
        let inMain = deck.mainDeck.contains { $0.cardId == card.id }
        let inSide = deck.sideDeck.contains { $0.cardId == card.id }
        var next = deck
        if inMain || inSide {
            let pile: Pile = inMain ? .main : .side
            next = step(deck, pile, cardId: card.id, delta: -1, at: now)
            // The old champion takes the freed place in the same pile, so main and side keep their size.
            if let old {
                let list = entries(next, pile)
                let back = list.contains { $0.cardId == old.cardId }
                    ? list.map { $0.cardId == old.cardId ? DecklistEntry(cardId: $0.cardId, cardName: $0.cardName, count: $0.count + 1) : $0 }
                    : list + [DecklistEntry(cardId: old.cardId, cardName: old.cardName, count: 1)]
                if pile == .main { next.mainDeck = back } else { next.sideDeck = back }
            }
        }
        next.champion = DecklistEntry(cardId: card.id, cardName: card.name, count: 1)
        next.updatedAt = now
        return next
    }

    /// nil when three are chosen already and the card is not one of them.
    static func toggleBattlefield(_ deck: Decklist, _ card: Card, at now: Date) -> Decklist? {
        var next = deck
        if deck.battlefields.contains(where: { $0.cardId == card.id }) {
            next.battlefields = deck.battlefields.filter { $0.cardId != card.id }
        } else if DeckRules.total(deck.battlefields) >= DeckRules.battlefields {
            return nil
        } else {
            next.battlefields = deck.battlefields + [DecklistEntry(cardId: card.id, cardName: card.name, count: 1)]
        }
        next.updatedAt = now
        return next
    }
}
