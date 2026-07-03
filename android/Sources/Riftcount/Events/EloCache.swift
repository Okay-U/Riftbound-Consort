import Foundation

/// Caching layer in front of `EloShowdownAPI`. The Profile segment is torn
/// down and rebuilt on every segment switch, which used to refire ~9 requests
/// per visit against a 60/hour anonymous rate limit. This actor memoizes
/// responses with a TTL so re-entering the Profile (or re-showing an opponent
/// badge) inside the window costs zero requests.
///
/// Views keep talking to `any EloShowdownService`; only their default service
/// instance points here. Failures are never cached — a 429/500 retries on the
/// next call. `lookup` nil results (no profile, a successful 404) ARE cached,
/// since repeat lookups of profile-less opponents are exactly the waste case.
actor EloCache: EloShowdownService {
    static let shared = EloCache()

    private let upstream = EloShowdownAPI()

    /// Default freshness window. ELO only moves when a match is reported, so
    /// ten minutes is plenty for live-tournament use.
    private let ttl: TimeInterval = 10 * 60
    /// Slow-moving registry data (season, distribution, communities).
    private let slowTTL: TimeInterval = 60 * 60

    private var entries: [String: (stamp: Date, value: Any)] = [:]
    private var lookups: [String: (stamp: Date, value: EloPlayer?)] = [:]

    /// Drop everything — pull-to-refresh path.
    func invalidateAll() {
        entries.removeAll()
        lookups.removeAll()
    }

    // MARK: - EloShowdownService

    func lookup(riftboundID: String) async throws -> EloPlayer? {
        if let hit = lookups[riftboundID], fresh(hit.stamp, ttl) {
            return hit.value
        }
        let value = try await upstream.lookup(riftboundID: riftboundID)
        lookups[riftboundID] = (Date(), value)
        return value
    }

    func search(query: String) async throws -> [EloSearchResult] {
        try await cached("search:\(query)", ttl) { try await upstream.search(query: query) }
    }

    func player(id: Int) async throws -> EloPlayer {
        try await cached("player:\(id)", ttl) { try await upstream.player(id: id) }
    }

    func stats(playerID: Int) async throws -> EloStats {
        try await cached("stats:\(playerID)", ttl) { try await upstream.stats(playerID: playerID) }
    }

    func dna(playerID: Int) async throws -> EloDNA {
        try await cached("dna:\(playerID)", ttl) { try await upstream.dna(playerID: playerID) }
    }

    func form(playerID: Int) async throws -> EloForm {
        try await cached("form:\(playerID)", ttl) { try await upstream.form(playerID: playerID) }
    }

    func eloHistory(playerID: Int) async throws -> EloHistory {
        try await cached("history:\(playerID)", ttl) { try await upstream.eloHistory(playerID: playerID) }
    }

    func topOpponents(playerID: Int) async throws -> [EloOpponent] {
        try await cached("opponents:\(playerID)", ttl) { try await upstream.topOpponents(playerID: playerID) }
    }

    func achievements(playerID: Int) async throws -> [EloAchievement] {
        try await cached("achievements:\(playerID)", ttl) { try await upstream.achievements(playerID: playerID) }
    }

    func rank(playerID: Int) async throws -> EloRank {
        try await cached("rank:\(playerID)", ttl) { try await upstream.rank(playerID: playerID) }
    }

    func currentSeason() async throws -> EloSeason {
        try await cached("season", slowTTL) { try await upstream.currentSeason() }
    }

    func matchHistory(playerID: Int, seasonSlug: String, page: Int, pageSize: Int) async throws -> EloMatchPage {
        try await cached("matches:\(playerID):\(seasonSlug):\(page):\(pageSize)", ttl) {
            try await upstream.matchHistory(playerID: playerID, seasonSlug: seasonSlug,
                                            page: page, pageSize: pageSize)
        }
    }

    func leaderboard(season: String, community: String?, country: String?, limit: Int) async throws -> [EloLeaderRow] {
        try await cached("leaderboard:\(season):\(community ?? "-"):\(country ?? "-"):\(limit)", ttl) {
            try await upstream.leaderboard(season: season, community: community,
                                           country: country, limit: limit)
        }
    }

    func communities() async throws -> [EloCommunity] {
        try await cached("communities", slowTTL) { try await upstream.communities() }
    }

    func headToHead(playerID: Int, opponentID: Int) async throws -> EloH2H {
        try await cached("h2h:\(playerID):\(opponentID)", ttl) {
            try await upstream.headToHead(playerID: playerID, opponentID: opponentID)
        }
    }

    func eloDistribution() async throws -> EloDistribution {
        try await cached("distribution", slowTTL) { try await upstream.eloDistribution() }
    }

    // MARK: - Store

    private func fresh(_ stamp: Date, _ window: TimeInterval) -> Bool {
        Date().timeIntervalSince(stamp) < window
    }

    private func cached<T: Sendable>(_ key: String, _ window: TimeInterval,
                                     _ fetch: () async throws -> T) async throws -> T {
        if let hit = entries[key], fresh(hit.stamp, window), let value = hit.value as? T {
            return value
        }
        let value = try await fetch()
        entries[key] = (Date(), value)
        return value
    }
}
