//
//  EloShowdownAPI.swift
//  Riftbound Companiokay
//
//  Read-only client for the eloshowdown.com public API (api/v1). Keyless:
//  anonymous access is rate-limited per IP (60 req/hour), which is plenty for a
//  profile screen and avoids embedding a shared secret in the app binary.
//  HTTPS only. Attribution ("Powered by eloshowdown.com") is shown in the UI.
//

import Foundation

protocol EloShowdownService: Sendable {
    /// Resolve a Riftbound player number to an eloshowdown player. nil = no match.
    func lookup(riftboundID: String) async throws -> EloPlayer?
    func search(query: String) async throws -> [EloSearchResult]
    func player(id: Int) async throws -> EloPlayer
    func stats(playerID: Int) async throws -> EloStats
    func dna(playerID: Int) async throws -> EloDNA
    func form(playerID: Int) async throws -> EloForm
    func eloHistory(playerID: Int) async throws -> EloHistory
    func topOpponents(playerID: Int) async throws -> [EloOpponent]
    func achievements(playerID: Int) async throws -> [EloAchievement]
    func rank(playerID: Int) async throws -> EloRank
    func currentSeason() async throws -> EloSeason
    /// Community (city) leaderboard by current ELO. `community` is a slug from `communities()`.
    func leaderboard(season: String, community: String?, country: String?, limit: Int) async throws -> [EloLeaderRow]
    /// Registry of communities (cities) — used to resolve a store's city to a slug.
    func communities() async throws -> [EloCommunity]
    /// Head-to-head between two players (both eloshowdown internal ids).
    func headToHead(playerID: Int, opponentID: Int) async throws -> EloH2H
    /// Season-wide ELO histogram for placing a player on the curve.
    func eloDistribution() async throws -> EloDistribution
}

nonisolated final class EloShowdownAPI: EloShowdownService {
    private let base = URL(string: "https://eloshowdown.com/api/v1/")!
    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)

        // Tolerate both plain ("…Z") and fractional-second ("…+00:00") ISO-8601 —
        // the v1 endpoints use the former, player-matches the latter. Parsed via
        // Date.ISO8601FormatStyle (Sendable, unlike ISO8601DateFormatter — the
        // decoding closure is @Sendable).
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { d in
            let raw = try d.singleValueContainer().decode(String.self)
            if let date = try? Date(raw, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
                return date
            }
            if let date = try? Date(raw, strategy: Date.ISO8601FormatStyle()) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(codingPath: d.codingPath,
                                                    debugDescription: "Unparseable date: \(raw)"))
        }
        self.decoder = decoder
    }

    func lookup(riftboundID: String) async throws -> EloPlayer? {
        do {
            return try await get("lookup?riftbound_id=\(encoded(riftboundID))")
        } catch EloError.http(404) {
            return nil   // no eloshowdown profile for this player
        }
    }

    func search(query: String) async throws -> [EloSearchResult] {
        try await get("search?q=\(encoded(query))")
    }

    func player(id: Int) async throws -> EloPlayer {
        try await get("players/\(id)")
    }

    func stats(playerID: Int) async throws -> EloStats {
        try await get("players/\(playerID)/stats")
    }

    func dna(playerID: Int) async throws -> EloDNA {
        try await get("players/\(playerID)/dna")
    }

    func form(playerID: Int) async throws -> EloForm {
        try await get("players/\(playerID)/form")
    }

    func eloHistory(playerID: Int) async throws -> EloHistory {
        try await get("players/\(playerID)/elo-history")
    }

    func topOpponents(playerID: Int) async throws -> [EloOpponent] {
        try await get("players/\(playerID)/top-opponents")
    }

    func achievements(playerID: Int) async throws -> [EloAchievement] {
        try await get("players/\(playerID)/achievements")
    }

    func rank(playerID: Int) async throws -> EloRank {
        try await get("players/\(playerID)/rank")
    }

    func currentSeason() async throws -> EloSeason {
        try await get("seasons/current")
    }

    func leaderboard(season: String, community: String?, country: String?, limit: Int) async throws -> [EloLeaderRow] {
        var query = "season=\(encoded(season))&limit=\(limit)"
        if let community, !community.isEmpty { query += "&community=\(encoded(community))" }
        if let country, !country.isEmpty { query += "&country=\(encoded(country))" }
        return try await get("leaderboard/?\(query)")   // trailing slash: endpoint 301s without it
    }

    func communities() async throws -> [EloCommunity] {
        try await get("communities")
    }

    func headToHead(playerID: Int, opponentID: Int) async throws -> EloH2H {
        try await get("players/\(playerID)/h2h/\(opponentID)")
    }

    func eloDistribution() async throws -> EloDistribution {
        try await get("stats/elo-distribution")
    }

    // MARK: - Transport

    private func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }

    private func get<T: Decodable>(_ path: String, relativeTo root: URL? = nil) async throws -> T {
        guard let url = URL(string: path, relativeTo: root ?? base) else { throw EloError.badURL }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw EloError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw EloError.http(http.statusCode)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw EloError.decoding(error)
        }
    }
}

enum EloError: LocalizedError {
    case badURL
    case badResponse
    case http(Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .badURL:      return "Invalid request."
        case .badResponse: return "Couldn't reach eloshowdown."
        case .http(let code):
            switch code {
            case 404: return "No eloshowdown profile found."
            case 429: return "Too many requests. Try again in a bit."
            case 500...599: return "eloshowdown is having problems. Try again later."
            default: return "eloshowdown error (\(code))."
            }
        case .decoding:    return "Couldn't read the eloshowdown data."
        }
    }
}
