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
    func currentSeason() async throws -> EloSeason
}

nonisolated final class EloShowdownAPI: EloShowdownService {
    private let base = URL(string: "https://eloshowdown.com/api/v1/")!
    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
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

    func currentSeason() async throws -> EloSeason {
        try await get("seasons/current")
    }

    // MARK: - Transport

    private func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: path, relativeTo: base) else { throw EloError.badURL }
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
