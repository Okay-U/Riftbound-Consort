//
//  GameHistoryView.swift
//  Riftbound Companiokay
//

import SwiftUI

enum GameHistoryScope {
    case all
    case deck(UUID?)
}

struct GameHistoryView: View {
    let scope: GameHistoryScope
    let title: String
    @EnvironmentObject var store: GameRecordStore

    private var records: [GameRecord] {
        let base: [GameRecord]
        switch scope {
        case .all:              base = store.records
        case .deck(let id):     base = store.records(for: id)
        }
        return base.sorted { $0.date > $1.date }
    }

    private var summary: (wins: Int, losses: Int, avgSeconds: Int) {
        let wins = records.count(where: { $0.result == .won })
        let losses = records.count(where: { $0.result == .lost })
        let total = records.count
        let sum = records.reduce(0) { $0 + $1.durationSeconds }
        let avg = total == 0 ? 0 : sum / total
        return (wins, losses, avg)
    }

    var body: some View {
        List {
            summarySection
            recordsSection
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summarySection: some View {
        let s = summary
        let total = s.wins + s.losses
        let pct = total == 0 ? 0 : Int(Double(s.wins) / Double(total) * 100)
        return Section("Summary") {
            HStack {
                Text("Record")
                Spacer()
                Text("\(s.wins)–\(s.losses)").monospacedDigit()
            }
            HStack {
                Text("Win rate")
                Spacer()
                Text(total == 0 ? "—" : "\(pct)%").monospacedDigit()
            }
            HStack {
                Text("Avg duration")
                Spacer()
                Text(total == 0 ? "—" : Self.formatDuration(s.avgSeconds))
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var recordsSection: some View {
        if records.isEmpty {
            Section {
                Text("No games logged yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else {
            Section("Games") {
                ForEach(records) { record in
                    GameHistoryRow(record: record)
                }
                .onDelete { offsets in
                    offsets.forEach { store.delete(records[$0]) }
                }
            }
        }
    }

    static func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

private struct GameHistoryRow: View {
    let record: GameRecord

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            resultBadge
            VStack(alignment: .leading, spacing: 2) {
                Text(record.opponent.isEmpty ? "Unknown opponent" : "vs \(record.opponent)")
                    .font(.subheadline.weight(.medium))
                Text(Self.dateFormatter.string(from: record.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(GameHistoryView.formatDuration(record.durationSeconds))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var resultBadge: some View {
        Text(record.result == .won ? "W" : "L")
            .font(.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(
                Circle().fill(record.result == .won ? Color.green : Color.red)
            )
    }
}
