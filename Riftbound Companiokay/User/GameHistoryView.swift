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
    @State private var editing: GameRecord?

    private var records: [GameRecord] {
        switch scope {
        case .all:              return store.records
        case .deck(let id):     return store.records(for: id)
        }
    }

    private var summary: (wins: Int, losses: Int, avgSeconds: Int) {
        var wins = 0
        var losses = 0
        var sum = 0
        for r in records {
            switch r.result {
            case .won:  wins += 1
            case .lost: losses += 1
            }
            sum += r.durationSeconds
        }
        let total = wins + losses
        let avg = total == 0 ? 0 : sum / total
        return (wins, losses, avg)
    }

    private struct TurnOrderStats {
        let firstWins: Int
        let firstLosses: Int
        let secondWins: Int
        let secondLosses: Int
        var firstTotal: Int { firstWins + firstLosses }
        var secondTotal: Int { secondWins + secondLosses }
    }

    private var turnOrderStats: TurnOrderStats {
        var fw = 0, fl = 0, sw = 0, sl = 0
        for r in records {
            switch (r.startedFirst, r.result) {
            case (.some(true), .won):   fw += 1
            case (.some(true), .lost):  fl += 1
            case (.some(false), .won):  sw += 1
            case (.some(false), .lost): sl += 1
            default: break
            }
        }
        return TurnOrderStats(firstWins: fw, firstLosses: fl, secondWins: sw, secondLosses: sl)
    }

    var body: some View {
        List {
            summarySection
            recordsSection
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { record in
            GameRecordEditSheet(record: record)
        }
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
            let t = turnOrderStats
            if t.firstTotal > 0 {
                HStack {
                    Text("Going first")
                    Spacer()
                    Text("\(t.firstWins)–\(t.firstLosses) · \(Int(Double(t.firstWins) / Double(t.firstTotal) * 100))%")
                        .monospacedDigit()
                }
            }
            if t.secondTotal > 0 {
                HStack {
                    Text("Going second")
                    Spacer()
                    Text("\(t.secondWins)–\(t.secondLosses) · \(Int(Double(t.secondWins) / Double(t.secondTotal) * 100))%")
                        .monospacedDigit()
                }
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
                    NavigationLink {
                        GameReviewView(record: record)
                    } label: {
                        GameHistoryRow(record: record)
                    }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                store.delete(record)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editing = record
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
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
