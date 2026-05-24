//
//  GameReviewView.swift
//  Riftbound Companiokay
//

import SwiftUI

struct GameReviewView: View {
    let record: GameRecord
    @EnvironmentObject var vm: ScoreboardViewModel

    private let gold = Color(red: 0.98, green: 0.86, blue: 0.35)
    private let defeatRed = Color(red: 0.90, green: 0.28, blue: 0.30)

    private var playerCount: Int {
        let maxSlot = record.events.map(\.slot).max() ?? 1
        return maxSlot >= 2 ? 4 : 2
    }

    private var youSlot: Int { 1 }
    private var oppSlot: Int { 0 }

    private var yourEvents: [ScoreEvent] {
        record.events.filter { $0.slot == youSlot }
    }
    private var oppEvents: [ScoreEvent] {
        record.events.filter { $0.slot == oppSlot }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                if record.events.isEmpty {
                    emptyPlaceholder
                } else {
                    statsRow
                    if playerCount == 2 {
                        pairedTimeline
                    } else {
                        chronologicalTimeline
                    }
                    footerPill
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Game Review")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 8) {
            HStack {
                resultBadge
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.opponent.isEmpty ? "Unknown opponent" : "vs \(record.opponent)")
                        .font(.headline)
                    if let deckName = record.deckName, !deckName.isEmpty {
                        Text(deckName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatDuration(record.durationSeconds))
                        .font(.title3.weight(.semibold).monospacedDigit())
                    Text(Self.dateFormatter.string(from: record.date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if let startedFirst = record.startedFirst {
                HStack {
                    Image(systemName: startedFirst ? "1.circle.fill" : "2.circle.fill")
                        .font(.caption)
                    Text(startedFirst ? "Went first" : "Went second")
                        .font(.caption.weight(.medium))
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    private var resultBadge: some View {
        Text(record.result == .won ? "W" : "L")
            .font(.title3.weight(.heavy).monospacedDigit())
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Circle().fill(record.result == .won ? Color.green : defeatRed))
    }

    // MARK: - Empty

    private var emptyPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Replay not available")
                .font(.headline)
            Text("This game was logged before the timeline feature.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Stats

    private var statsRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                statChip(label: "Your Conquers",
                         value: yourEvents.filter { $0.type == .conquer }.count,
                         color: youColor, icon: "c.circle.fill")
                statChip(label: "Your Holds",
                         value: yourEvents.filter { $0.type == .hold }.count,
                         color: youColor, icon: "h.circle.fill")
            }
            HStack(spacing: 10) {
                statChip(label: "Opp Conquers",
                         value: oppEvents.filter { $0.type == .conquer }.count,
                         color: oppColor, icon: "c.circle.fill")
                statChip(label: "Opp Holds",
                         value: oppEvents.filter { $0.type == .hold }.count,
                         color: oppColor, icon: "h.circle.fill")
            }
        }
    }

    private func statChip(label: String, value: Int, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)")
                    .font(.title3.weight(.bold).monospacedDigit())
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(color.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Paired Timeline (2p)

    private var pairedTimeline: some View {
        let ordered = record.events.sorted { $0.elapsedSeconds < $1.elapsedSeconds }
        let winningEventIdx = winningEventIndex(in: ordered)

        return VStack(spacing: 0) {
            ForEach(Array(ordered.enumerated()), id: \.element.id) { pair in
                let idx = pair.0
                let event = pair.1
                let isWinning = idx == winningEventIdx
                let isYou = event.slot == youSlot
                pairedRow(event: event, isYou: isYou, isWinning: isWinning,
                          cumulative: cumulativeScore(for: event.slot, upTo: idx, in: ordered))
            }
        }
        .padding(.vertical, 8)
    }

    private func pairedRow(event: ScoreEvent, isYou: Bool, isWinning: Bool, cumulative: Int) -> some View {
        HStack(alignment: .center, spacing: 0) {
            if isYou {
                eventCard(event: event, color: youColor, alignment: .trailing,
                          cumulative: cumulative, isWinning: isWinning)
                spine(time: event.elapsedSeconds)
                Color.clear.frame(maxWidth: .infinity)
            } else {
                Color.clear.frame(maxWidth: .infinity)
                spine(time: event.elapsedSeconds)
                eventCard(event: event, color: oppColor, alignment: .leading,
                          cumulative: cumulative, isWinning: isWinning)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func spine(time: Int) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.secondary.opacity(0.25)).frame(width: 1, height: 16)
            Text(formatDuration(time))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(.ultraThinMaterial))
            Rectangle().fill(Color.secondary.opacity(0.25)).frame(width: 1, height: 16)
        }
        .frame(width: 60)
    }

    // MARK: - Chronological (4p)

    private var chronologicalTimeline: some View {
        let ordered = record.events.sorted { $0.elapsedSeconds < $1.elapsedSeconds }
        let winningIdx = winningEventIndex(in: ordered)

        return VStack(spacing: 8) {
            ForEach(Array(ordered.enumerated()), id: \.element.id) { pair in
                let idx = pair.0
                let event = pair.1
                HStack(spacing: 10) {
                    Text(formatDuration(event.elapsedSeconds))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .leading)
                    eventCard(event: event,
                              color: slotColor(event.slot),
                              alignment: .leading,
                              cumulative: cumulativeScore(for: event.slot, upTo: idx, in: ordered),
                              isWinning: idx == winningIdx)
                }
            }
        }
    }

    // MARK: - Event card

    private func eventCard(event: ScoreEvent, color: Color, alignment: HorizontalAlignment,
                           cumulative: Int, isWinning: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: iconFor(event.type))
                .font(.callout.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(labelFor(event.type))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(deltaText(event.delta))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Text("\(cumulative)")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
                .frame(minWidth: 22)
                .padding(6)
                .background(Circle().fill(color.opacity(0.25)))
                .overlay(Circle().stroke(color, lineWidth: 1))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isWinning ? gold : color.opacity(0.4),
                        lineWidth: isWinning ? 2 : 1)
        )
        .shadow(color: isWinning ? gold.opacity(0.4) : .clear, radius: 6)
    }

    // MARK: - Footer

    private var footerPill: some View {
        Text(record.result == .won ? "VICTORY" : "DEFEAT")
            .font(.headline.weight(.heavy)).tracking(2)
            .foregroundStyle(record.result == .won ? gold : defeatRed)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(.thinMaterial)
            )
            .overlay(
                Capsule().stroke((record.result == .won ? gold : defeatRed).opacity(0.6), lineWidth: 1.5)
            )
            .padding(.top, 4)
    }

    // MARK: - Helpers

    private func iconFor(_ type: ScoreEventType) -> String {
        switch type {
        case .conquer: return "c.circle.fill"
        case .hold:    return "h.circle.fill"
        case .manual:  return "minus.circle.fill"
        }
    }

    private func labelFor(_ type: ScoreEventType) -> String {
        switch type {
        case .conquer: return "Conquer"
        case .hold:    return "Hold"
        case .manual:  return "Adjust"
        }
    }

    private func deltaText(_ delta: Int) -> String {
        delta >= 0 ? "+\(delta)" : "\(delta)"
    }

    private func cumulativeScore(for slot: Int, upTo idx: Int, in ordered: [ScoreEvent]) -> Int {
        var sum = 0
        for i in 0...idx where ordered[i].slot == slot {
            sum = max(0, sum + ordered[i].delta)
        }
        return sum
    }

    private func winningEventIndex(in ordered: [ScoreEvent]) -> Int? {
        guard record.result == .won else { return nil }
        var lastIdx: Int? = nil
        for (i, e) in ordered.enumerated() where e.slot == youSlot && e.delta > 0 {
            lastIdx = i
        }
        return lastIdx
    }

    private var youColor: Color {
        let idx = vm.colorIndex(for: youSlot)
        if idx >= 0 { return Palette.colors[idx % Palette.colors.count] }
        return .green
    }

    private var oppColor: Color {
        let idx = vm.colorIndex(for: oppSlot)
        if idx >= 0 { return Palette.colors[idx % Palette.colors.count] }
        return defeatRed
    }

    private func slotColor(_ slot: Int) -> Color {
        let idx = vm.colorIndex(for: slot)
        if idx >= 0 { return Palette.colors[idx % Palette.colors.count] }
        switch slot {
        case 0: return defeatRed
        case 1: return .green
        case 2: return .blue
        case 3: return .orange
        default: return .gray
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
