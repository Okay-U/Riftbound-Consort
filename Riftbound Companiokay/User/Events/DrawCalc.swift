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

nonisolated enum DrawCalc {
    static let pointsPerWin = 3
    static let pointsPerDraw = 1
    static let pointsPerLoss = 0

    /// Verdict if I take the same result (`perRoundPoints`) in every one of the
    /// `roundsLeft` remaining Swiss rounds.
    ///
    /// - Parameters:
    ///   - myPoints: my current match points (from standings).
    ///   - others:   every *other* player's current match points.
    ///   - cut:      top-cut size (e.g. 8).
    ///   - roundsLeft: Swiss rounds still to play (≥ 1).
    ///   - perRoundPoints: 3 win-out, 1 draw-out, 0 lose-out.
    static func chance(myPoints: Int,
                       others: [Int],
                       cut: Int,
                       roundsLeft: Int,
                       perRoundPoints: Int) -> CutChance {
        guard cut > 0, roundsLeft >= 1 else { return .bubble }

        let myFinal = myPoints + perRoundPoints * roundsLeft
        let maxGain = pointsPerWin * roundsLeft

        // Always strictly above me, even if they lose every remaining round.
        let guaranteedAbove = others.lazy.filter { $0 > myFinal }.count
        if guaranteedAbove >= cut { return .out }

        // Could finish at or above me if they win enough (worst case for me).
        let contenders = others.lazy.filter { $0 + maxGain >= myFinal }.count
        if contenders < cut { return .locked }

        return .bubble
    }

    /// Win-out / draw-out / lose-out verdicts in one call.
    static func outlook(myPoints: Int,
                        others: [Int],
                        cut: Int,
                        roundsLeft: Int) -> (win: CutChance, draw: CutChance, lose: CutChance) {
        (
            win:  chance(myPoints: myPoints, others: others, cut: cut, roundsLeft: roundsLeft, perRoundPoints: pointsPerWin),
            draw: chance(myPoints: myPoints, others: others, cut: cut, roundsLeft: roundsLeft, perRoundPoints: pointsPerDraw),
            lose: chance(myPoints: myPoints, others: others, cut: cut, roundsLeft: roundsLeft, perRoundPoints: pointsPerLoss)
        )
    }
}
