import Foundation

// The Android unit tests of the same rules (ScoreRulesTest, DuelTest, ResultPickerTest), case by case.

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
    check(won.log == [PlayedGame(winner: Seat.you, scores: [0, 8])], "log")
    check(atSeven.score(Seat.you, .hold, at: t0).winner == Seat.you, "hold wins")
}

// A won game blocks points and undo until the next game.
do {
    let won = ScoreState(bestOf: 3).points(Seat.opponent, 3).points(Seat.you, 8)
    check(won.gameOver && !won.canUndo, "blocked")
    check(won == won.score(Seat.opponent, .hold, at: t0) && won == won.undo() && won == won.restart(), "no-ops")
    let next = won.nextGame(at: t0)
    check(next.gameNo == 2 && next.players.map(\.score) == [0, 0], "next game")
    check(next.seriesWins() == [0, 1] && !next.gameOver, "series kept")
}

// Two won games end the best of three, a new match resets everything.
do {
    let over = ScoreState(bestOf: 3).points(Seat.you, 8).nextGame(at: t0).points(Seat.opponent, 8).nextGame(at: t0).points(Seat.you, 8)
    check(over.matchOver && over == over.nextGame(at: t0), "match over")
    check(over.newMatch() == ScoreState(), "new match")
}

// Casual games stand alone and never end a match.
do {
    let won = ScoreState().points(Seat.you, 8)
    check(won.gameOver && !won.matchOver, "casual won")
    let next = won.nextGame(at: t0)
    check(next.gameNo == 2 && next.log.isEmpty, "casual next")
    check(!next.points(Seat.you, 8).nextGame(at: t0).points(Seat.you, 8).matchOver, "never a match")
}

// A best of one ends with its game.
do {
    let over = ScoreState(bestOf: 1).points(Seat.opponent, 8)
    check(over.matchOver && over.winsNeeded == 1, "best of one")
}

// A series exists only for a live match, casual cannot become one.
do {
    let playing = ScoreState().points(Seat.you, 3)
    check(playing.withBestOf(3) == playing, "casual stays casual")
}

// A live match starts in the event's format and can switch between one and three games.
do {
    let rolled = ScoreState().points(Seat.you, 2).withStarter(Seat.opponent, at: t0)
    let live = rolled.startLive(tag: "R3 · T5", bestOf: 1)
    check(live.bestOf == 1 && live.liveTag == "R3 · T5" && live.players.map(\.score) == [0, 0], "live match")
    check(live.starter == Seat.opponent, "who goes first was rolled before")
    let wonFirst = live.points(Seat.you, 8)
    check(wonFirst.matchOver && !wonFirst.withBestOf(3).matchOver, "best of three after all")
    check(live.startLive(tag: "R3 · T5", bestOf: 3).bestOf == 3, "event best of three")
    check(wonFirst.newMatch() == ScoreState(), "casual after a live match")
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

// The match clock starts on the first point, pauses, and times each game.
do {
    let first = ScoreState().score(Seat.you, .hold, at: t0)
    check(first.clock.isRunning, "clock starts")
    let paused = first.toggleClock(at: at(90))
    check(paused.clock.elapsedSeconds(at: at(500)) == 90, "paused")
    let resumed = paused.toggleClock(at: at(500))
    check(resumed.clock.elapsedSeconds(at: at(510)) == 100, "resumed")
    let won = resumed.points(Seat.you, 7, at: at(600))
    check(won.gameSeconds(at: at(600)) == 190, "game seconds")
    let next = won.nextGame(at: at(600))
    check(next.clock.isRunning, "clock runs on")
    // A casual game counts from its own first point.
    let started = next.points(Seat.opponent, 1, at: at(660))
    check(started.events.count == 1 && started.events[0].elapsedSeconds == 0, "casual from its first point")
    check(started.points(Seat.opponent, 7, at: at(720)).gameSeconds(at: at(720)) == 60, "casual game time")
    // A live match keeps one clock: its next game counts from the end of the last one.
    let live = ScoreState(bestOf: 3).points(Seat.you, 8, at: at(60)).nextGame(at: at(60))
    check(live.points(Seat.opponent, 8, at: at(180)).gameSeconds(at: at(180)) == 120, "live clock")
}

do {
    check(clockText(0) == "00:00" && clockText(3069) == "51:09", "clock text")
}

// The saved board reads back as it was.
do {
    let s = ScoreState(bestOf: 3).points(Seat.you, 8, at: at(30)).nextGame(at: at(40)).points(Seat.opponent, 2, .conquer, at: at(50)).xp(Seat.you, 2)
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

// Games unlock in order and lock again after the deciding game.
do {
    let empty = ResultPicker(ending: true, picks: [nil, nil, nil], need: 2)
    check(!empty.locked(0) && empty.locked(1), "in order")
    let twoWins = empty.choose(0, Seat.you).choose(1, Seat.you)
    check(twoWins.decidedAt() == 1 && twoWins.locked(2), "decided")
    let split = empty.choose(0, Seat.you).choose(1, Seat.opponent)
    check(split.decidedAt() == -1 && !split.locked(2), "split")
    // Changing a game clears the games after it, tapping again clears it.
    let full = empty.choose(0, Seat.you).choose(1, Seat.opponent).choose(2, Seat.draw)
    check(full.choose(0, Seat.opponent).picks == [Seat.opponent, nil, nil], "change clears after")
    check(full.choose(1, Seat.you).picks == [Seat.you, Seat.you, nil], "change the middle")
    check(empty.choose(0, Seat.you).choose(0, Seat.you).picks == [nil, nil, nil], "tap again clears")
    // One game decides a best of one.
    let one = ResultPicker(ending: true, picks: [nil], need: 1)
    check(one.decidedAt() == -1 && one.choose(0, Seat.opponent).decidedAt() == 0, "best of one picker")
}

print("scoreboard rules ok (\(checks) checks)")
