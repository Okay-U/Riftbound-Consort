//
//  PlayRiftboundAPI.swift
//  Riftbound Companiokay
//
//  Client for PlayRiftbound's GraphQL endpoint with the signed-in player's own
//  session: their own tournaments, one tournament's pairings and standings, and
//  their own result submission. Riot has approved none of it (Okay's risk,
//  docs/PLAYRIFTBOUND.md §4). The endpoint
//  accepts persisted operation ids only; the ids ship with the app and can be
//  replaced from okay-u.github.io when Riot redeploys, without an app update.
//  Details and the id table: docs/PLAYRIFTBOUND.md.
//

import Foundation
import os

nonisolated enum PlayRiftboundError: Error, LocalizedError {
    case notSignedIn
    case sessionExpired
    case unknownOperation(String)
    case staleOperationIDs
    case http(Int)
    case graphQL([String])
    case badResponse

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Sign in on PlayRiftbound first."
        case .sessionExpired: return "Your PlayRiftbound session expired. Open the PlayRiftbound segment to refresh it."
        case .unknownOperation(let name): return "Unknown operation \(name)."
        case .staleOperationIDs: return "PlayRiftbound changed. Update the app or try again later."
        case .http(let code): return "PlayRiftbound answered with status \(code)."
        case .graphQL(let messages): return messages.joined(separator: "\n")
        case .badResponse: return "Unexpected answer from PlayRiftbound."
        }
    }
}

// MARK: - Operation ids

/// Persisted-query ids, keyed by operation name. Built-in values are from the site
/// build of 2026-09-15; the remote file overrides them when Riot ships a new build.
actor PlayRiftboundOperationIDs {
    static let shared = PlayRiftboundOperationIDs()

    static let feed = URL(string: "https://okay-u.github.io/playriftbound-ops.json")!

    static let builtIn: [String: String] = [
        "PlayerTournaments": "b210fdb2100186e794cb96a3cd72b294dcc7ca9ae5733ad540141ac6a390be4d",
        "PlayerRegisteredTournamentIds": "b224261bf00cb424c12a30d914d6216f898e665fefc4550d89cf02679b629b29",
        "GetCompeteTournamentForRiftboundPlayer": "e56d6d93e4f8fa287557521535544350e5cc9baafd78ba69f9f592873b090e57",   // adds roundDuration, tableNumber (2026-10-20)
        "GetCompeteRbRefreshPoller": "459dbd58b231ad1767b999a1bf987836123ac86a0b5110e166de15b69723ba0d",
        "SubmitGameResults": "4f304b3a523f27d1abde2291d1b9e836e7b524f9e455d70b548680170e91c430",
        // Beyond the reads and the report (docs/PLAYRIFTBOUND.md §4):
        "CompeteTournamentSearch": "acbcbba681a9c9a8063f792f7d665ba1eda81b19528b6af19e523f0c2061bec2",
        "RegisterCompetePlayer": "7372d50ddebea493bd6aefdfce20666c7030d272252c0714fdcb2f63a92f9089",
        "DeregisterCompetePlayer": "c2c3984c2c050f1f9ab54e5fb373e99e645e91cf010ee4a681b80089826b63d2",
        "DropCompetePlayerFromTournament": "de49d7c455017093075e79b537558ee398b84aceab36bb0e1e648a665967d95d",
        "FavoritedOrganizers": "8186f58c21e12fb11f76e413ba2795d62baf8d21bc422575f3ea34d894edda2f",
        "FavoriteOrganizer": "80740df75cd7148fae22aa75c6070f37a8f16467c992c1eb8fc4711926d0816d",
        "UnfavoriteOrganizer": "8e20642289398a5a26a552089dd25ea5c8d81f3e197d4f0f3bd9d33f845b7fdf",
        "OrganizerSummary": "9142e18241bb86a3b4c2692d899b31aaf61d11065ca8a259191aa9cc0a06ed57",
    ]

    private var ids = builtIn
    private var refresh: Task<[String: String], Never>?

    func id(for operation: String) async -> String? {
        // One feed fetch shared by every caller; concurrent first calls wait for it instead of
        // racing ahead with possibly stale built-in ids.
        if refresh == nil { refresh = Task { await Self.fetchFeed() } }
        if let fetched = await refresh?.value {
            for (name, id) in fetched { ids[name] = id }
        }
        return ids[operation]
    }

    /// Fetch the feed again on the next call (after Riot rejected an id).
    func invalidate() { refresh = nil }

    private struct Feed: Decodable {
        struct Entry: Decodable { let id: String }
        let operations: [String: Entry]
    }

    /// Built-in ids stay in force when this fails; the feed is an accelerator, not a dependency.
    private static func fetchFeed() async -> [String: String] {
        var request = URLRequest(url: feed, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(Feed.self, from: data) else { return [:] }
        return decoded.operations.compactMapValues { $0.id.count == 64 ? $0.id : nil }
    }
}

// MARK: - Client

nonisolated final class PlayRiftboundAPI: Sendable {
    static let endpoint = URL(string: "https://playriftbound.com/api/gql")!

    private let ids: PlayRiftboundOperationIDs
    private let log = Logger(subsystem: "pitopia.Riftcount", category: "PlayRiftboundAPI")

    /// One session for every instance: a session keeps its delegate until it is invalidated,
    /// and views create a new API on every update, so a session each would never be freed.
    private static let session: URLSession = {
        // No cookie jar of our own: the player's cookies are passed per request and
        // never stored outside the web view's data store.
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.timeoutIntervalForRequest = 20
        // The player's cookies are set by hand on each request; a redirect must never carry
        // them anywhere else (or re-POST a result), so redirects are refused outright.
        return URLSession(configuration: config, delegate: RefuseRedirects(), delegateQueue: nil)
    }()

    init(ids: PlayRiftboundOperationIDs = .shared) {
        self.ids = ids
    }

    // MARK: Reads and the report

    private struct PlayerTournamentsVariables: Encodable, Sendable {
        let upcomingFirst: Int
        let pastFirst: Int
    }

    func myTournaments(credentials: PlayRiftboundCredentials, upcoming: Int = 20, past: Int = 20) async throws -> PlayerTournamentsData {
        try await query("PlayerTournaments",
                        variables: PlayerTournamentsVariables(upcomingFirst: upcoming, pastFirst: past),
                        credentials: credentials)
    }

    private struct TournamentVariables: Encodable, Sendable { let tournamentId: String }

    /// One tournament with rounds, matches and standings, as the player sees it on the site.
    func tournament(id: String, credentials: PlayRiftboundCredentials) async throws -> CompeteTournament? {
        let data: CompeteTournamentsData = try await query("GetCompeteTournamentForRiftboundPlayer",
                                                           variables: TournamentVariables(tournamentId: id),
                                                           credentials: credentials)
        return data.competeTournaments.first
    }

    /// One game of a result report. `winnerParticipantID` nil + `draw` false = not played (omit instead).
    nonisolated struct GameResult: Encodable, Sendable {
        let gameId: String
        let draw: Bool
        let winnerParticipantId: String?
    }

    private struct SubmitInput: Encodable, Sendable {
        let esportsTournamentId: String
        let games: [GameResult]
    }
    private struct SubmitVariables: Encodable, Sendable { let input: SubmitInput }
    private struct SubmitData: Decodable, Sendable {
        struct Payload: Decodable, Sendable { let submittedGameIds: [String]? }
        let submitGameResults: Payload?
    }

    /// The player's own result for games of their current match.
    /// Shape recovered from the gateway's validation errors, see docs/PLAYRIFTBOUND.md.
    @discardableResult
    func submitGameResults(tournamentID: String, games: [GameResult], credentials: PlayRiftboundCredentials) async throws -> [String] {
        let data: SubmitData = try await mutate("SubmitGameResults",
                                                variables: SubmitVariables(input: SubmitInput(esportsTournamentId: tournamentID, games: games)),
                                                credentials: credentials)
        return data.submitGameResults?.submittedGameIds ?? []
    }

    // MARK: Transport

    private struct Extensions: Encodable {
        struct Persisted: Encodable { let version = 1; let sha256Hash: String }
        let persistedQuery: Persisted
    }

    private struct MutationBody<V: Encodable>: Encodable {
        let operationName: String
        let variables: V
        let extensions: Extensions
    }

    /// Persisted query over GET, the way the site does it.
    func query<V: Encodable & Sendable, T: Decodable & Sendable>(_ operation: String, variables: V,
                                                                 credentials: PlayRiftboundCredentials?) async throws -> T {
        guard let id = await ids.id(for: operation) else { throw PlayRiftboundError.unknownOperation(operation) }
        var components = URLComponents(url: Self.endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "operationName", value: operation),
            URLQueryItem(name: "variables", value: try jsonString(variables)),
            URLQueryItem(name: "extensions", value: try jsonString(Extensions(persistedQuery: .init(sha256Hash: id)))),
        ]
        guard let url = components.url else { throw PlayRiftboundError.badResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return try await perform(request, operation: operation, credentials: credentials)
    }

    /// Persisted mutation over POST.
    func mutate<V: Encodable & Sendable, T: Decodable & Sendable>(_ operation: String, variables: V,
                                                                  credentials: PlayRiftboundCredentials) async throws -> T {
        guard let id = await ids.id(for: operation) else { throw PlayRiftboundError.unknownOperation(operation) }
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("https://playriftbound.com", forHTTPHeaderField: "Origin")
        request.httpBody = try JSONEncoder().encode(MutationBody(operationName: operation, variables: variables,
                                                                 extensions: Extensions(persistedQuery: .init(sha256Hash: id))))
        return try await perform(request, operation: operation, credentials: credentials)
    }

    private func perform<T: Decodable & Sendable>(_ request: URLRequest, operation: String,
                                                  credentials: PlayRiftboundCredentials?) async throws -> T {
        var request = request
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Riftcount", forHTTPHeaderField: "apollographql-client-name")
        request.setValue(Self.appVersion, forHTTPHeaderField: "apollographql-client-version")
        if let credentials {
            if credentials.isExpired { throw PlayRiftboundError.sessionExpired }
            request.setValue(credentials.cookieHeader, forHTTPHeaderField: "Cookie")
            request.setValue("Cookie \(PlayRiftboundSession.accessCookie)", forHTTPHeaderField: "Authorization")
        }

        #if DEBUG
        // Settings › Debug › Fake live event: answered here, nothing goes to Riot.
        let (data, status) = FakeLiveEvent.isOn ? FakeLiveEvent.answer(to: request, operation: operation) : try await Self.send(request)
        #else
        let (data, status) = try await Self.send(request)
        #endif
        if status == 401 || status == 403 {
            // Without a session a 401/403 is the gateway or CDN, not an expired sign-in.
            throw credentials == nil ? PlayRiftboundError.http(status) : PlayRiftboundError.sessionExpired
        }

        let envelope: GraphQLEnvelope<T>
        do {
            envelope = try Self.decoder.decode(GraphQLEnvelope<T>.self, from: data)
        } catch {
            guard (200..<300).contains(status) else { throw PlayRiftboundError.http(status) }
            log.error("\(operation, privacy: .public): undecodable response: \(String(describing: error), privacy: .public)")
            throw PlayRiftboundError.badResponse
        }
        if let errors = envelope.errors, !errors.isEmpty {
            let codes = errors.compactMap { $0.extensions?.code }
            if codes.contains("PERSISTED_QUERY_NOT_FOUND") || codes.contains("PERSISTED_QUERY_ID_REQUIRED") {
                await ids.invalidate()
                throw PlayRiftboundError.staleOperationIDs
            }
            if codes.contains("UNAUTHENTICATED")
                || errors.contains(where: { $0.message.localizedCaseInsensitiveContains("jwt") && $0.message.localizedCaseInsensitiveContains("expired") }) {
                throw PlayRiftboundError.sessionExpired
            }
            throw PlayRiftboundError.graphQL(errors.map(\.message))
        }
        guard let payload = envelope.data else { throw PlayRiftboundError.badResponse }
        return payload
    }

    private static func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PlayRiftboundError.badResponse }
        return (data, http.statusCode)
    }

    private static let appVersion: String =
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"

    private func jsonString<E: Encodable>(_ value: E) throws -> String {
        String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
    }

    /// Riot sends plain and fractional-second ISO 8601 timestamps.
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date(raw, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true)) { return date }
            if let date = try? Date(raw, strategy: .iso8601) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(raw)"))
        }
        return decoder
    }()
}

/// The GraphQL endpoint never redirects; anything that does is answered as the 3xx itself.
/// Completion-handler form on purpose: the async form crashes the compiler (SILGen, Obj-C thunk).
private nonisolated final class RefuseRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
