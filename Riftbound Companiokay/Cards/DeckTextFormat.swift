//
//  DeckTextFormat.swift
//  Riftbound Companiokay
//

import Foundation

/// Plain-text decklist format compatible with common Riftbound deckbuilders.
/// Sections: Legend, Champion, MainDeck, Battlefields, Runes, Sideboard.
enum DeckTextFormat {

    // MARK: - Parsed result

    struct ParsedDeck {
        var name: String
        var legend: Card?
        var champion: Card?
        var battlefields: [Card]
        var mainDeck: [(card: Card, count: Int)]
        var sideDeck: [(card: Card, count: Int)]
        /// Domain (lowercased) → count.
        var runeCounts: [String: Int]
        /// Lines that could not be matched to any card.
        var unresolvedLines: [String]
    }

    private enum Section {
        case none, legend, champion, main, battlefields, runes, side
    }

    // MARK: - Export

    static func export(deck: Decklist, cardPool: [Card]) -> String {
        var out: [String] = []

        if let legend = deck.legend {
            out.append("Legend:")
            out.append("1 \(canonicalName(for: legend, pool: cardPool))")
            out.append("")
        }
        if let champion = deck.champion {
            out.append("Champion:")
            out.append("1 \(canonicalName(for: champion, pool: cardPool))")
            out.append("")
        }
        if !deck.mainDeck.isEmpty {
            out.append("MainDeck:")
            for (name, count) in aggregate(deck.mainDeck, pool: cardPool) {
                out.append("\(count) \(name)")
            }
            out.append("")
        }
        if !deck.battlefields.isEmpty {
            out.append("Battlefields:")
            for (name, count) in aggregate(deck.battlefields, pool: cardPool) {
                out.append("\(count) \(name)")
            }
            out.append("")
        }
        if !deck.runes.isEmpty {
            out.append("Runes:")
            for (name, count) in aggregate(deck.runes, pool: cardPool) {
                out.append("\(count) \(name)")
            }
            out.append("")
        }
        if !deck.sideDeck.isEmpty {
            out.append("Sideboard:")
            for (name, count) in aggregate(deck.sideDeck, pool: cardPool) {
                out.append("\(count) \(name)")
            }
            out.append("")
        }

        return out.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Parse

    static func parse(_ text: String,
                      cardPool: [Card],
                      defaultName: String = "Imported Deck") -> ParsedDeck {

        var legend: Card?
        var champion: Card?
        var battlefields: [Card] = []
        var mainDeck: [(Card, Int)] = []
        var sideDeck: [(Card, Int)] = []
        var runeCounts: [String: Int] = [:]
        var unresolved: [String] = []

        var section: Section = .none

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if let s = matchSectionHeader(line) {
                section = s
                continue
            }

            guard let (count, name) = parseEntryLine(line) else {
                unresolved.append(raw)
                continue
            }

            switch section {
            case .none:
                unresolved.append(raw)
            case .legend:
                if let c = matchCard(name: name, in: cardPool, section: .legend) {
                    legend = c
                } else { unresolved.append(raw) }
            case .champion:
                if let c = matchCard(name: name, in: cardPool, section: .champion) {
                    champion = c
                } else { unresolved.append(raw) }
            case .main:
                if let c = matchCard(name: name, in: cardPool, section: .main) {
                    mainDeck.append((c, count))
                } else { unresolved.append(raw) }
            case .battlefields:
                if let c = matchCard(name: name, in: cardPool, section: .battlefields) {
                    for _ in 0..<count { battlefields.append(c) }
                } else { unresolved.append(raw) }
            case .runes:
                if let domain = parseRuneDomain(name) {
                    runeCounts[domain, default: 0] += count
                } else { unresolved.append(raw) }
            case .side:
                if let c = matchCard(name: name, in: cardPool, section: .side) {
                    sideDeck.append((c, count))
                } else { unresolved.append(raw) }
            }
        }

        return ParsedDeck(
            name: defaultName,
            legend: legend,
            champion: champion,
            battlefields: battlefields,
            mainDeck: mainDeck,
            sideDeck: sideDeck,
            runeCounts: runeCounts,
            unresolvedLines: unresolved
        )
    }

    // MARK: - Header & line parsing

    private static func matchSectionHeader(_ raw: String) -> Section? {
        let s = raw.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ":", with: "")
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        switch s {
        case "legend":                        return .legend
        case "champion", "champions":         return .champion
        case "maindeck", "main":              return .main
        case "battlefields", "battlefield":   return .battlefields
        case "runes", "rune":                 return .runes
        case "sideboard", "sidedeck", "side": return .side
        default:                              return nil
        }
    }

    private static func parseEntryLine(_ line: String) -> (Int, String)? {
        // "3 Card Name"  or  "3x Card Name"
        let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        let head = parts[0].lowercased().replacingOccurrences(of: "x", with: "")
        if let n = Int(head), n > 0 {
            return (n, parts[1].trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    private static func matchCard(name: String,
                                  in pool: [Card],
                                  section: Section) -> Card? {
        let needle = normaliseName(name)
        let needlePrimary = primaryToken(needle)

        let typeFiltered = pool.filter { matchesSection($0, section: section) }
        let scope = typeFiltered.isEmpty ? pool : typeFiltered

        // 1. Exact match on name or cleanName.
        let exact = scope.filter { card in
            normaliseName(card.name) == needle
                || normaliseName(card.metadata?.cleanName ?? "") == needle
        }
        if let pick = pickPreferred(exact) { return pick }

        // 2. Primary-token match (handles short cleanName vs subtitle name).
        let token = scope.filter { card in
            let n  = primaryToken(normaliseName(card.name))
            let cn = primaryToken(normaliseName(card.metadata?.cleanName ?? ""))
            return n == needlePrimary || cn == needlePrimary
        }
        if let pick = pickPreferred(token) { return pick }

        // 3. Substring fallback within scope.
        let contains = scope.filter { card in
            let n  = normaliseName(card.name)
            let cn = normaliseName(card.metadata?.cleanName ?? "")
            return n.contains(needle) || cn.contains(needle)
                || needle.contains(n) || (cn.isEmpty == false && needle.contains(cn))
        }
        return pickPreferred(contains)
    }

    private static func matchesSection(_ card: Card, section: Section) -> Bool {
        let type = card.classification?.type?.lowercased() ?? ""
        switch section {
        case .legend:       return type == "legend"
        case .champion:     return card.isChampion
        case .battlefields: return type == "battlefield"
        case .runes:        return type == "rune"
        case .main, .side:
            return type != "legend" && type != "battlefield" && type != "rune"
        case .none:         return true
        }
    }

    private static func primaryToken(_ s: String) -> String {
        if let comma = s.firstIndex(of: ",") {
            return String(s[..<comma]).trimmingCharacters(in: .whitespaces)
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    private static func pickPreferred(_ matches: [Card]) -> Card? {
        guard !matches.isEmpty else { return nil }
        return matches.min { a, b in
            (a.collectorNumber ?? Int.max) < (b.collectorNumber ?? Int.max)
        }
    }

    private static func normaliseName(_ s: String) -> String {
        var t = s.lowercased()
        // Strip parenthesised qualifiers like "(Showcase)".
        while let r = t.range(of: #"\s*\([^)]*\)"#, options: .regularExpression) {
            t.removeSubrange(r)
        }
        // Drop punctuation so "Yone, Blademaster" matches "Yone Blademaster"
        // and "Zhonya's" matches "Zhonyas". Keep alphanumerics + whitespace.
        let scalars = t.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar) || scalar == " " || scalar == "\t"
        }
        let stripped = String(String.UnicodeScalarView(scalars))
        let parts = stripped.split(whereSeparator: { $0.isWhitespace })
        return parts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    private static func parseRuneDomain(_ name: String) -> String? {
        var t = normaliseName(name)
        if t.hasSuffix(" rune") { t.removeLast(" rune".count) }
        if t.hasPrefix("rune of ") { t.removeFirst("rune of ".count) }
        let trimmed = t.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func canonicalName(for entry: DecklistEntry,
                                      pool: [Card]) -> String {
        if let card = pool.first(where: { $0.id == entry.cardId }) {
            return exportDisplayName(for: card)
        }
        return stripVariantSuffix(entry.cardName)
    }

    /// Produces the canonical, deckbuilder-compatible name for a card.
    /// Preserves commas, strips parenthesised qualifiers and trailing rarity
    /// or variant suffixes (Metal, Signature, Promo, Foil, Showcase, etc.).
    private static func exportDisplayName(for card: Card) -> String {
        stripVariantSuffix(card.name)
    }

    private static func stripVariantSuffix(_ raw: String) -> String {
        var t = raw
        // Drop "(Metal)", "(Showcase)" and similar parenthesised qualifiers.
        while let r = t.range(of: #"\s*\([^)]*\)"#, options: .regularExpression) {
            t.removeSubrange(r)
        }
        // Riftcodex stores subtitled cards as "Name - Subtitle". Most other
        // deckbuilders use "Name, Subtitle" — convert so exports are portable.
        t = t.replacingOccurrences(of: " - ", with: ", ")
        // Drop trailing variant words (case-insensitive). Repeats so chained
        // suffixes like "Foo Metal Signature" all strip.
        let suffixes = [
            " metal", " signature", " promo", " foil",
            " showcase", " alternate art", " alt art",
            " overnumbered", " gold", " silver", " bronze"
        ]
        var changed = true
        while changed {
            changed = false
            let lower = t.lowercased()
            for sfx in suffixes where lower.hasSuffix(sfx) {
                t = String(t.dropLast(sfx.count))
                changed = true
                break
            }
        }
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// Aggregates entries by canonical (clean) name so variant printings of
    /// the same card collapse into a single line on export.
    private static func aggregate(_ entries: [DecklistEntry],
                                  pool: [Card]) -> [(name: String, count: Int)] {
        var byName: [String: Int] = [:]
        var order: [String] = []
        for entry in entries {
            let n = canonicalName(for: entry, pool: pool)
            if byName[n] == nil { order.append(n) }
            byName[n, default: 0] += entry.count
        }
        return order.map { ($0, byName[$0] ?? 0) }
    }
}
