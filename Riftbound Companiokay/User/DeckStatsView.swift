//
//  DeckStatsView.swift
//  Riftbound Companiokay
//

import SwiftUI
import Charts

struct DeckStatsView: View {
    let deck: Decklist
    @EnvironmentObject var cardStore: CardStore

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
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Lookup

    private var cardMap: [String: Card] {
        Dictionary(uniqueKeysWithValues: cardStore.allCards.map { ($0.id, $0) })
    }

    private func card(_ id: String, in map: [String: Card]) -> Card? {
        map[id]
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
                Chart(buckets) { b in
                    BarMark(
                        x: .value("Cost", b.label),
                        y: .value("Count", b.count)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .annotation(position: .top) {
                        if b.count > 0 {
                            Text("\(b.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 200)
                .padding(.vertical, 4)
                Text("Total: \(total) cards with cost")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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

    private func color(forDomain domain: String) -> Color {
        switch domain {
        case "body":  return .green
        case "calm":  return .blue
        case "chaos": return .purple
        case "fury":  return .red
        case "mind":  return .yellow
        case "order": return .teal
        default:      return .gray
        }
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
                                .fill(color(forDomain: domain))
                                .frame(width: 16, height: 16)
                        }
                        Text(domain.capitalized)
                        Spacer()
                        Text("\(value)")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.primary)
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
            case "unit":  u += n
            case "spell": s += n
            case "gear":  g += n
            default:      break
            }
        }
        return (u, s, g)
    }

    @ViewBuilder
    private var typeSection: some View {
        Section("Card types (main deck)") {
            let t = typeCounts()
            HStack(spacing: 12) {
                typeChip(label: "Unit", count: t.unit, system: "person.fill")
                typeChip(label: "Spell", count: t.spell, system: "sparkles")
                typeChip(label: "Gear", count: t.gear, system: "shield.fill")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func typeChip(label: String, count: Int, system: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: system)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.title3.monospacedDigit().weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}
