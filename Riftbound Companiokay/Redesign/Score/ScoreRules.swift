//
//  ScoreRules.swift
//  Riftbound Companiokay
//
//  The redesign's scoreboard rules, ported from the Android app (`ScoreRules.kt`, docs/IOS_REDESIGN.md).
//  Immutable: every action returns a new state. A duel ends at 8 and its 8th point by conquering is
//  asked for; undo of 50 steps including XP; a score never below 0, unchanged scores are not recorded.
//  Every game stands alone, also at a PlayRiftbound event (the seam's Report sends the match; Okay,
//  2026-10-26). Checked by tools/check-scoreboard/run.sh.
//

import Foundation

/// 2 players: slot 0 is the opponent (top, turned), slot 1 is you. 4 players: slots 0-1 top, 2-3 bottom.
enum Seat {
    static let opponent = 0
    static let you = 1
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
    var winner = -1
    var asking = -1
    var starter = -1
    var clock = MatchClock()
    var lastGameEndSeconds = 0
    /// The last game's loser, who picks who starts this one (Riftbound's rule); -1 once picked or played.
    var chooser = -1
    /// When `chooser` was asked; without it the question never shows.
    var chooserSince: Date? = nil

    var isDuel: Bool { players.count == 2 }
    var gameOver: Bool { winner >= 0 }
    var canUndo: Bool { !history.isEmpty && !gameOver }

    /// Who is asked who starts, or -1: only within `startChoiceWindow` of the last game, so coming back
    /// to the board hours later does not find the question still open.
    func startChooser(at now: Date) -> Int {
        guard chooser >= 0, let since = chooserSince, now.timeIntervalSince(since) < Self.startChoiceWindow else { return -1 }
        return chooser
    }

    /// Conquer, Hold or a card effect for `slot`; the 8th point by conquering waits for `confirmFinalPoint`.
    func score(_ slot: Int, _ kind: PointKind, at now: Date) -> ScoreState {
        if gameOver { return self }
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

    /// Won or lost by hand (the seam's game menu): a concession, or the last points scored without the
    /// board. The scores stay as they are.
    func end(winner slot: Int) -> ScoreState {
        guard isDuel, !gameOver, players.indices.contains(slot) else { return self }
        var next = self
        next.winner = slot
        next.asking = -1
        next.chooser = -1
        return next
    }

    private func commit(_ slot: Int, delta: Int, type: ScoreEventType, at now: Date) -> ScoreState {
        if gameOver && delta > 0 { return self }
        let old = players[slot].score
        let new = max(0, old + delta)
        if new == old { return self }
        // A game is timed from its own first point: the board (and its clock) is saved, so a game played a
        // day after the last one would count the wait.
        let fresh = events.isEmpty
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
        if isDuel && new >= Self.target && !gameOver { next.winner = slot }
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
        if gameOver { return self }
        var next = self
        next.players = freshSeats
        next.events = []
        next.history = pushed()
        next.asking = -1
        return next
    }

    /// After a won game: the next one; the clock runs on.
    func nextGame(at now: Date) -> ScoreState {
        guard gameOver else { return self }
        var next = self
        next.players = freshSeats
        next.events = []
        next.history = []
        next.winner = -1
        next.asking = -1
        next.starter = -1
        next.chooser = isDuel ? 1 - winner : -1
        next.chooserSince = now
        next.lastGameEndSeconds = clock.elapsedSeconds(at: now)
        return next
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

/// Stopwatch of the board that survives restarts: accumulated time plus the running stretch.
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
}

func clockText(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}
