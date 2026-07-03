import SwiftUI

/// "Where you rank" card for the Profile, ported from iOS: places the player's
/// current ELO on the season-wide distribution — a "Top X%" badge plus a
/// histogram with the player's position marked. Swift Charts is not bridged,
/// so the histogram is drawn (equal-width bars + dashed rule). Renders nothing
/// until the distribution loads (or if it fails).
struct EloPercentileView: View {
    let currentElo: Int
    var service: any EloShowdownService = EloCache.shared

    @State var phase: Phase = .idle

    enum Phase { case idle, loading, loaded(EloDistribution), hidden }

    private let chartHeight: CGFloat = 150

    var body: some View {
        Group {
            if case .loaded(let dist) = phase { card(dist) }
        }
        .task { await load() }
    }

    private func card(_ dist: EloDistribution) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            EventsSectionHeader("Where you rank") {
                MiniBarsGlyph()
            } trailing: {
                if let top = dist.topPercent(for: currentElo) {
                    Text("Top \(formatTop(top))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(EventsTheme.green)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Capsule().fill(EventsTheme.greenSoft))
                }
            }
            Text("Your ELO \(currentElo) against every ranked player this season.")
                .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)

            histogram(dist)
                .frame(height: chartHeight + 18)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .eventsCard(radius: 18)
    }

    /// Drawn histogram: equal-width bars bottom-aligned, "You" rule at the
    /// player's position along the ELO domain.
    private func histogram(_ dist: EloDistribution) -> some View {
        let buckets = dist.buckets.sorted { $0.bucketMin < $1.bucketMin }
        let maxCount = max(buckets.map(\.count).max() ?? 1, 1)
        let domainMin = buckets.first?.bucketMin ?? 0
        let domainMax = max(buckets.last?.bucketMax ?? 1, domainMin + 1)
        let frac = CGFloat(min(max(Double(currentElo - domainMin) / Double(domainMax - domainMin), 0), 1))

        return GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(buckets) { bucket in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor(bucket))
                            .frame(height: max(CGFloat(bucket.count) / CGFloat(maxCount) * chartHeight, 2))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: chartHeight, alignment: .bottom)

                // "You" marker: label + dashed rule at the ELO position.
                VStack(spacing: 2) {
                    Text("You")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(EventsTheme.green)
                    VerticalDashedLine()
                        .stroke(EventsTheme.green, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .frame(width: 1.5, height: chartHeight)
                }
                .frame(width: 40)
                .offset(x: min(max(geo.size.width * frac - 20, 0), geo.size.width - 40))
            }
        }
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

/// Full-height vertical dashed rule.
struct VerticalDashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
    }
}

/// Tiny drawn bar-chart glyph for section headers (chart.* symbols are not in
/// SkipUI's map).
struct MiniBarsGlyph: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            RoundedRectangle(cornerRadius: 1).frame(width: 3.5, height: 7)
            RoundedRectangle(cornerRadius: 1).frame(width: 3.5, height: 12)
            RoundedRectangle(cornerRadius: 1).frame(width: 3.5, height: 9)
        }
        .foregroundStyle(EventsTheme.green)
    }
}
