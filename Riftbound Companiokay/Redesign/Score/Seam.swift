//
//  Seam.swift
//  Riftbound Companiokay
//
//  The pill on the territory line (Android `Seam.kt`): dice, undo, restart; during the roll its die type,
//  Roll both and close. Liquid Glass on iOS 26. Match mode joins in a later step (docs/IOS_REDESIGN.md).
//

import SwiftUI

struct Seam: View {
    @ObservedObject var c: ScoreController

    var body: some View {
        let s = c.state
        let roll = c.firstRoll
        // Four players: the verdict banner takes the seam's place.
        let gone = s.showSummary || ((roll?.winner ?? -1) >= 0 && !s.isDuel)
        Group {
            if let roll {
                HStack(spacing: 10) {
                    DieKindSwitch(kind: roll.kind, enabled: !roll.busy && !gone) { c.rollKind($0) }
                    Pill(text: s.isDuel ? "Roll both" : "Roll all", height: 42, fill: .white.opacity(0.13), enabled: roll.canRollAll && !gone) { c.rollAll() }
                    RoundIcon(symbol: "xmark", label: "Back to the scoreboard", enabled: !gone) { c.closeRoll() }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.7)))
            } else {
                HStack(spacing: 10) {
                    RoundIcon(symbol: "dice", label: "Roll who goes first", tint: RiftColor.you, fill: RiftColor.you.opacity(0.14), enabled: !gone) { c.openRoll() }
                    RoundIcon(symbol: "arrow.uturn.backward", label: "Undo last point", enabled: s.canUndo && !gone) { c.undo() }
                    RoundIcon(symbol: "arrow.counterclockwise", label: "Restart this game", enabled: !s.gameOver && !gone) { c.askRestart() }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.7)))
            }
        }
        .padding(6)
        .seamBackground()
        .opacity(gone ? 0 : 1)
        .scaleEffect(gone ? 0.85 : 1)
        .animation(.rift(0.5), value: gone)
        .animation(.rift(0.42), value: roll != nil)
    }
}

private extension View {
    @ViewBuilder func seamBackground() -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular.tint(.black.opacity(0.35)), in: Capsule())
        } else {
            background(Color(hex: "080808").opacity(0.92), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
        }
    }
}
