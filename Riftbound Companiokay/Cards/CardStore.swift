//
//  CardStore.swift
//  Riftbound Companiokay
//

import Foundation
internal import Combine

@MainActor
final class CardStore: ObservableObject {
    @Published private(set) var allCards: [Card] = []
    @Published private(set) var legendNames: [String] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String? = nil

    var availableDomains: [String] {
        let all = allCards.compactMap { $0.classification?.domain }.flatMap { $0 }
        return Array(Set(all)).sorted()
    }

    /// Baseline types plus any new type actually present in the loaded DB
    /// (e.g. Vendetta's Unit-Gear), so future sets filter without an app
    /// update. Token subtypes (tokenParentMap keys) stay hidden — they're
    /// reachable through their parent type.
    var availableTypes: [String] {
        dynamicOptions(baseline: CardFilters.knownTypes,
                       values: allCards.compactMap { $0.classification?.type },
                       excluding: Set(CardFilters.tokenParentMap.keys))
    }

    /// Baseline rarities plus any new rarity present in the loaded DB.
    /// "Rare" is deliberately not a baseline: it marks legends, which have
    /// their own type chip — but if a future set puts it on other cards it
    /// appears here automatically.
    var availableRarities: [String] {
        dynamicOptions(baseline: CardFilters.knownRarities,
                       values: allCards.compactMap { $0.classification?.rarity },
                       excluding: ["rare"])
    }

    /// Baseline order first, then unseen values (case-insensitive dedupe)
    /// sorted alphabetically at the end.
    private func dynamicOptions(baseline: [String],
                                values: [String],
                                excluding: Set<String>) -> [String] {
        var seen = Set(baseline.map { $0.lowercased() })
        var extras: Set<String> = []
        for value in values {
            let key = value.lowercased()
            guard !seen.contains(key), !excluding.contains(key) else { continue }
            seen.insert(key)
            extras.insert(value)
        }
        return baseline + extras.sorted()
    }

    private let repo = RiftcodexCardRepository()
    private var loadTask: Task<Void, Never>?

    private static func computeLegendNames(from cards: [Card]) -> [String] {
        var names: Set<String> = []
        for card in cards {
            let type = card.classification?.type?.lowercased()
            let rarity = card.classification?.rarity?.lowercased()
            if type == "legend" && rarity == "rare" {
                names.insert(card.name)
            }
        }
        return names.sorted()
    }

    func loadIfNeeded() {
        guard allCards.isEmpty, !isLoading else { return }
        load()
    }

    func load() {
        loadTask?.cancel()
        loadTask = Task {
            isLoading = true
            loadError = nil
            var accumulated: [Card] = []
            var page = 1
            do {
                while true {
                    try Task.checkCancellation()
                    let result = try await repo.cards(page: page)
                    accumulated.append(contentsOf: result.items)
                    if accumulated.count >= result.total || result.items.isEmpty { break }
                    page += 1
                }
                allCards = accumulated
                legendNames = Self.computeLegendNames(from: accumulated)
            } catch is CancellationError {
                // ignored
            } catch {
                loadError = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - Filtering

    func filtered(query: String,
                  filters: CardFilters,
                  primarySort: CardSort = .set,
                  secondarySort: CardSort? = .energy) -> [Card] {
        let matched = allCards.filter { card in
            matchesQuery(card, query: query)
                && matchesDomains(card, selected: filters.domains)
                && matchesTypes(card, selected: filters.types)
                && matchesSeries(card, selected: filters.series)
                && matchesRarities(card, selected: filters.rarities)
                && matchesCost(card, filters: filters)
        }
        return sorted(matched, primary: primarySort, secondary: secondarySort)
    }

    private func sorted(_ cards: [Card],
                        primary: CardSort,
                        secondary: CardSort?) -> [Card] {
        // If secondary equals primary, treat as no secondary.
        let sec = (secondary == primary) ? nil : secondary

        return cards.sorted { lhs, rhs in
            let p = primary.compare(lhs, rhs)
            if p != .orderedSame { return p == .orderedAscending }
            if let sec {
                let s = sec.compare(lhs, rhs)
                if s != .orderedSame { return s == .orderedAscending }
            }
            // Stable tiebreaker: collector number, then name.
            let ln = lhs.collectorNumber ?? Int.max
            let rn = rhs.collectorNumber ?? Int.max
            if ln != rn { return ln < rn }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func matchesQuery(_ card: Card, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty || card.name.localizedCaseInsensitiveContains(q)
    }

    private func matchesDomains(_ card: Card, selected: Set<String>) -> Bool {
        guard !selected.isEmpty else { return true }
        let cardDomains = Set(card.classification?.domain ?? [])
        return !cardDomains.isDisjoint(with: selected)
    }

    private func matchesTypes(_ card: Card, selected: Set<String>) -> Bool {
        guard !selected.isEmpty else { return true }
        let cardType = card.classification?.type?.lowercased() ?? ""
        let supertype = card.classification?.supertype?.lowercased() ?? ""

        for option in selected {
            let t = option.lowercased()
            if cardType == t { return true }
            // For tokens, map subtype to parent type
            if supertype == "token" {
                let parent = CardFilters.tokenParentMap[cardType] ?? cardType
                if parent == t { return true }
            }
        }
        return false
    }

    private func matchesSeries(_ card: Card, selected: Set<String>) -> Bool {
        guard !selected.isEmpty else { return true }
        let label = card.set?.label ?? ""
        return selected.contains { seriesName in
            guard let entry = CardFilters.knownSeries.first(where: { $0.name == seriesName })
            else { return false }
            return label.localizedCaseInsensitiveContains(entry.fragment)
        }
    }

    private func matchesRarities(_ card: Card, selected: Set<String>) -> Bool {
        guard !selected.isEmpty else { return true }
        let rarity = card.classification?.rarity?.lowercased() ?? ""
        return selected.contains { $0.lowercased() == rarity }
    }

    private func matchesCost(_ card: Card, filters: CardFilters) -> Bool {
        let energy = card.attributes?.energy ?? 0
        let power  = card.attributes?.power  ?? 0
        let might  = card.attributes?.might  ?? 0
        // A max slider AT its cap means "no upper limit" so future-set cards
        // exceeding today's caps still show with default filters.
        return energy >= filters.minEnergy
            && (filters.maxEnergy >= CardFilters.energyCap || energy <= filters.maxEnergy)
            && power >= filters.minPower
            && (filters.maxPower >= CardFilters.powerCap || power <= filters.maxPower)
            && might >= filters.minMight
            && (filters.maxMight >= CardFilters.mightCap || might <= filters.maxMight)
    }
}
