//
//  Seam.swift
//  Riftbound Companiokay
//
//  The pill on the territory line (Android `Seam.kt`): dice, undo, restart; during the roll its die type,
//  Roll both and close. Match mode adds the PlayRiftbound check, the event line (event before round 1,
//  bye, reported round) and, for a pairing, its table and opponent with Start match; a started live match
//  shows its round, table and clock with Report or End. Liquid Glass on iOS 26.
//

import SwiftUI

struct Seam: View {
    @ObservedObject var c: ScoreController
    var match: MatchInfo? = nil
    var checking = false
    var onCheck: () -> Void = {}
    /// The centre leads to the event, after a question: a slip must not take the scoreboard away.
    var onOpenEvent: (() -> Void)? = nil

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
        let live = link?.tag == s.liveTag ? link : nil
        let waiting = link.flatMap { s.isDuel && $0.reportable && $0.tag != s.liveTag ? $0 : nil }
        let line = s.liveTag == nil && waiting == nil ? match?.line : nil
        let ask = gone ? nil : onOpenEvent
        return HStack(spacing: 10) {
            RoundIcon(symbol: "dice", label: "Roll who goes first", tint: RiftColor.you, fill: RiftColor.you.opacity(0.14), enabled: !gone) { c.openRoll() }
            RoundIcon(symbol: "arrow.uturn.backward", label: "Undo last point", enabled: s.canUndo && !gone) { c.undo() }
            if waiting != nil || s.liveTag != nil {
                ClockBox(state: s, waiting: waiting, roundEnd: live?.roundEndsAt, onOpen: ask) { c.toggleClock() }
            } else if let line {
                LineBox(line: line, onOpen: ask)
            }
            // Waiting for Start match, the table and opponent need the room; restart comes back with the match.
            if waiting == nil {
                RoundIcon(symbol: "arrow.counterclockwise", label: "Restart this game", enabled: !s.gameOver && !gone) { c.askRestart() }
            }
            if let waiting {
                SeamDivider()
                Pill(text: "Start match", height: 42, fill: RiftColor.you, ink: .black, enabled: !gone) { c.startLive(waiting) }
            } else if s.isSeries {
                SeamDivider()
                Pill(text: live?.reportable == true ? "Report" : "End", height: 42, fill: .white.opacity(0.13), enabled: !gone) { c.openPicker(ending: true) }
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

/// Before a live match: its table and opponent (Start match beside it starts it). During it: round and
/// table over the round's countdown (the organiser's clock; gold once over), or the match clock where the
/// round has none, which a long press pauses. A tap asks to open the event.
private struct ClockBox: View {
    let state: ScoreState
    let waiting: TableLink?
    let roundEnd: Date?
    let onOpen: (() -> Void)?
    let onClock: () -> Void

    var body: some View {
        let round = waiting == nil ? roundEnd : nil
        let ticking = waiting == nil && (round != nil || state.clock.isRunning)
        let canPause = waiting == nil && round == nil
        Group {
            if ticking {
                TimelineView(.periodic(from: .now, by: 1)) { context in face(at: context.date, round: round) }
            } else {
                face(at: Date(), round: round)
            }
        }
        .frame(minWidth: 72, maxWidth: 132)
        .contentShape(Rectangle())
        .onTapGesture { onOpen?() }
        .onLongPressGesture { if canPause { onClock() } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: state.clock.isRunning ? "Pause the clock" : "Start the clock") { if canPause { onClock() } }
    }

    private func face(at now: Date, round: Date?) -> some View {
        let left = round.map { Int($0.timeIntervalSince(now)) }
        let over = (left ?? 0) < 0
        let text: String = {
            guard let left else { return clockText(state.clock.elapsedSeconds(at: now)) }
            return over ? "+" + clockText(-left) : clockText(left)
        }()
        let paused = waiting == nil && round == nil && !state.clock.isRunning && state.clock.accumulated > 0
        let label: String = {
            if let waiting { return waiting.table.map { "TABLE \($0)" } ?? waiting.tag.uppercased() }
            return paused ? "PAUSED" : (state.liveTag ?? "").uppercased()
        }()
        return VStack(spacing: 0) {
            Text(label).caps(10).foregroundStyle(paused ? RiftColor.gold : .white.opacity(0.72)).lineLimit(1)
            Text(waiting.map { "vs \($0.opponent ?? "?")" } ?? text)
                .font(RiftFont.text(waiting != nil ? 14 : 16, .semibold))
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
