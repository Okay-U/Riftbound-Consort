//
//  ScoreRules.swift
//  Riftbound Companiokay
//
//  The redesign's scoreboard rules, ported from the Android app (`ScoreRules.kt`, docs/IOS_REDESIGN.md).
//  Immutable: every action returns a new state. A duel ends at 8 and its 8th point by conquering is
//  asked for; undo of 50 steps including XP; a score never below 0, unchanged scores are not recorded.
//  Casual games stand alone; a series (best of 1 or 3, its summary and report) only for a live
//  PlayRiftbound match. Checked by tools/check-scoreboard/run.sh.
//

import Foundation

/// 2 players: slot 0 is the opponent (top, turned), slot 1 is you. 4 players: slots 0-1 top, 2-3 bottom.
enum Seat {
    static let opponent = 0
    static let you = 1
    /// A drawn game in `PlayedGame.winner` and the result picker.
    static let draw = -1
}

enum PointKind {
    case conquer, hold, effect

    var eventType: ScoreEventType {
        switch self {
        case .conquer: return .conquer
        case .hold: return .hold
        case .effect: return .manual
        }
    }
}

struct SeatScore: Codable, Equatable {
    var score = 0
    var xp = 0
}

struct ScoreSnapshot: Codable, Equatable {
    let scores: [Int]
    let xps: [Int]
    let events: [ScoreEvent]
}

/// A finished game of the match: `winner` is a slot or `Seat.draw`, `scores` nil when set by hand.
struct PlayedGame: Codable, Equatable {
    let winner: Int
    var scores: [Int]? = nil
}

struct ScoreState: Codable, Equatable {
    /// Points to win a game in a duel.
    static let target = 8
    /// How long after a game its loser is asked who starts the next one; later the question is stale.
    static let startChoiceWindow: TimeInterval = 10 * 60
    static let undoDepth = 50
    static let xpMax = 99

    var players: [SeatScore] = [SeatScore(), SeatScore()]
    var events: [ScoreEvent] = []
    var history: [ScoreSnapshot] = []
    var log: [PlayedGame] = []
    var gameNo = 1
    var winner = -1
    var asking = -1
    var starter = -1
    var clock = MatchClock()
    var lastGameEndSeconds = 0
    /// The match was ended by hand ("End the match"): the summary shows, scoring stops.
    var ended = false
    /// 0 casual; 1 or 3 a best-of match with its series, summary and report.
    var bestOf = 0
    /// The PlayRiftbound pairing ("R3 · T5") this match was started for; nil for any other.
    var liveTag: String? = nil
    /// The last game's loser, who picks who starts this one (Riftbound's rule); -1 once picked or played.
    var chooser = -1
    /// When `chooser` was asked; without it the question never shows.
    var chooserSince: Date? = nil

    var isDuel: Bool { players.count == 2 }
    var isSeries: Bool { isDuel && bestOf > 0 }
    /// Games to win the match: one of a best of one, two of a best of three.
    var winsNeeded: Int { (bestOf + 1) / 2 }
    var gameOver: Bool { winner >= 0 }
    var matchOver: Bool { isSeries && seriesWins().contains { $0 >= winsNeeded } }
    var canUndo: Bool { !history.isEmpty && !gameOver && !ended }
    var showSummary: Bool { matchOver || ended }

    /// Who is asked who starts, or -1: only within `startChoiceWindow` of the last game, so coming back
    /// to the board hours later does not find the question still open.
    func startChooser(at now: Date) -> Int {
        guard chooser >= 0, let since = chooserSince, now.timeIntervalSince(since) < Self.startChoiceWindow else { return -1 }
        return chooser
    }

    func seriesWins() -> [Int] {
        players.indices.map { slot in log.filter { $0.winner == slot }.count }
    }

    /// Conquer, Hold or a card effect for `slot`; the 8th point by conquering waits for `confirmFinalPoint`.
    func score(_ slot: Int, _ kind: PointKind, at now: Date) -> ScoreState {
        if gameOver || matchOver || ended { return self }
        if isDuel && kind == .conquer && players[slot].score == Self.target - 1 {
            var next = self
            next.asking = slot
            return next
        }
        return commit(slot, delta: 1, type: kind.eventType, at: now)
    }

    func confirmFinalPoint(_ scoreIt: Bool, at now: Date) -> ScoreState {
        var cleared = self
        cleared.asking = -1
        return scoreIt && asking >= 0 ? cleared.commit(asking, delta: 1, type: .conquer, at: now) : cleared
    }

    /// "Fix": take a point back by hand.
    func fix(_ slot: Int, at now: Date) -> ScoreState {
        commit(slot, delta: -1, type: .manual, at: now)
    }

    private func commit(_ slot: Int, delta: Int, type: ScoreEventType, at now: Date) -> ScoreState {
        if gameOver && delta > 0 { return self }
        let old = players[slot].score
        let new = max(0, old + delta)
        if new == old { return self }
        // A casual game is timed from its own first point: the board (and its clock) is saved, so a game
        // played a day after the last one would count the wait. A live match keeps one clock for all games.
        let fresh = !isSeries && events.isEmpty
        let clockNow: MatchClock
        if fresh {
            clockNow = MatchClock(runningSince: now)
        } else if clock.isRunning || clock.elapsedSeconds(at: now) > 0 {
            clockNow = clock
        } else {
            clockNow = clock.started(at: now)
        }
        var next = self
        next.players[slot].score = new
        next.events.append(ScoreEvent(elapsedSeconds: clockNow.elapsedSeconds(at: now), slot: slot, type: type, delta: new - old))
        next.history = pushed()
        next.asking = -1
        next.chooser = -1
        next.clock = clockNow
        if fresh { next.lastGameEndSeconds = 0 }
        if isDuel && new >= Self.target && !gameOver {
            next.winner = slot
            next.log.append(PlayedGame(winner: slot, scores: next.players.map(\.score)))
        }
        return next
    }

    func xp(_ slot: Int, _ delta: Int) -> ScoreState {
        var next = self
        next.players[slot].xp = min(Self.xpMax, max(0, players[slot].xp + delta))
        next.history = pushed()
        return next
    }

    func undo() -> ScoreState {
        guard canUndo, let last = history.last else { return self }
        var next = self
        guard last.scores.count == players.count else {
            next.history = []
            return next
        }
        next.players = players.indices.map { SeatScore(score: last.scores[$0], xp: last.xps[$0]) }
        next.events = last.events
        next.history.removeLast()
        next.asking = -1
        return next
    }

    /// Scores and XP back to 0 in the same game; undoable like the classic reset. The clock keeps running.
    func restart() -> ScoreState {
        if gameOver || matchOver || ended { return self }
        var next = self
        next.players = freshSeats
        next.events = []
        next.history = pushed()
        next.asking = -1
        return next
    }

    /// After a won game: the next one. A series keeps its games, a casual game nothing; the clock runs on.
    func nextGame(at now: Date) -> ScoreState {
        if !gameOver || matchOver || ended { return self }
        var next = self
        next.players = freshSeats
        next.events = []
        next.history = []
        next.log = isSeries ? log : []
        next.gameNo = gameNo + 1
        next.winner = -1
        next.asking = -1
        next.starter = -1
        next.chooser = isDuel ? 1 - winner : -1
        next.chooserSince = now
        next.lastGameEndSeconds = clock.elapsedSeconds(at: now)
        return next
    }

    func newMatch() -> ScoreState {
        ScoreState(players: freshSeats)
    }

    /// One ↔ three games in a live match: the event's setting is not always what the table plays.
    func withBestOf(_ n: Int) -> ScoreState {
        guard isSeries, n == 1 || n == 3, !ended else { return self }
        var next = self
        next.bestOf = n
        return next
    }

    /// A fresh match for a PlayRiftbound pairing in the event's format; who goes first stays as rolled.
    func startLive(tag: String, bestOf: Int) -> ScoreState {
        ScoreState(players: freshSeats, starter: starter, bestOf: bestOf == 1 ? 1 : 3, liveTag: tag)
    }

    func withPlayerCount(_ count: Int) -> ScoreState {
        let n = count == 4 ? 4 : 2
        if n == players.count { return self }
        return ScoreState(players: (0..<n).map { $0 < players.count ? players[$0] : SeatScore() }, clock: clock)
    }

    func withStarter(_ slot: Int, at now: Date) -> ScoreState {
        var next = self
        next.starter = slot
        next.chooser = -1
        next.clock = clock.started(at: now)
        return next
    }

    func toggleClock(at now: Date) -> ScoreState {
        var next = self
        next.clock = clock.isRunning ? clock.paused(at: now) : clock.started(at: now)
        return next
    }

    /// Seconds this game took: match clock minus the end of the previous game (classic `lastGameEnd`).
    func gameSeconds(at now: Date) -> Int {
        let elapsed = clock.elapsedSeconds(at: now)
        return elapsed >= lastGameEndSeconds ? elapsed - lastGameEndSeconds : elapsed
    }

    private var freshSeats: [SeatScore] { Array(repeating: SeatScore(), count: players.count) }

    private func pushed() -> [ScoreSnapshot] {
        Array((history + [ScoreSnapshot(scores: players.map(\.score), xps: players.map(\.xp), events: events)]).suffix(Self.undoDepth))
    }
}

/// Stopwatch for the whole match that survives restarts: accumulated time plus the running stretch.
struct MatchClock: Codable, Equatable {
    var accumulated: TimeInterval = 0
    var runningSince: Date? = nil

    var isRunning: Bool { runningSince != nil }

    func elapsed(at now: Date) -> TimeInterval {
        accumulated + (runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    func elapsedSeconds(at now: Date) -> Int { Int(elapsed(at: now)) }

    func started(at now: Date) -> MatchClock {
        isRunning ? self : MatchClock(accumulated: accumulated, runningSince: now)
    }

    func paused(at now: Date) -> MatchClock {
        isRunning ? MatchClock(accumulated: elapsed(at: now)) : self
    }
}

/// Behind "End the match" and "Set them yourself": one result per game (`Seat.you`, `Seat.opponent` or
/// `Seat.draw`), as many games as the format has; `need` wins decide it.
struct ResultPicker: Equatable {
    let ending: Bool
    var picks: [Int?]
    let need: Int

    func decidedAt() -> Int {
        var me = 0
        var them = 0
        for (i, pick) in picks.enumerated() {
            guard let pick else { return -1 }
            if pick == Seat.you { me += 1 }
            if pick == Seat.opponent { them += 1 }
            if me >= need || them >= need { return i }
        }
        return -1
    }

    func locked(_ i: Int) -> Bool {
        if i > 0 && picks[i - 1] == nil { return true }
        let decided = decidedAt()
        return decided >= 0 && i > decided
    }

    func choose(_ i: Int, _ value: Int) -> ResultPicker {
        var next = self
        next.picks = picks.enumerated().map { j, old in
            j == i ? (old == value ? nil : value) : (j > i ? nil : old)
        }
        return next
    }
}

func clockText(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}
