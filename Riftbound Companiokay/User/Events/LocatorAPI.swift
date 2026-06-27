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
    func myEvents(token: String, page: Int) async throws -> LocatorPage<LocatorUserEventStatus>
    func myMatch(roundID: Int, token: String) async throws -> LocatorMyMatch
    func searchStores(query: String, page: Int) async throws -> LocatorPage<LocatorStoreWrapper>
    func storesNearby(latitude: Double, longitude: Double, miles: Int, page: Int) async throws -> LocatorPage<LocatorStoreWrapper>
    func store(id: String) async throws -> LocatorStoreWrapper
    func storeEvents(storeID: Int, status: String?, page: Int) async throws -> LocatorPage<LocatorStoreEvent>
    func register(eventID: Int, token: String) async throws
    func drop(eventID: Int, token: String) async throws
    func registrationStatus(eventID: Int, token: String) async throws -> String?
    func myDeckSubmission(eventID: Int, token: String) async throws -> LocatorDeckSubmission?
    func reportResult(matchID: Int,
                      token: String,
                      myPMRID: Int,
                      myGamesWon: Int,
                      opponentPMRID: Int,
                      opponentGamesWon: Int,
                      gamesDrawn: Int) async throws
}

nonisolated final class RiftboundLocatorService: LocatorService {
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
        let page: LocatorPage<LocatorMatch> = try await get("player/events/\(eventID)/tv/matches/?page_size=500")
        return page.results
    }

    func standings(eventID: Int) async throws -> [LocatorStanding] {
        let page: LocatorPage<LocatorStanding> = try await get("player/events/\(eventID)/tv/standings/?page_size=500")
        return page.results
    }

    func myEvents(token: String, page: Int) async throws -> LocatorPage<LocatorUserEventStatus> {
        try await get(
            "player/user-event-statuses/?game_slug=riftbound&ordering=-start_datetime&page=\(page)",
            token: token
        )
    }

    func myMatch(roundID: Int, token: String) async throws -> LocatorMyMatch {
        try await get("tournament-rounds/\(roundID)/my-match/", token: token)
    }

    func searchStores(query: String, page: Int) async throws -> LocatorPage<LocatorStoreWrapper> {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return try await get("game-stores/?game_slug=riftbound&search=\(encoded)&page=\(page)")
    }

    func store(id: String) async throws -> LocatorStoreWrapper {
        try await get("game-stores/\(id)/")
    }

    /// Stores within `miles` of a coordinate (distance-sorted). Riftbound = game_id 3.
    func storesNearby(latitude: Double, longitude: Double, miles: Int, page: Int) async throws -> LocatorPage<LocatorStoreWrapper> {
        try await get("game-stores/?game_id=3&num_miles=\(miles)&latitude=\(latitude)&longitude=\(longitude)&page=\(page)&page_size=25")
    }

    func storeEvents(storeID: Int, status: String?, page: Int) async throws -> LocatorPage<LocatorStoreEvent> {
        var path = "events/?game_slug=riftbound&store=\(storeID)&page=\(page)&ordering=start_datetime"
        if let status, !status.isEmpty { path += "&display_status=\(status)" }
        return try await get(path)
    }

    func register(eventID: Int, token: String) async throws {
        // Exact body the website sends. `initial_registration_status: COMPLETE` is
        // what actually registers you (without it you stay a draft); environment
        // is uppercase "PRODUCTION".
        try await postVoid("user-event-statuses/get-or-create/", token: token,
                           json: ["event_id": eventID,
                                  "initial_registration_status": "COMPLETE",
                                  "brand_key": "riftbound",
                                  "environment": "PRODUCTION"])
    }

    func drop(eventID: Int, token: String) async throws {
        try await postVoid("user-event-statuses/drop/", token: token, json: ["event_id": eventID])
    }

    /// Current user's registration status for an event (nil = not registered). Read-only GET.
    func registrationStatus(eventID: Int, token: String) async throws -> String? {
        do {
            let ues: LocatorRegistrationStatus = try await get("user-event-statuses/event/\(eventID)/", token: token)
            return ues.registrationStatus
        } catch LocatorError.http(404) {
            return nil   // no registration for this event
        }
    }

    func myDeckSubmission(eventID: Int, token: String) async throws -> LocatorDeckSubmission? {
        let result: LocatorDeckSubmissions = try await get("deckbuilder/deck-submissions/events/\(eventID)/", token: token)
        return result.submissions.first
    }

    private func postVoid(_ path: String, token: String, json: [String: Any]) async throws {
        guard let url = URL(string: path, relativeTo: base) else { throw LocatorError.badURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: json)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LocatorError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 { throw LocatorError.http(401) }   // keep 401 → sign-out path
            if let message = Self.serverMessage(in: data) { throw LocatorError.serverMessage(message) }
            throw LocatorError.http(http.statusCode)
        }
    }

    /// Pull a human message out of a Locator error body (`{"message": ...}` /
    /// `{"detail": ...}` / `{"non_field_errors": [...] }`).
    private static func serverMessage(in data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let message = json["message"] as? String, !message.isEmpty, message != "Form is invalid" { return message }
        if let detail = json["detail"] as? String, !detail.isEmpty { return detail }
        if let errors = json["non_field_errors"] as? [String], let first = errors.first { return first }
        return nil
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
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .badURL:          return "Invalid request."
        case .badResponse:     return "Couldn't reach the tournament server."
        case .http(let code):
            switch code {
            case 403: return "Registration isn't available for this event — it may be full or not accepting sign-ups."
            case 404: return "This event couldn't be found. It may have been removed."
            case 401: return "Your session ended. Please sign in again."
            case 500...599: return "The tournament server is having problems. Try again later."
            default: return "Tournament server error (\(code))."
            }
        case .decoding:        return "Couldn't read the tournament data."
        case .alreadyReported: return "This match is already reported. Ask the scorekeeper if it needs changing."
        case .serverMessage(let message): return message
        }
    }
}
