//
//  CardClassifier.swift
//  Riftbound Companiokay
//

import Foundation

extension Card {
    private var typeLower: String {
        classification?.type?.lowercased() ?? ""
    }

    private var supertypeLower: String {
        classification?.supertype?.lowercased() ?? ""
    }

    private var rarityLower: String {
        classification?.rarity?.lowercased() ?? ""
    }

    var isRareLegend: Bool {
        typeLower == "legend" && rarityLower == "rare"
    }

    var isChampion: Bool {
        supertypeLower == "champion"
    }

    var isBattlefield: Bool {
        typeLower == "battlefield"
    }

    var isRune: Bool {
        typeLower == "rune"
    }

    var domains: [String] {
        classification?.domain ?? []
    }

    /// Cards that can fill the 39-slot main deck for a deck whose legend has
    /// the given domains. Excludes legends, champions, battlefields, and runes.
    /// Allows colorless cards (no/empty domain) plus cards whose every domain
    /// is in the legend's domain set.
    func isMainDeckEligible(legendDomains: Set<String>) -> Bool {
        if isRareLegend || isBattlefield || isRune { return false }
        if typeLower == "legend" { return false }
        let cardDomains = Set(domains.map { $0.lowercased() })
        if cardDomains.isEmpty { return true }
        return cardDomains.isSubset(of: legendDomains)
    }

    /// True if this champion card matches the given legend. Strategy:
    /// 1. Tag intersection (preferred — both share a tag).
    /// 2. Fallback: champion name starts with legend's primary name token
    ///    (e.g. legend "Master Yi" → champion "Master Yi, Wuju Bladesman").
    func matchesLegend(_ legend: Card) -> Bool {
        let myTags = Set((tags ?? []).map { $0.lowercased() })
        let legendTags = Set((legend.tags ?? []).map { $0.lowercased() })
        if !myTags.isEmpty && !legendTags.isEmpty &&
           !myTags.isDisjoint(with: legendTags) {
            return true
        }
        // Fallback — name prefix match.
        let legendKey = Card.primaryNameToken(legend.name).lowercased()
        guard !legendKey.isEmpty else { return false }
        let mine = Card.primaryNameToken(name).lowercased()
        return mine == legendKey
    }

    /// Splits "Master Yi, Wuju Bladesman" → "Master Yi".
    static func primaryNameToken(_ name: String) -> String {
        if let comma = name.firstIndex(of: ",") {
            return String(name[..<comma]).trimmingCharacters(in: .whitespaces)
        }
        return name.trimmingCharacters(in: .whitespaces)
    }

    /// Finds a rune card representing the given domain. Returns the lowest
    /// collector-number match so behaviour is deterministic across reprints.
    static func runeCard(forDomain domain: String, in pool: [Card]) -> Card? {
        let domainKey = domain.lowercased()
        let candidates = pool.filter { card in
            guard card.isRune else { return false }
            return card.domains.contains { $0.lowercased() == domainKey }
        }
        return candidates.min {
            ($0.collectorNumber ?? Int.max) < ($1.collectorNumber ?? Int.max)
        }
    }
}
