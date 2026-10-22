//
//  FirstRoll.swift
//  Riftbound Companiokay
//
//  Who goes first (Android `Duel.kt`): every player rolls, the single highest roll wins, ties roll again.
//  With two players the winner picks first or second; with four the winner starts.
//

import Foundation

struct FirstRoll: Equatable {
    enum DieKind: Int, CaseIterable {
        case d20 = 20, d6 = 6
        var label: String { "D\(rawValue)" }
    }

    struct Die: Equatable {
        var value: Int? = nil
        var rolling = false
        var rolls = 0
    }

    enum Choice { case first, second }

    var kind: DieKind = .d20
    var dice: [Die]
    var winner = -1
    var tie = false
    var choice: Choice? = nil

    var busy: Bool { dice.contains { $0.rolling } }
    var decided: Bool { winner >= 0 || tie }
    var canRollAll: Bool { !busy && !decided && dice.contains { $0.value == nil } }

    func canRoll(_ slot: Int) -> Bool { !decided && !dice[slot].rolling && dice[slot].value == nil }

    func rolling(_ slot: Int) -> FirstRoll {
        var next = self
        next.dice[slot].rolling = true
        return next
    }

    /// One face of the tumble, or the final value when `done`.
    func shown(_ slot: Int, value: Int, done: Bool) -> FirstRoll {
        var next = self
        next.dice[slot].value = value
        next.dice[slot].rolling = !done
        next.dice[slot].rolls += 1
        return next.settled()
    }

    private func settled() -> FirstRoll {
        if dice.contains(where: { $0.rolling || $0.value == nil }) { return self }
        let top = dice.map { $0.value ?? 0 }.max() ?? 0
        let leaders = dice.indices.filter { dice[$0].value == top }
        var next = self
        if leaders.count == 1 { next.winner = leaders[0] } else { next.tie = true }
        return next
    }

    func rerolled() -> FirstRoll { FirstRoll.start(players: dice.count, kind: kind) }

    /// 2 players: the winner chooses; with 4 the winner simply starts.
    func starter() -> Int {
        if winner < 0 { return -1 }
        return dice.count == 2 && choice == .second ? 1 - winner : winner
    }

    static func start(players: Int, kind: DieKind = .d20) -> FirstRoll {
        FirstRoll(kind: kind, dice: Array(repeating: Die(), count: players))
    }

    /// Waits between tumbling faces in milliseconds: quick at first, slowing down (38 ms × 1.27ⁿ, 11 faces).
    static let tumbleWaitsMs: [Int] = (0..<11).map { Int((38 * pow(1.27, Double($0))).rounded()) }

    /// A random face that differs from the one shown before, so the tumble visibly moves.
    static func face(sides: Int, notThis: Int?, using rng: inout some RandomNumberGenerator) -> Int {
        let value = Int.random(in: 1...sides, using: &rng)
        return value == notThis ? value % sides + 1 : value
    }
}
