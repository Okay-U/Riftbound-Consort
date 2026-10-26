//
//  Seam.swift
//  Riftbound Companiokay
//
//  The pill on the territory line (Android `Seam.kt`): dice, undo and the game menu (won, lost, restart);
//  during the roll its die type, Roll both and close. Match mode adds the PlayRiftbound check and the event
//  line (event before round 1, bye, reported round), or for a pairing its round, table, opponent or round
//  clock with a green Report. Liquid Glass on iOS 26.
//

import SwiftUI

struct Seam: View {
    @ObservedObject var c: ScoreController
    var match: MatchInfo? = nil
    var checking = false
    var onCheck: () -> Void = {}
    /// The centre leads to the event, after a question: a slip must not take the scoreboard away.
    var onOpenEvent: (() -> Void)? = nil
    var onReport: (TableLink) -> Void = { _ in }

    var body: some View {
        let s = c.state
        let roll = c.firstRoll
        // Four players: the verdict banner takes the seam's place.
        let gone = (roll?.winner ?? -1) >= 0 && !s.isDuel
        Group {
            if let roll {
                HStack(spacing: 10) {
                    DieKindSwitch(kind: roll.kind, enabled: !roll.busy && !gone) { c.rollKind($0) }
                    Pill(text: s.isDuel ? "Roll both" : "Roll all", height: 42, fill: .white.opacity(0.13), enabled: roll.canRollAll && !gone) { c.rollAll() }
                    RoundIcon(symbol: "xmark", label: "Back to the scoreboard", enabled: !gone) { c.closeRoll() }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.7)))
            } else {
                board(s, gone: gone)
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

    private func board(_ s: ScoreState, gone: Bool) -> some View {
        let link = match?.link
        let line = link == nil ? match?.line : nil
        let ask = gone ? nil : onOpenEvent
        return HStack(spacing: 10) {
            RoundIcon(symbol: "dice", label: "Roll who goes first", tint: RiftColor.you, fill: RiftColor.you.opacity(0.14), enabled: !gone) { c.openRoll() }
            RoundIcon(symbol: "arrow.uturn.backward", label: "Undo last point", enabled: s.canUndo && !gone) { c.undo() }
            if let link {
                ClockBox(link: link, onOpen: ask)
            } else if let line {
                LineBox(line: line, onOpen: ask)
            }
            // Won, lost or restart behind a flag, so it never passes for Undo (Okay, 2026-10-26).
            RoundIcon(symbol: "flag.checkered", label: s.isDuel ? "End or restart this game" : "Restart this game", enabled: !s.gameOver && !gone) { c.openGameMenu() }
            if let link {
                SeamDivider()
                Pill(text: "Report", height: 42, fill: RiftColor.you, ink: .black, enabled: !gone) { onReport(link) }
            } else if match != nil {
                SeamDivider()
                CheckButton(checking: checking, enabled: !gone, action: onCheck)
            }
        }
    }
}

private struct SeamDivider: View {
    var body: some View { Rectangle().fill(.white.opacity(0.16)).frame(width: 1, height: 26) }
}

/// The trophy: asks PlayRiftbound for the pairing now (they go up between rounds); it pulses while it looks.
private struct CheckButton: View {
    let checking: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "trophy")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(RiftColor.you)
                .symbolEffect(.pulse, isActive: checking)
                .frame(width: 42, height: 42)
                .background(RiftColor.you.opacity(0.14), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(PressScale())
        .opacity(enabled ? 1 : 0.35)
        .disabled(!enabled || checking)
        .accessibilityLabel("Look for your PlayRiftbound match")
    }
}

/// The event before round 1, a bye or a reported round; a tap asks to open the event.
private struct LineBox: View {
    let line: EventLine
    let onOpen: (() -> Void)?

    var body: some View {
        Button { onOpen?() } label: {
            VStack(spacing: 0) {
                Text(line.label.uppercased()).caps(10).foregroundStyle(RiftColor.you).lineLimit(1)
                Text(line.text).font(RiftFont.text(14, .semibold)).foregroundStyle(.white).lineLimit(1)
            }
            .frame(minWidth: 72, maxWidth: 140)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .disabled(onOpen == nil)
        .accessibilityLabel("\(line.label), \(line.text). Open the event")
    }
}

/// The pairing: round and table over the round's countdown (the organiser's clock; gold once over), or
/// over the opponent's name before the round clock runs. A tap asks to open the event.
private struct ClockBox: View {
    let link: TableLink
    let onOpen: (() -> Void)?

    var body: some View {
        Group {
            if let end = link.roundEndsAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in face(left: Int(end.timeIntervalSince(context.date))) }
            } else {
                face(left: nil)
            }
        }
        .frame(minWidth: 72, maxWidth: 120)
        .contentShape(Rectangle())
        .onTapGesture { onOpen?() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the event")
    }

    private func face(left: Int?) -> some View {
        let over = (left ?? 0) < 0
        let text = left.map { over ? "+" + clockText(-$0) : clockText($0) } ?? "vs \(link.opponent ?? "?")"
        return VStack(spacing: 0) {
            Text(link.tag.uppercased()).caps(10).foregroundStyle(.white.opacity(0.72)).lineLimit(1)
            Text(text)
                .font(RiftFont.text(left == nil ? 14 : 16, .semibold))
                .monospacedDigit()
                .foregroundStyle(over ? RiftColor.gold : .white)
                .lineLimit(1)
        }
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
