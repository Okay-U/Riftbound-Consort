//
//  RiftboundWidgetsLiveActivity.swift
//  RiftboundWidgets
//

import ActivityKit
import AppIntents
import WidgetKit
import SwiftUI

struct RiftboundWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GameActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DeckLabel(name: context.state.myDeckName ?? "You",
                              tint: .blue)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    DeckLabel(name: context.state.oppDeckName ?? "Opponent",
                              tint: .red,
                              alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    if context.state.scores.count == 2 {
                        HStack(spacing: 10) {
                            ScoreStepper(slot: 1,
                                         score: context.state.scores[1],
                                         target: context.attributes.targetScore,
                                         tint: .blue)
                            ScoreStepper(slot: 0,
                                         score: context.state.scores[0],
                                         target: context.attributes.targetScore,
                                         tint: .red)
                        }
                    } else {
                        ScoreLine(scores: context.state.scores,
                                  target: context.attributes.targetScore)
                            .font(.title.bold())
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TimerLabel(state: context.state)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } compactLeading: {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
            } compactTrailing: {
                ScoreLine(scores: youFirst(context.state.scores),
                          target: context.attributes.targetScore)
                    .font(.caption.monospacedDigit().bold())
            } minimal: {
                ScoreLine(scores: youFirst(context.state.scores),
                          target: context.attributes.targetScore)
                    .font(.caption2.monospacedDigit().bold())
            }
            .keylineTint(.yellow)
        }
    }

    private func youFirst(_ scores: [Int]) -> [Int] {
        scores.count == 2 ? [scores[1], scores[0]] : scores
    }
}

// MARK: - Lock screen view

private struct LockScreenView: View {
    let attributes: GameActivityAttributes
    let state: GameActivityAttributes.State

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                DeckLabel(name: state.myDeckName ?? "You", tint: .blue)
                Spacer()
                DeckLabel(name: state.oppDeckName ?? "Opponent",
                          tint: .red, alignment: .trailing)
            }

            if state.scores.count == 2 {
                HStack(spacing: 14) {
                    ScoreStepper(slot: 1,
                                 score: state.scores[1],
                                 target: attributes.targetScore,
                                 tint: .blue)
                    ScoreStepper(slot: 0,
                                 score: state.scores[0],
                                 target: attributes.targetScore,
                                 tint: .red)
                }
            } else {
                HStack(spacing: 12) {
                    Spacer()
                    ScoreLine(scores: state.scores, target: attributes.targetScore)
                        .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                    Spacer()
                }
            }

            HStack {
                Image(systemName: state.isRunning ? "timer" : "pause.circle")
                    .foregroundStyle(.secondary)
                TimerLabel(state: state)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("to \(attributes.targetScore)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct ScoreStepper: View {
    let slot: Int
    let score: Int
    let target: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Button(intent: ScoreIntent(slot: slot, delta: -1)) {
                Image(systemName: "minus")
                    .font(.headline)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .background(tint.opacity(0.25), in: Circle())

            Text("\(score)")
                .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(score >= target ? .yellow : .primary)
                .frame(minWidth: 36)

            Button(intent: ScoreIntent(slot: slot, delta: +1)) {
                Image(systemName: "plus")
                    .font(.headline)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .background(tint.opacity(0.25), in: Circle())
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Pieces

private struct ScoreLine: View {
    let scores: [Int]
    let target: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(scores.enumerated()), id: \.offset) { i, s in
                Text("\(s)")
                    .foregroundStyle(s >= target ? .yellow : .primary)
                if i < scores.count - 1 {
                    Text("–").foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct DeckLabel: View {
    let name: String
    let tint: Color
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(tint).frame(width: 8, height: 8)
            Text(name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity,
               alignment: alignment == .leading ? .leading : .trailing)
    }
}

private struct TimerLabel: View {
    let state: GameActivityAttributes.State

    var body: some View {
        if let start = state.effectiveStart {
            Text(timerInterval: start...Date.distantFuture,
                 countsDown: false,
                 showsHours: true)
        } else {
            Text(format(state.pausedElapsed))
        }
    }

    private func format(_ t: TimeInterval) -> String {
        let s = Int(t)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }
}

// MARK: - Preview

extension GameActivityAttributes {
    fileprivate static var preview: GameActivityAttributes {
        GameActivityAttributes(playerCount: 2, targetScore: 8)
    }
}

extension GameActivityAttributes.State {
    fileprivate static var running: Self {
        .init(scores: [3, 2],
              effectiveStart: Date().addingTimeInterval(-127),
              pausedElapsed: 127,
              myDeckName: "Yasuo Aggro",
              oppDeckName: "Lux Control")
    }
    fileprivate static var paused: Self {
        .init(scores: [5, 4],
              effectiveStart: nil,
              pausedElapsed: 543,
              myDeckName: "Yasuo Aggro",
              oppDeckName: "Lux Control")
    }
}

#Preview("Lock screen", as: .content, using: GameActivityAttributes.preview) {
    RiftboundWidgetsLiveActivity()
} contentStates: {
    GameActivityAttributes.State.running
    GameActivityAttributes.State.paused
}
