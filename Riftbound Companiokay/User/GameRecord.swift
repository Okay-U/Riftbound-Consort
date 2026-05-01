//
//  GameRecord.swift
//  Riftbound Companiokay
//

import Foundation

enum GameResult: String, Codable, Sendable {
    case won
    case lost
}

struct GameRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let deckId: UUID?
    let deckName: String?
    let opponent: String
    let result: GameResult
    let durationSeconds: Int

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        deckId: UUID? = nil,
        deckName: String? = nil,
        opponent: String = "",
        result: GameResult,
        durationSeconds: Int
    ) {
        self.id = id
        self.date = date
        self.deckId = deckId
        self.deckName = deckName
        self.opponent = opponent
        self.result = result
        self.durationSeconds = durationSeconds
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case deckId           = "deck_id"
        case deckName         = "deck_name"
        case opponent
        case result
        case durationSeconds  = "duration_seconds"
    }
}
