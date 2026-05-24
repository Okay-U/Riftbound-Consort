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
    let events: [ScoreEvent]
    let startedFirst: Bool?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        deckId: UUID? = nil,
        deckName: String? = nil,
        opponent: String = "",
        result: GameResult,
        durationSeconds: Int,
        events: [ScoreEvent] = [],
        startedFirst: Bool? = nil
    ) {
        self.id = id
        self.date = date
        self.deckId = deckId
        self.deckName = deckName
        self.opponent = opponent
        self.result = result
        self.durationSeconds = durationSeconds
        self.events = events
        self.startedFirst = startedFirst
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case deckId           = "deck_id"
        case deckName         = "deck_name"
        case opponent
        case result
        case durationSeconds  = "duration_seconds"
        case events
        case startedFirst     = "started_first"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.date = try c.decode(Date.self, forKey: .date)
        self.deckId = try c.decodeIfPresent(UUID.self, forKey: .deckId)
        self.deckName = try c.decodeIfPresent(String.self, forKey: .deckName)
        self.opponent = try c.decode(String.self, forKey: .opponent)
        self.result = try c.decode(GameResult.self, forKey: .result)
        self.durationSeconds = try c.decode(Int.self, forKey: .durationSeconds)
        self.events = try c.decodeIfPresent([ScoreEvent].self, forKey: .events) ?? []
        self.startedFirst = try c.decodeIfPresent(Bool.self, forKey: .startedFirst)
    }
}
