//
//  Decklist.swift
//  Riftbound Companiokay
//

import Foundation

struct Decklist: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date

    var champion: DecklistEntry?
    var legend: DecklistEntry?
    var battlefields: [DecklistEntry]
    var mainDeck: [DecklistEntry]
    var sideDeck: [DecklistEntry]
    var runes: [DecklistEntry]

    init(name: String) {
        self.id           = UUID()
        self.name         = name
        self.createdAt    = Date()
        self.updatedAt    = Date()
        self.champion     = nil
        self.legend       = nil
        self.battlefields = []
        self.mainDeck     = []
        self.sideDeck     = []
        self.runes        = []
    }
}

struct DecklistEntry: Codable, Hashable, Sendable {
    var cardId: String
    var cardName: String
    var count: Int

    enum CodingKeys: String, CodingKey {
        case cardId   = "card_id"
        case cardName = "card_name"
        case count
    }
}

enum DeckSlot: String, CaseIterable, Codable, Sendable {
    case champion
    case legend
    case battlefield
    case mainDeck
    case sideDeck
    case rune

    var displayName: String {
        switch self {
        case .champion:    return "Champion"
        case .legend:      return "Legend"
        case .battlefield: return "Battlefields"
        case .mainDeck:    return "Main deck"
        case .sideDeck:    return "Side deck"
        case .rune:        return "Runes"
        }
    }
}

extension Card {
    /// Default slot a card should be routed to when adding to a deck.
    var preferredSlot: DeckSlot {
        let type = classification?.type?.lowercased()
        let supertype = classification?.supertype?.lowercased()
        if type == "legend" { return .legend }
        if type == "battlefield" { return .battlefield }
        if type == "rune" { return .rune }
        if supertype == "champion" { return .champion }
        return .mainDeck
    }
}
