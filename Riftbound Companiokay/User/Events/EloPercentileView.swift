//
//  EloPercentileView.swift
//  Riftbound Companiokay
//
//  "Where you rank" card for the Profile: places the player's current ELO on the
//  season-wide distribution (eloshowdown /stats/elo-distribution) — a "Top X%"
//  badge plus a histogram with the player's position marked. Renders nothing
//  until the distribution loads (or if it fails).
//

import SwiftUI
import Charts

struct EloPercentileView: View {
    let currentElo: Int
    var service: any EloShowdownService = EloCache.shared

    @State private var phase: Phase = .idle

    enum Phase { case idle, loading, loaded(EloDistribution), hidden }

    var body: some View {
        Group {
            if case .loaded(let dist) = phase { card(dist) }
        }
        .task { await load() }
    }

    private func card(_ dist: EloDistribution) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("chart.bar.fill", "Where you rank") {
                if let top = dist.topPercent(for: currentElo) {
                    Text("Top \(formatTop(top))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(EventsTheme.green)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(EventsTheme.greenSoft, in: Capsule())
                }
            }
            Text("Your ELO \(currentElo) against every ranked player this season.")
                .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)

            Chart {
                ForEach(dist.buckets) { bucket in
                    BarMark(
                        x: .value("ELO", bucket.mid),
                        y: .value("Players", bucket.count)
                    )
                    .foregroundStyle(barColor(bucket))
                }
                RuleMark(x: .value("You", currentElo))
                    .foregroundStyle(EventsTheme.green)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .annotation(position: .top, alignment: .center, spacing: 2) {
                        Text("You")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(EventsTheme.green)
                    }
            }
            .chartYAxis(.hidden)
            .frame(height: 150)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .eventsCard(radius: 18)
    }

    private func barColor(_ bucket: EloBucket) -> Color {
        (currentElo >= bucket.bucketMin && currentElo < bucket.bucketMax)
            ? EventsTheme.green
            : EventsTheme.textTertiary.opacity(0.5)
    }

    private func formatTop(_ percent: Double) -> String {
        percent < 10 ? String(format: "%.1f%%", percent) : "\(Int(percent.rounded()))%"
    }

    @MainActor
    private func load() async {
        guard case .idle = phase else { return }
        phase = .loading
        guard let dist = try? await service.eloDistribution(), !dist.buckets.isEmpty else {
            phase = .hidden
            return
        }
        phase = .loaded(dist)
    }
}
