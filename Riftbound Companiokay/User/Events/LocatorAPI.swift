//
//  LocatorAPI.swift
//  Riftbound Companiokay
//
//  Read-only client for the Riftbound Locator (UVS Games Hydra) REST API.
//  Step 1: public "TV" endpoints only — no auth. Login + writes come later.
//

import Foundation

protocol LocatorService: Sendable {
    func event(id: Int) async throws -> LocatorEvent
    func pairings(eventID: Int) async throws -> [LocatorMatch]
    func standings(eventID: Int) async throws -> [LocatorStanding]
    func myEvents(token: String) async throws -> [LocatorUserEventStatus]
    func myMatch(roundID: Int, token: String) async throws -> LocatorMyMatch
    func reportResult(matchID: Int,
                      token: String,
                      myPMRID: Int,
                      myGamesWon: Int,
                      opponentPMRID: Int,
                      opponentGamesWon: Int,
                      gamesDrawn: Int) async throws
}

final class RiftboundLocatorService: LocatorService {
    private let base = URL(string: "https://api.riftbound.uvsgames.com/api/v2/")!
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

    func event(id: Int) async throws -> LocatorEvent {
        try await get("events/\(id)/")
    }

    func pairings(eventID: Int) async throws -> [LocatorMatch] {
        let page: LocatorPage<LocatorMatch> = try await get("player/events/\(eventID)/tv/matches/")
        return page.results
    }

    func standings(eventID: Int) async throws -> [LocatorStanding] {
        let page: LocatorPage<LocatorStanding> = try await get("player/events/\(eventID)/tv/standings/")
        return page.results
    }

    func myEvents(token: String) async throws -> [LocatorUserEventStatus] {
        let page: LocatorPage<LocatorUserEventStatus> = try await get(
            "player/user-event-statuses/?game_slug=riftbound&ordering=-start_datetime",
            token: token
        )
        return page.results
    }

    func myMatch(roundID: Int, token: String) async throws -> LocatorMyMatch {
        try await get("tournament-rounds/\(roundID)/my-match/", token: token)
    }

    func reportResult(matchID: Int,
                      token: String,
                      myPMRID: Int,
                      myGamesWon: Int,
                      opponentPMRID: Int,
                      opponentGamesWon: Int,
                      gamesDrawn: Int) async throws {
        let json: [String: Any] = [
            "status": "COMPLETE",
            "players": [
                ["id": myPMRID, "games_won": myGamesWon],
                ["id": opponentPMRID, "games_won": opponentGamesWon],
            ],
            "games_drawn": gamesDrawn,
        ]
        guard let url = URL(string: "tournament-matches/\(matchID)/update-status/", relativeTo: base) else {
            throw LocatorError.badURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: json)

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LocatorError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 409 { throw LocatorError.alreadyReported }
            throw LocatorError.http(http.statusCode)
        }
    }

    private func get<T: Decodable>(_ path: String, token: String? = nil) async throws -> T {
        guard let url = URL(string: path, relativeTo: base) else {
            throw LocatorError.badURL
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LocatorError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw LocatorError.http(http.statusCode)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw LocatorError.decoding(error)
        }
    }
}

enum LocatorError: LocalizedError {
    case badURL
    case badResponse
    case http(Int)
    case decoding(Error)
    case alreadyReported

    var errorDescription: String? {
        switch self {
        case .badURL:          return "Invalid request."
        case .badResponse:     return "Couldn't reach the tournament server."
        case .http(let code):  return "Tournament server error (\(code))."
        case .decoding:        return "Couldn't read the tournament data."
        case .alreadyReported: return "This match is already reported. Ask the scorekeeper if it needs changing."
        }
    }
}
