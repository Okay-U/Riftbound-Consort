import Foundation

/// Codable models for the eloshowdown.com public API (api/v1), ported from
/// iOS. Open, free API (attribution shown: "Powered by eloshowdown.com").
/// Decoder uses .convertFromSnakeCase, so snake_case JSON maps to camelCase.

/// Player identity + lifetime totals. The cross-reference to the Riftbound
/// Locator is `riftboundId` (the public player number), which equals the
/// Locator `users/self.id` we already hold as `AuthSession.userID`.
struct EloPlayer: Decodable, Sendable, Identifiable {
    let id: Int                       // eloshowdown internal id (used in /players/{id}/…)
    let displayName: String
    let riftboundId: String?
    let isAnonymous: Bool?
    let primaryCommunity: String?
    let primaryCommunitySlug: String?
    let country: String?
    let lifetimeTotalMatches: Int?
    let lifetimeWins: Int?
    let lifetimeLosses: Int?
    let lifetimeDraws: Int?
}

/// A season in the eloshowdown registry. `/seasons/current` returns the active one.
struct EloSeason: Decodable, Sendable, Identifiable {
    let slug: String
    let name: String?
    let start: Date?
    let end: Date?
    let isCurrent: Bool?

    var id: String { slug }
}

/// Lightweight search/autocomplete result.
struct EloSearchResult: Decodable, Sendable, Identifiable {
    let id: Int
    let displayName: String
    let primaryCommunity: String?
    let country: String?
}

// MARK: - Per-season stats

struct EloStats: Decodable, Sendable {
    let playerId: Int
    let seasons: [EloSeasonStats]
}

struct EloSeasonStats: Decodable, Sendable, Identifiable {
    let seasonSlug: String
    let seasonName: String?
    let matches: Int?
    let tournaments: Int?
    let wins: Int?
    let losses: Int?
    let draws: Int?
    let winRate: Double?
    let currentElo: Int?
    let peakElo: Int?
    let lowestElo: Int?
    let startingElo: Int?

    var id: String { seasonSlug }

    var record: String {
        "\(wins ?? 0)-\(losses ?? 0)-\(draws ?? 0)"
    }
}

// MARK: - Summoner's DNA (eloshowdown's signature stat)

struct EloDNA: Decodable, Sendable {
    let version: String?
    let seasonSlug: String?
    let dimensions: EloDNADimensions
}

struct EloDNADimensions: Decodable, Sendable {
    let dominance: Double?
    let consistency: Double?
    let composure: Double?
    let sweepPower: Double?
    let eventMastery: Double?
    let clutchCloser: Double?

    /// Display order with friendly labels, skipping any missing dimension.
    var ordered: [(label: String, value: Double)] {
        [("Dominance", dominance), ("Consistency", consistency), ("Composure", composure),
         ("Sweep Power", sweepPower), ("Event Mastery", eventMastery), ("Clutch Closer", clutchCloser)]
            .compactMap { pair in pair.1.map { (pair.0, $0) } }
    }
}

// MARK: - Rank / tier

struct EloRank: Decodable, Sendable {
    let seasonSlug: String?
    let seasonName: String?
    let tier: String?               // "iron"…"challenger"
    let isPlacement: Bool?
    let rankInCommunity: Int?
    let percentile: Double?
    let totalRanked: Int?
    let community: String?
    let country: String?
}

// MARK: - Opponents + achievements

struct EloOpponent: Decodable, Sendable, Identifiable {
    let opponentId: Int
    let opponentName: String
    let opponentCommunity: String?
    let totalMatches: Int?
    let wins: Int?
    let losses: Int?
    let draws: Int?
    let opponentCurrentElo: Int?

    var id: Int { opponentId }
    var record: String { "\(wins ?? 0)-\(losses ?? 0)-\(draws ?? 0)" }
    /// Positive = you're up in the H2H, negative = down.
    var net: Int { (wins ?? 0) - (losses ?? 0) }
}

struct EloAchievement: Decodable, Sendable, Identifiable {
    let code: String
    let name: String
    let rarity: String?
    let category: String?
    let icon: String?
    let earnedAt: Date?
    let seasonName: String?
    let isPermanent: Bool?

    var id: String { code }
}

// MARK: - Leaderboard + communities (store / city ranking)

/// One row of a community (city) leaderboard, ordered by current ELO.
struct EloLeaderRow: Decodable, Sendable, Identifiable {
    let rank: Int?
    let playerId: Int
    let displayName: String?
    let community: String?
    let country: String?
    let currentElo: Int?
    let totalMatches: Int?
    let winRate: Double?

    var id: Int { playerId }
}

/// A community (city) in the eloshowdown registry. Used to resolve a store's
/// geocoded city to the slug the leaderboard endpoint expects.
struct EloCommunity: Decodable, Sendable, Identifiable {
    let slug: String
    let name: String?
    let country: String?
    let state: String?
    let playerCount: Int?
    let isActive: Bool?

    var id: String { slug }
}

// MARK: - Head-to-head + ELO distribution

/// Head-to-head between two players this season (`/players/{id}/h2h/{opp_id}`).
struct EloH2H: Decodable, Sendable {
    let playerId: Int?
    let opponentId: Int?
    let seasonSlug: String?
    let totalMatches: Int?
    let wins: Int?
    let losses: Int?
    let draws: Int?
    let winRate: Double?
    let eloSwingTotal: Int?
    let lastMeeting: EloH2HMeeting?
    let firstMeetingDate: Date?

    var hasHistory: Bool { (totalMatches ?? 0) > 0 }
    var record: String { "\(wins ?? 0)-\(losses ?? 0)-\(draws ?? 0)" }
}

struct EloH2HMeeting: Decodable, Sendable {
    let date: Date?
    let result: String?      // "win" / "loss" / "draw" (from the player's side)
    let eloChange: Int?
}

/// Season-wide ELO histogram (`/stats/elo-distribution`), used to place a player
/// on the curve and compute their percentile.
struct EloDistribution: Decodable, Sendable {
    let seasonSlug: String?
    let buckets: [EloBucket]

    /// Percent of players at or above `elo` (i.e. "Top X%"), 0.1…100.
    func topPercent(for elo: Int) -> Double? {
        let total = buckets.reduce(0) { $0 + $1.count }
        guard total > 0 else { return nil }
        var below = 0.0
        for b in buckets {
            let width = max(b.bucketMax - b.bucketMin, 1)
            if elo >= b.bucketMax { below += Double(b.count) }
            else if elo > b.bucketMin {
                below += Double(b.count) * Double(elo - b.bucketMin) / Double(width)
            }
        }
        let top = (Double(total) - below) / Double(total) * 100
        return min(100, max(0.1, top))
    }
}

struct EloBucket: Decodable, Sendable, Identifiable {
    let bucketMin: Int
    let bucketMax: Int
    let count: Int

    var id: Int { bucketMin }
    var mid: Int { (bucketMin + bucketMax) / 2 }
}

// MARK: - ELO history + recent form

/// Whole-season, per-match ELO history. Also feeds the Match History card:
/// the eloshowdown dev added opponent_id/opponent_name/result to the points
/// (2026-07) at our request, replacing the unofficial `player-matches` web
/// endpoint we used to page through.
struct EloHistory: Decodable, Sendable {
    let seasonSlug: String?
    let points: [EloHistoryPoint]
}

struct EloHistoryPoint: Decodable, Sendable, Identifiable {
    let date: Date?
    let eloBefore: Int?
    let eloAfter: Int?
    let eloChange: Int?
    let matchId: Int
    let opponentId: Int?
    let opponentName: String?
    let result: String?       // "win" / "loss" / "draw"

    var id: Int { matchId }
}

struct EloForm: Decodable, Sendable {
    let seasonSlug: String?
    let lastN: [String]
    let currentStreak: EloStreak?
    let longestWinStreak: Int?
    let longestLossStreak: Int?
    let eloChangeLastN: Int?
}

struct EloStreak: Decodable, Sendable {
    let type: String?     // "win" / "loss" / "draw"
    let length: Int?
}
