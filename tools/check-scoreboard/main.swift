import Foundation
import SwiftUI

// The Android unit tests of the same rules (ScoreRulesTest, DuelTest), case by case.

let t0 = Date(timeIntervalSince1970: 1_000)
func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

extension ScoreState {
    func points(_ slot: Int, _ n: Int, _ kind: PointKind = .hold, at now: Date = t0) -> ScoreState {
        (0..<n).reduce(self) { s, _ in s.score(slot, kind, at: now) }
    }
}

var checks = 0
func check(_ ok: Bool, _ what: String, line: Int = #line) {
    checks += 1
    if !ok {
        print("FAIL line \(line): \(what)")
        exit(1)
    }
}

/// Seeded generator so the face check is repeatable.
struct SplitMix: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// Points are recorded as classic events and never go below zero.
do {
    let s = ScoreState().score(Seat.you, .conquer, at: t0).score(Seat.you, .effect, at: t0).fix(Seat.opponent, at: t0)
    check(s.players.map(\.score) == [0, 2], "scores")
    check(s.events.map { "\($0.type.rawValue):\($0.delta)" } == ["conquer:1", "manual:1"], "event types")
    check(s.history.count == 2, "the no-op fix on 0 pushed nothing")
}

// The eighth point by conquering is asked for, hold wins directly.
do {
    let atSeven = ScoreState().points(Seat.you, 7)
    let asked = atSeven.score(Seat.you, .conquer, at: t0)
    check(asked.asking == Seat.you && asked.players[Seat.you].score == 7, "asked")
    let declined = asked.confirmFinalPoint(false, at: t0)
    check(declined.asking == -1 && declined.players[Seat.you].score == 7, "declined")
    let won = asked.confirmFinalPoint(true, at: t0)
    check(won.winner == Seat.you, "won")
    check(atSeven.score(Seat.you, .hold, at: t0).winner == Seat.you, "hold wins")
}

// A won game blocks points and undo until the next game.
do {
    let won = ScoreState().points(Seat.opponent, 3).points(Seat.you, 8)
    check(won.gameOver && !won.canUndo, "blocked")
    check(won == won.score(Seat.opponent, .hold, at: t0) && won == won.undo() && won == won.restart(), "no-ops")
    let next = won.nextGame(at: t0)
    check(next.players.map(\.score) == [0, 0] && !next.gameOver && next.history.isEmpty, "next game")
    check(ScoreState() == ScoreState().nextGame(at: t0), "no next game while playing")
}

// Won or lost by hand ends the game as it stands; four players have no winner.
do {
    let playing = ScoreState().points(Seat.you, 5).points(Seat.opponent, 3, .conquer)
    let conceded = playing.end(winner: Seat.you)
    check(conceded.winner == Seat.you && conceded.players.map(\.score) == [3, 5], "won by hand")
    check(playing.end(winner: Seat.opponent).winner == Seat.opponent, "lost by hand")
    check(conceded.end(winner: Seat.opponent) == conceded, "decided once")
    check(conceded.nextGame(at: t0).chooser == Seat.opponent, "the loser picks next")
    let asked = ScoreState().points(Seat.you, 7).score(Seat.you, .conquer, at: t0)
    check(asked.end(winner: Seat.you).asking == -1, "the open question closes")
    check(ScoreState().withPlayerCount(4).end(winner: 2) == ScoreState().withPlayerCount(4), "four players")
    check(playing.end(winner: 5) == playing, "no such seat")
}

// The last game's loser picks who starts the next one, asked right after the game only.
do {
    let next = ScoreState().points(Seat.opponent, 8).nextGame(at: t0)
    check(next.chooser == Seat.you, "loser picks")
    check(next.withStarter(Seat.opponent, at: t0).chooser == -1, "picked")
    check(next.points(Seat.opponent, 1).chooser == -1, "playing on closes the question")
    check(ScoreState().chooser == -1, "fresh board")
    check(next.startChooser(at: at(60)) == Seat.you, "asked soon after")
    check(next.startChooser(at: at(ScoreState.startChoiceWindow)) == -1, "stale later")
    var unknown = next
    unknown.chooserSince = nil
    check(unknown.startChooser(at: t0) == -1, "never without its time")
}

// Undo walks back points and XP, at most fifty steps.
do {
    let s = ScoreState().points(Seat.you, 2).xp(Seat.you, 1).xp(Seat.you, 1)
    check(s.players[Seat.you].xp == 2, "xp")
    let back = s.undo().undo()
    check(back.players[Seat.you].xp == 0 && back.players[Seat.you].score == 2, "undo xp")
    let many = (0..<60).reduce(ScoreState()) { acc, _ in acc.xp(Seat.you, 1) }
    check(many.history.count == 50, "undo depth")
}

// Restart zeroes the game and can be undone.
do {
    let s = ScoreState().points(Seat.you, 5).xp(Seat.opponent, 3).restart()
    check(s.players.map(\.score) == [0, 0] && s.players.map(\.xp) == [0, 0] && s.events.isEmpty, "restart")
    let undone = s.undo()
    check(undone.players[Seat.you].score == 5 && undone.players[Seat.opponent].xp == 3, "undo restart")
}

// Four players have no target and no conquer question.
do {
    let s = ScoreState().withPlayerCount(4).points(2, 9, .conquer)
    check(s.players[2].score == 9 && s.winner == -1 && s.asking == -1, "four players")
}

// The clock starts on the first point and times each game.
do {
    let first = ScoreState().score(Seat.you, .hold, at: t0)
    check(first.clock.isRunning, "clock starts")
    let won = first.points(Seat.you, 7, at: at(190))
    check(won.gameSeconds(at: at(190)) == 190, "game seconds")
    let next = won.nextGame(at: at(600))
    check(next.clock.isRunning, "clock runs on")
    // Every game counts from its own first point.
    let started = next.points(Seat.opponent, 1, at: at(660))
    check(started.events.count == 1 && started.events[0].elapsedSeconds == 0, "from its first point")
    check(started.points(Seat.opponent, 7, at: at(720)).gameSeconds(at: at(720)) == 60, "game time")
    // A game ended by hand before its first point counts from the end of the last one.
    check(next.end(winner: Seat.you).gameSeconds(at: at(630)) == 30, "pointless game time")
}

do {
    check(clockText(0) == "00:00" && clockText(3069) == "51:09", "clock text")
}

// The saved board reads back as it was.
do {
    let s = ScoreState().points(Seat.you, 8, at: at(30)).nextGame(at: at(40)).points(Seat.opponent, 2, .conquer, at: at(50)).xp(Seat.you, 2)
    let back = try JSONDecoder().decode(ScoreState.self, from: JSONEncoder().encode(s))
    check(back == s, "JSON round trip")
}

// The higher roll wins once both dice have landed.
do {
    let d = FirstRoll.start(players: 2).rolling(0).rolling(1).shown(0, value: 4, done: false)
    check(d.busy, "busy")
    let landed = d.shown(0, value: 7, done: true).shown(1, value: 15, done: true)
    check(landed.winner == Seat.you && !landed.tie, "higher wins")
}

// A tie rolls again and the winner may let the other start.
do {
    let tie = FirstRoll.start(players: 2).shown(0, value: 9, done: true).shown(1, value: 9, done: true)
    check(tie.tie && tie.rerolled().dice.map(\.value) == [nil, nil], "tie")
    let won = FirstRoll.start(players: 2).shown(0, value: 12, done: true).shown(1, value: 3, done: true)
    var first = won
    first.choice = .first
    var second = won
    second.choice = .second
    check(first.starter() == Seat.opponent && second.starter() == Seat.you, "winner's choice")
}

// With four players the single highest starts.
do {
    let rolls = [2, 6, 5, 1], tied = [6, 6, 5, 1]
    let d = (0..<4).reduce(FirstRoll.start(players: 4, kind: .d6)) { acc, i in acc.shown(i, value: rolls[i], done: true) }
    check(d.starter() == 1, "four players")
    let t = (0..<4).reduce(FirstRoll.start(players: 4, kind: .d6)) { acc, i in acc.shown(i, value: tied[i], done: true) }
    check(t.tie, "four players tie")
}

// Tumbling faces slow down and never repeat the face before.
do {
    let w = FirstRoll.tumbleWaitsMs
    check(w.count == 11 && w.first == 38 && zip(w, w.dropFirst()).allSatisfy { $0 < $1 }, "tumble waits")
    var rng = SplitMix(state: 7)
    for _ in 0..<200 { check(FirstRoll.face(sides: 6, notThis: 5, using: &rng) != 5, "face differs") }
}

// Colour model C on every player colour (the palette, Rift Green, Rift Violet): white on a field and on a
// leading seat, the seat colour on its own field, Conquer's ink on white (WCAG contrast).
do {
    func linear(_ color: Color) -> SIMD3<Float> {
        let c = color.resolve(in: EnvironmentValues())
        return SIMD3(c.linearRed, c.linearGreen, c.linearBlue)
    }
    func contrast(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let x = 0.2126 * a.x + 0.7152 * a.y + 0.0722 * a.z + 0.05
        let y = 0.2126 * b.x + 0.7152 * b.y + 0.0722 * b.z + 0.05
        return max(x, y) / min(x, y)
    }
    let white = SIMD3<Float>(1, 1, 1)
    let green = linear(Color(hex: "2BE38B")), violet = linear(Color(hex: "A99BFF"))
    for seat in Palette.colors.map(linear) + [green, violet] {
        let field = SeatShade.deep(seat), drawn = SeatShade.lift(seat)
        check(contrast(field, white) >= 7, "white on the field")
        check(contrast(SeatShade.deep(seat, depth: 1.125), white) >= 4.5, "white on a leading seat")
        check(contrast(drawn, field) >= 3.3, "seat colour on its field")
        check(contrast(SeatShade.deep(drawn, depth: 0.75), white) >= 4.5, "Conquer's ink")
    }
    check(SeatShade.lift(green) == green && SeatShade.lift(violet) == violet, "the default colours stay")
}

print("scoreboard rules ok (\(checks) checks)")
