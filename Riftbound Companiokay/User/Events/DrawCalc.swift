//
//  DrawCalc.swift
//  Riftbound Companiokay
//
//  "Can I draw into top cut?" Swiss math. Pure, deterministic, no UI — so the
//  logic can be reasoned about (and unit-tested once a test target exists).
//
//  Points: win 3, draw 1, loss 0. The calc is conservative: it ignores pairing
//  constraints (only one player per pairing can win), so a "locked" verdict is a
//  true guarantee — if anything, real life is kinder than this worst case.
//

import Foundation

nonisolated enum CutChance: Sendable, Equatable {
    case locked   // guaranteed top cut, no matter how every other match ends
    case bubble   // makes it in some outcomes, comes down to results / tiebreakers
    case out      // cannot reach top cut on this line

    var label: String {
        switch self {
        case .locked: return "Locked in"
        case .bubble: return "Bubble"
        case .out:    return "Out"
        }
    }
}

/// A rival in the top-cut race: points so far and matches still to play (0 once dropped).
nonisolated struct DrawContender: Sendable, Equatable {
    let points: Int
    let remaining: Int
}

nonisolated enum DrawCalc {
    static let pointsPerWin = 3
    static let pointsPerDraw = 1
    static let pointsPerLoss = 0

    /// Verdict if I take the same result (`perRoundPoints`) in each of my `myRemaining`
    /// matches. Every rival carries their own remaining matches, so results already
    /// reported in the running round count and dropped players cannot climb.
    static func chance(myPoints: Int,
                       myRemaining: Int,
                       others: [DrawContender],
                       cut: Int,
                       perRoundPoints: Int) -> CutChance {
        guard cut > 0, myRemaining >= 1 else { return .bubble }

        let myFinal = myPoints + perRoundPoints * myRemaining

        // Always strictly above me, even if they lose every remaining match.
        let guaranteedAbove = others.lazy.filter { $0.points > myFinal }.count
        if guaranteedAbove >= cut { return .out }

        // Could finish at or above me if they win enough (worst case for me).
        let contenders = others.lazy.filter { $0.points + pointsPerWin * $0.remaining >= myFinal }.count
        if contenders < cut { return .locked }

        return .bubble
    }

    static func outlook(myPoints: Int,
                        myRemaining: Int,
                        others: [DrawContender],
                        cut: Int) -> (win: CutChance, draw: CutChance, lose: CutChance) {
        (
            win:  chance(myPoints: myPoints, myRemaining: myRemaining, others: others, cut: cut, perRoundPoints: pointsPerWin),
            draw: chance(myPoints: myPoints, myRemaining: myRemaining, others: others, cut: cut, perRoundPoints: pointsPerDraw),
            lose: chance(myPoints: myPoints, myRemaining: myRemaining, others: others, cut: cut, perRoundPoints: pointsPerLoss)
        )
    }

    /// Everyone with the same number of rounds left (between rounds, legacy Locator screen).
    static func chance(myPoints: Int, others: [Int], cut: Int, roundsLeft: Int, perRoundPoints: Int) -> CutChance {
        chance(myPoints: myPoints, myRemaining: roundsLeft,
               others: others.map { DrawContender(points: $0, remaining: roundsLeft) },
               cut: cut, perRoundPoints: perRoundPoints)
    }

    static func outlook(myPoints: Int, others: [Int], cut: Int, roundsLeft: Int) -> (win: CutChance, draw: CutChance, lose: CutChance) {
        outlook(myPoints: myPoints, myRemaining: roundsLeft,
                others: others.map { DrawContender(points: $0, remaining: roundsLeft) }, cut: cut)
    }
}
