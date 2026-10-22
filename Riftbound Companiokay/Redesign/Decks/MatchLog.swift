//
//  MatchLog.swift
//  Riftbound Companiokay
//
//  The match log's numbers (Android `MatchLog.kt`, the classic `GameHistoryView` summary plus the mock's
//  race to 8): wins and losses, first / second, average game, every point with the score after it.
//

import Foundation

/// Wins and losses of a set of games.
struct Tally: Equatable {
    let wins: Int
    let losses: Int

    var games: Int { wins + losses }
    var rate: Double { games == 0 ? 0 : Double(wins) / Double(games) }
    var text: String { "\(wins)–\(losses)" }
    var percent: String { games > 0 ? "\(Int((rate * 100).rounded()))%" : "–" }

    static func of(_ games: [GameRecord]) -> Tally {
        let wins = games.filter { $0.result == .won }.count
        return Tally(wins: wins, losses: games.count - wins)
    }
}

/// One scoring step of a game for the review: who, what, and the score after it.
struct ScorePoint: Equatable {
    let seconds: Int
    let slot: Int
    let kind: ScoreEventType
    let delta: Int
    let you: Int
    let them: Int
}

enum MatchLog {
    static func firstSecond(_ games: [GameRecord]) -> (first: Tally, second: Tally) {
        (Tally.of(games.filter { $0.startedFirst == true }), Tally.of(games.filter { $0.startedFirst == false }))
    }

    static func averageMinutes(_ games: [GameRecord]) -> Int? {
        guard !games.isEmpty else { return nil }
        let seconds: Int = games.reduce(0) { $0 + $1.durationSeconds }
        let minutes = Double(seconds) / 60 / Double(games.count)
        return Int(minutes.rounded())
    }

    /// The 2-player events in order with the running score (never below 0); empty for 4 players.
    static func points(_ game: GameRecord) -> [ScorePoint] {
        guard !game.events.contains(where: { $0.slot > Seat.you }) else { return [] }
        var you = 0
        var them = 0
        return game.events.sorted { $0.elapsedSeconds < $1.elapsedSeconds }.map { e in
            if e.slot == Seat.you { you = max(0, you + e.delta) } else { them = max(0, them + e.delta) }
            return ScorePoint(seconds: e.elapsedSeconds, slot: e.slot, kind: e.type, delta: e.delta, you: you, them: them)
        }
    }

    /// Final score "8–5", nil when the game was saved without a point log.
    static func score(_ game: GameRecord) -> (you: Int, them: Int)? {
        points(game).last.map { ($0.you, $0.them) }
    }

    /// Each lane's points in the order they were scored; a Fix −1 takes the last one back.
    static func race(_ game: GameRecord) -> [Int: [ScoreEventType]] {
        var lanes: [Int: [ScoreEventType]] = [Seat.you: [], Seat.opponent: []]
        for p in points(game) {
            for _ in 0..<abs(p.delta) {
                if p.delta > 0 { lanes[p.slot, default: []].append(p.kind) } else { _ = lanes[p.slot]?.popLast() }
            }
        }
        return lanes
    }

    static func clock(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }

    /// "Darius" for "Darius - Hand of Noxus"; "Unknown" when nobody picked a legend.
    static func opponentShort(_ name: String) -> String {
        let short = Card.championName(name)
        return short.isEmpty ? "Unknown" : short
    }

    /// "Oct 19" like the mock.
    static func shortDate(_ date: Date) -> String { date.formatted(.dateTime.month(.abbreviated).day()) }

    /// "Wed, Oct 22 · 21:40".
    static func longDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) + " · " + date.formatted(date: .omitted, time: .shortened)
    }

    /// The deck a game was played with, by id, or the name it was saved with.
    static func deckName(_ game: GameRecord, in decks: [Decklist]) -> String? {
        decks.first { $0.id == game.deckId }?.name ?? game.deckName
    }
}
