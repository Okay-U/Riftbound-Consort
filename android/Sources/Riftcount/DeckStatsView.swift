import SwiftUI

/// Deck stats, ported from iOS. Swift Charts does not exist on Android,
/// so the energy curve is a hand-drawn bar chart.
struct DeckStatsView: View {
    let deck: Decklist
    @Environment(CardStore.self) var cardStore

    private static let domainOrder = ["body", "calm", "chaos", "fury", "mind", "order"]

    private struct EnergyBucket: Identifiable {
        let cost: Int
        let count: Int
        var id: Int { cost }
        var label: String { cost >= 7 ? "7+" : String(cost) }
    }

    var body: some View {
        List {
            energySection
            domainPowerSection
            typeSection
        }
        .navigationTitle("Stats")
    }

    // MARK: - Lookup

    private var cardMap: [String: Card] {
        Dictionary(uniqueKeysWithValues: cardStore.allCards.map { ($0.id, $0) })
    }

    private func mainDeckCards() -> [(card: Card, count: Int)] {
        let map = cardMap
        var out: [(Card, Int)] = []
        for entry in deck.mainDeck {
            if let c = map[entry.cardId] { out.append((c, entry.count)) }
        }
        if let champ = deck.champion, let c = map[champ.cardId] {
            out.append((c, 1))
        }
        return out
    }

    private func powerEligibleCards() -> [(card: Card, count: Int)] {
        let map = cardMap
        var out: [(Card, Int)] = []
        for entry in deck.mainDeck + deck.sideDeck {
            if let c = map[entry.cardId] { out.append((c, entry.count)) }
        }
        if let champ = deck.champion, let c = map[champ.cardId] {
            out.append((c, 1))
        }
        return out
    }

    // MARK: - Energy

    private var energyBuckets: [EnergyBucket] {
        var counts: [Int: Int] = [:]
        for (c, n) in mainDeckCards() {
            guard let e = c.attributes?.energy else { continue }
            let key = min(e, 7)
            counts[key, default: 0] += n
        }
        let maxKey = max(counts.keys.max() ?? 0, 6)
        return (0...maxKey).map { EnergyBucket(cost: $0, count: counts[$0] ?? 0) }
    }

    @ViewBuilder
    private var energySection: some View {
        Section("Energy curve") {
            let buckets = energyBuckets
            let total = buckets.reduce(0) { $0 + $1.count }
            if total == 0 {
                Text("No cards with energy cost.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                energyChart(buckets)
                Text("Total: \(total) cards with cost")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Hand-drawn bar chart standing in for Charts.BarMark.
    private func energyChart(_ buckets: [EnergyBucket]) -> some View {
        let maxCount = max(buckets.map(\.count).max() ?? 1, 1)
        let barMaxHeight: CGFloat = 140

        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(buckets) { b in
                VStack(spacing: 4) {
                    if b.count > 0 {
                        Text("\(b.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(height: max(CGFloat(b.count) / CGFloat(maxCount) * barMaxHeight,
                                           b.count > 0 ? 4 : 1))
                        .frame(maxWidth: .infinity)
                    Text(b.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 190, alignment: .bottom)
        .padding(.vertical, 4)
    }

    // MARK: - Domain power

    private func domainPowerTotals() -> [String: Int] {
        var totals: [String: Int] = [:]
        for (c, n) in powerEligibleCards() {
            guard let p = c.attributes?.power, p > 0 else { continue }
            let domains = c.domains.map { $0.lowercased() }
            guard !domains.isEmpty else { continue }
            for d in domains {
                totals[d, default: 0] += p * n
            }
        }
        return totals
    }

    @ViewBuilder
    private var domainPowerSection: some View {
        Section("Power by domain") {
            let totals = domainPowerTotals()
            let entries = Self.domainOrder
                .map { ($0, totals[$0] ?? 0) }
                .filter { $0.1 > 0 }
            if entries.isEmpty {
                Text("No power-bearing cards in this deck.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries, id: \.0) { domain, value in
                    HStack(spacing: 12) {
                        if let asset = CardFilters.runeAssetName(for: domain) {
                            Image(asset)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                        } else {
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 16, height: 16)
                        }
                        Text(domain.capitalized)
                        Spacer()
                        Text("\(value)")
                    }
                }
            }
        }
    }

    // MARK: - Types

    private func typeCounts() -> (unit: Int, spell: Int, gear: Int) {
        var u = 0, s = 0, g = 0
        for (c, n) in mainDeckCards() {
            switch (c.classification?.type ?? "").lowercased() {
            case "unit": u += n
            case "spell": s += n
            case "gear": g += n
            default: break
            }
        }
        return (u, s, g)
    }

    @ViewBuilder
    private var typeSection: some View {
        Section("Card types (main deck)") {
            let t = typeCounts()
            HStack(spacing: 12) {
                typeChip(label: "Unit", count: t.unit) {
                    Image(systemName: "person.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                typeChip(label: "Spell", count: t.spell) {
                    Image(systemName: "star.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                typeChip(label: "Gear", count: t.gear) {
                    ShieldShape()
                        .fill(Color.secondary)
                        .frame(width: 20, height: 20)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func typeChip(label: String, count: Int, @ViewBuilder icon: () -> some View) -> some View {
        VStack(spacing: 4) {
            icon()
                .frame(height: 24)
            Text("\(count)")
                .font(.title3.weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}
