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

    /// A Signature card (Core Rules 103.2.d: at most three, all of the legend's champion). Not the signed
    /// "(Signature)" printing of a legend or champion, which the feed marks in metadata.signature.
    var isSignature: Bool {
        supertypeLower == "signature"
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

    /// True if this card carries the legend's champion tag (Core Rules 103.2): the champion's name, "Jinx" for
    /// "Jinx - Loose Cannon". A tag the legend shares with others is not one: Kennen's "Yordle" offered every
    /// Yordle champion.
    func matchesLegend(_ legend: Card) -> Bool {
        let champion = Card.championName(legend.name)
        guard !champion.isEmpty else { return false }
        if Card.championName(name).caseInsensitiveCompare(champion) == .orderedSame { return true }
        return (tags ?? []).contains { $0.caseInsensitiveCompare(champion) == .orderedSame }
    }

    /// A Signature card only goes with its own champion's legend (Core Rules 103.2.d); without a legend yet, any.
    func signatureFits(legend: Card?) -> Bool {
        guard isSignature, let legend else { return true }
        return matchesLegend(legend)
    }

    /// "Jinx - Loose Cannon" → "Jinx", "Master Yi, Wuju Bladesman" → "Master Yi".
    static func championName(_ name: String) -> String {
        let beforeDash = name.components(separatedBy: " - ").first ?? name
        let beforeComma = beforeDash.components(separatedBy: ",").first ?? beforeDash
        return beforeComma.trimmingCharacters(in: .whitespaces)
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
