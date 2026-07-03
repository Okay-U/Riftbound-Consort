//
//  CardFilters.swift
//  Riftbound Companiokay
//

import SwiftUI

enum CardSort: String, CaseIterable, Identifiable {
    case set
    case energy
    case type

    var id: String { rawValue }

    var label: String {
        switch self {
        case .set:    return "Set (release order)"
        case .energy: return "Energy"
        case .type:   return "Type"
        }
    }

    var systemImage: String {
        switch self {
        case .set:    return "rectangle.stack"
        case .energy: return "bolt.fill"
        case .type:   return "square.grid.2x2"
        }
    }

    // Returns .orderedAscending / .orderedDescending / .orderedSame
    // for two cards under this sort key alone.
    func compare(_ lhs: Card, _ rhs: Card) -> ComparisonResult {
        switch self {
        case .set:
            let lr = CardFilters.setRank(label: lhs.set?.label)
            let rr = CardFilters.setRank(label: rhs.set?.label)
            if lr != rr { return lr < rr ? .orderedAscending : .orderedDescending }
            return .orderedSame
        case .energy:
            let le = lhs.attributes?.energy ?? Int.max
            let re = rhs.attributes?.energy ?? Int.max
            if le != re { return le < re ? .orderedAscending : .orderedDescending }
            return .orderedSame
        case .type:
            let lt = lhs.classification?.type ?? "~"
            let rt = rhs.classification?.type ?? "~"
            return lt.localizedCaseInsensitiveCompare(rt)
        }
    }
}

struct CardFilters: Equatable {
    var domains: Set<String> = []
    var types: Set<String> = []
    var series: Set<String> = []
    var rarities: Set<String> = []

    var minEnergy: Int = 0
    var maxEnergy: Int = 12
    var minPower: Int = 0
    var maxPower: Int = 12
    var minMight: Int = 0
    var maxMight: Int = 14

    var isActive: Bool {
        !domains.isEmpty || !types.isEmpty || !series.isEmpty || !rarities.isEmpty
            || minEnergy > 0 || maxEnergy < 12
            || minPower > 0 || maxPower < 12
            || minMight > 0 || maxMight < 14
    }

    // MARK: - Known options

    static let knownTypes    = ["Unit", "Spell", "Gear", "Battlefield", "Legend"]
    static let knownRarities = ["Common", "Uncommon", "Epic", "Showcase"]

    // Display name → fragment to match against card.set?.label
    static let knownSeries: [(name: String, fragment: String)] = [
        ("Origins",         "Origins"),
        ("Proving Grounds", "Proving Grounds"),
        ("Spiritforge",     "Spiritforge"),
        ("Unleashed",       "Unleashed")
    ]

    // Token subtype → parent type (lowercase)
    static let tokenParentMap: [String: String] = [
        "recruit": "unit",
        "gold":    "gear"
    ]

    // Returns release-order rank for a card's set label (lower = earlier).
    // Unknown labels sort to the end.
    static func setRank(label: String?) -> Int {
        guard let label else { return Int.max }
        for (idx, entry) in knownSeries.enumerated() {
            if label.localizedCaseInsensitiveContains(entry.fragment) { return idx }
        }
        return Int.max
    }

    // Domain → asset name in Assets.xcassets. Colorless has no rune;
    // a plain white circle is rendered instead.
    static let domainAssets: [String: String] = [
        "body":  "RuneBody",
        "calm":  "RuneCalm",
        "chaos": "RuneChaos",
        "fury":  "RuneFury",
        "mind":  "RuneMind",
        "order": "RuneOrder"
    ]

    // Returns the asset name for a domain rune, or nil for colorless / unknown
    // domains (callers should render a fallback circle).
    static func runeAssetName(for domain: String) -> String? {
        domainAssets[domain.lowercased()]
    }
}
