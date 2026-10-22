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
    var availableRarities: [String] {
        dynamicOptions(baseline: CardFilters.knownRarities,
                       values: allCards.compactMap { $0.classification?.rarity },
                       excluding: [])
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

    private let repo = HostedCardRepository()
    private var loadTask: Task<Void, Never>?

    /// Keeps the first row per printing. The feed is built de-duplicated, but a
    /// source hiccup must never double every card in the grid.
    private static func dedupe(_ cards: [Card]) -> [Card] {
        var seen = Set<String>(), ids = Set<String>()
        var out: [Card] = []
        for card in cards {
            let key = "\(card.riftboundId ?? card.id)|\(card.name)"
            // One row per id too: id lookups build dictionaries that trap on a duplicate key.
            if seen.insert(key).inserted, ids.insert(card.id).inserted { out.append(card) }
        }
        return out
    }

    private static func computeLegendNames(from cards: [Card]) -> [String] {
        var names: Set<String> = []
        for card in cards {
            let type = card.classification?.type?.lowercased()
            let rarity = card.classification?.rarity?.lowercased()
            if type == "legend" && rarity == "rare" {
                // One name per legend: "(Overnumbered)", "(Signature)" and "(Starter)" printings
                // are the same legend for opponents and stats.
                names.insert(card.name.replacingOccurrences(of: #"\s*\([^)]*\)$"#, with: "", options: .regularExpression))
            }
        }
        return names.sorted()
    }

    func loadIfNeeded() {
        guard allCards.isEmpty, !isLoading else { return }
        load()
    }

    /// Back in the foreground: checks the feed again once it is due (an unchanged feed answers
    /// 304), so a phone that keeps the app in the background for days still sees a new set's
    /// cards leave preview. Nil while the first check of this launch is still running.
    func refreshIfDue() {
        guard !allCards.isEmpty, !isLoading, let nextCheck, Date() >= nextCheck else { return }
        load()
    }

    private static let refreshInterval: TimeInterval = 6 * 60 * 60
    private static let retryInterval: TimeInterval = 15 * 60
    private var nextCheck: Date?

    private nonisolated static let cacheName = "cards_cache_v2.json"
    private nonisolated static let etagKey = "cardsFeedETag"

    private nonisolated static var cacheURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(cacheName)
    }

    /// The riftcodex-era snapshot. Decks saved before 3.5 reference its database
    /// ids; `DecklistStore.migrateLegacyIDs` maps them onto the hosted feed.
    nonisolated static var legacyCacheURL: URL {
        cacheURL.deletingLastPathComponent().appendingPathComponent("cards_cache_v1.json")
    }

    func load() {
        loadTask?.cancel()
        loadTask = Task {
            // Last snapshot first: the tab is usable immediately and the
            // network pass below silently replaces it when it lands.
            //
            // Detached, because this store is @MainActor and an unstructured
            // Task started here inherits that: the snapshot is 1.7 MB of JSON,
            // and decoding it on the main thread was the whole reason the tab
            // felt slow to open even though the cache was working.
            if allCards.isEmpty,
               let cached = await Task.detached(priority: .userInitiated, operation: {
                   Self.readCache()
               }).value {
                publish(cached)
            }
            isLoading = allCards.isEmpty   // spinner only when nothing to show
            loadError = nil
            do {
                // The ETag only means something while the snapshot it belongs to exists.
                let etag = allCards.isEmpty ? nil : UserDefaults.standard.string(forKey: Self.etagKey)
                let fetched = try await repo.allCards(ifChangedSince: etag)
                nextCheck = Date().addingTimeInterval(Self.refreshInterval)
                guard let fetched else {
                    isLoading = false
                    return
                }
                // A feed that lost most of the catalogue is a broken build, not a new card list:
                // keep the cards on screen and their offline copy.
                guard Self.isPlausible(fetched.page.items, replacing: allCards) else {
                    if allCards.isEmpty { loadError = "The card list looks incomplete. Please try again later." }
                    isLoading = false
                    return
                }
                publish(fetched.page.items)
                let snapshot = fetched.page.items, tag = fetched.etag
                Task.detached(priority: .utility) {
                    // The ETag only after its snapshot is on disk: an ETag without the matching
                    // snapshot would get 304 forever and keep a stale catalogue.
                    if Self.writeCache(snapshot) { UserDefaults.standard.set(tag, forKey: Self.etagKey) }
                }
            } catch is CancellationError {
                // ignored
            } catch {
                // With a snapshot on screen a failed refresh stays invisible;
                // the error state is only for a truly empty tab.
                if allCards.isEmpty { loadError = error.localizedDescription }
                nextCheck = Date().addingTimeInterval(Self.retryInterval)
            }
            isLoading = false
        }
    }

    /// The feed's own build refuses fewer than 1000 cards or a 3% drop; the app only refuses
    /// the obviously broken: fewer than this, or under half of the cards shown now.
    private static let minimumFeedCards = 500

    private static func isPlausible(_ new: [Card], replacing old: [Card]) -> Bool {
        new.count >= max(minimumFeedCards, old.count / 2)
    }

    private nonisolated static func readCache() -> [Card]? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        // A corrupt/outdated snapshot just falls through to the network path.
        return try? JSONDecoder().decode([Card].self, from: data)
    }

    @discardableResult
    private nonisolated static func writeCache(_ cards: [Card]) -> Bool {
        guard let data = try? JSONEncoder().encode(cards) else { return false }
        // Documents may not exist yet in the Android sandbox.
        try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        // A failed write only costs the next launch a refetch.
        return (try? data.write(to: cacheURL, options: .atomic)) != nil
    }

    /// Bumped on every publish: card text, images or the preview flag can change while the
    /// number of cards stays the same.
    @Published private(set) var revision = 0
    /// What a search reads besides the name, per card id; built once per publish, not per keystroke.
    private var searchIndex: [String: String] = [:]

    private func publish(_ cards: [Card]) {
        revision += 1
        let unique = Self.dedupe(cards)
        allCards = unique
        legendNames = Self.computeLegendNames(from: unique)
        searchIndex = Dictionary(uniqueKeysWithValues: unique.map { ($0.id, Self.searchText(of: $0)) })
    }

    /// The rules text without its icon tokens (`:rb_might:`) and the tags, so "Repeat" or "friendly" finds
    /// every card that says it (Android parity, Okay 2026-10-22).
    private static func searchText(of card: Card) -> String {
        let rules = (card.text?.plain ?? "")
            .replacingOccurrences(of: ":rb_[a-z0-9_]+:", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&amp;", with: "&")
        return ([rules] + (card.tags ?? [])).joined(separator: " ")
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
        let ordered = sorted(matched, primary: primarySort, secondary: secondarySort)
        // Cards named so come before cards that only say it in their text.
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return ordered }
        return ordered.filter { $0.name.localizedCaseInsensitiveContains(q) }
            + ordered.filter { !$0.name.localizedCaseInsensitiveContains(q) }
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
            || searchIndex[card.id]?.localizedCaseInsensitiveContains(q) == true
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
