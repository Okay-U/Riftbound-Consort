import SwiftUI

/// Post-game event timeline, ported from iOS. Letter glyphs replace the
/// unmapped c/h/minus circle symbols; tile colors read straight from the
/// persisted colorIdx_ keys instead of the scoreboard view model.
struct GameReviewView: View {
    let record: GameRecord

    private let gold = Color(red: 0.98, green: 0.86, blue: 0.35)
    private let defeatRed = Color(red: 0.90, green: 0.28, blue: 0.30)
    private let cardFill = Color.secondary.opacity(0.15)

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
                        .font(.title3.weight(.semibold))
                    Text(record.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if let startedFirst = record.startedFirst {
                HStack {
                    letterGlyph(startedFirst ? "1" : "2", color: .secondary, size: 18)
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
                .fill(cardFill)
        )
    }

    private var resultBadge: some View {
        Text(record.result == .won ? "W" : "L")
            .font(.title3.weight(.heavy))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Circle().fill(record.result == .won ? Color.green : defeatRed))
    }

    // MARK: - Empty

    private var emptyPlaceholder: some View {
        VStack(spacing: 8) {
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
                         color: youColor, letter: "C")
                statChip(label: "Your Holds",
                         value: yourEvents.filter { $0.type == .hold }.count,
                         color: youColor, letter: "H")
            }
            HStack(spacing: 10) {
                statChip(label: "Opp Conquers",
                         value: oppEvents.filter { $0.type == .conquer }.count,
                         color: oppColor, letter: "C")
                statChip(label: "Opp Holds",
                         value: oppEvents.filter { $0.type == .hold }.count,
                         color: oppColor, letter: "H")
            }
        }
    }

    private func statChip(label: String, value: Int, color: Color, letter: String) -> some View {
        HStack(spacing: 8) {
            letterGlyph(letter, color: color, size: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)")
                    .font(.title3.weight(.bold))
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
                .fill(cardFill)
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

        return VStack(spacing: 10) {
            HStack {
                Text("YOU")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(youColor)
                    .frame(maxWidth: .infinity)
                Color.clear.frame(width: 52, height: 1)
                Text(record.opponent.isEmpty ? "OPPONENT" : record.opponent.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(oppColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }

            ForEach(Array(ordered.enumerated()), id: \.element.id) { pair in
                let idx = pair.0
                let event = pair.1
                let isWinning = idx == winningEventIdx
                let isYou = event.slot == youSlot
                pairedRow(event: event, isYou: isYou, isWinning: isWinning,
                          cumulative: cumulativeScore(for: event.slot, upTo: idx, in: ordered))
            }
        }
        .padding(.vertical, 4)
    }

    /// Chat-bubble row: two equal flexible halves around a fixed time pill,
    /// so both sides stay symmetric regardless of platform width weighting.
    private func pairedRow(event: ScoreEvent, isYou: Bool, isWinning: Bool, cumulative: Int) -> some View {
        HStack(alignment: .center, spacing: 6) {
            ZStack {
                Color.clear.frame(height: 1)
                if isYou {
                    eventCard(event: event, color: youColor,
                              cumulative: cumulative, isWinning: isWinning)
                }
            }
            .frame(maxWidth: .infinity)

            Text(formatDuration(event.elapsedSeconds))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 52)

            ZStack {
                Color.clear.frame(height: 1)
                if !isYou {
                    eventCard(event: event, color: oppColor,
                              cumulative: cumulative, isWinning: isWinning)
                }
            }
            .frame(maxWidth: .infinity)
        }
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
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .leading)
                    eventCard(event: event,
                              color: slotColor(event.slot),
                              cumulative: cumulativeScore(for: event.slot, upTo: idx, in: ordered),
                              isWinning: idx == winningIdx)
                }
            }
        }
    }

    // MARK: - Event card

    private func eventCard(event: ScoreEvent, color: Color,
                           cumulative: Int, isWinning: Bool) -> some View {
        HStack(spacing: 8) {
            letterGlyph(letterFor(event.type), color: color, size: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(labelFor(event.type))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(deltaText(event.delta))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Text("\(cumulative)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(color.opacity(0.25)))
                .overlay(Circle().stroke(color, lineWidth: 1))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isWinning ? gold : color.opacity(0.4),
                        lineWidth: isWinning ? 2 : 1)
        )
        .shadow(color: isWinning ? gold.opacity(0.4) : Color.clear, radius: 6)
    }

    // MARK: - Footer

    private var footerPill: some View {
        Text(record.result == .won ? "VICTORY" : "DEFEAT")
            .font(.headline.weight(.heavy))
            .foregroundStyle(record.result == .won ? gold : defeatRed)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(cardFill)
            )
            .overlay(
                Capsule().stroke((record.result == .won ? gold : defeatRed).opacity(0.6), lineWidth: 1.5)
            )
            .padding(.top, 4)
    }

    // MARK: - Helpers

    private func letterGlyph(_ letter: String, color: Color, size: CGFloat) -> some View {
        Text(letter)
            .font(.system(size: size * 0.55, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .overlay(Circle().stroke(color.opacity(0.7), lineWidth: 1.5))
    }

    private func letterFor(_ type: ScoreEventType) -> String {
        switch type {
        case .conquer: return "C"
        case .hold: return "H"
        case .manual: return "−"
        }
    }

    private func labelFor(_ type: ScoreEventType) -> String {
        switch type {
        case .conquer: return "Conquer"
        case .hold: return "Hold"
        case .manual: return "Adjust"
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

    private func storedColor(slot: Int) -> Color? {
        let idx = UserDefaults.standard.object(forKey: "colorIdx_\(slot)") as? Int ?? -1
        guard idx >= 0 else { return nil }
        return Palette.entry(for: idx % Palette.colors.count)?.color
    }

    private var youColor: Color {
        storedColor(slot: youSlot) ?? .green
    }

    private var oppColor: Color {
        storedColor(slot: oppSlot) ?? defeatRed
    }

    private func slotColor(_ slot: Int) -> Color {
        if let c = storedColor(slot: slot) { return c }
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
}
