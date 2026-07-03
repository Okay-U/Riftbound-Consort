//
//  DeckLegality.swift
//  Riftbound Companiokay
//

import Foundation

struct DeckLegality {
    let issues: [String]

    var isLegal: Bool { issues.isEmpty }

    static func evaluate(_ deck: Decklist) -> DeckLegality {
        var issues: [String] = []

        if deck.champion == nil { issues.append("Missing champion") }
        if deck.legend == nil { issues.append("Missing legend") }

        let battlefields = totalCount(deck.battlefields)
        if battlefields != 3 {
            issues.append("Battlefields: \(battlefields)/3")
        }

        let main = totalCount(deck.mainDeck)
        if main != 39 {
            issues.append("Main deck: \(main)/39")
        }

        let side = totalCount(deck.sideDeck)
        if side != 0 && side != 8 {
            issues.append("Side deck: \(side) (must be 0 or 8)")
        }

        let runes = totalCount(deck.runes)
        if runes != 12 {
            issues.append("Runes: \(runes)/12")
        }

        return DeckLegality(issues: issues)
    }

    private static func totalCount(_ entries: [DecklistEntry]) -> Int {
        entries.reduce(0) { $0 + $1.count }
    }
}
