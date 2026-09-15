//
//  PlayRiftboundAPI.swift
//  Riftbound Companiokay
//
//  Client for PlayRiftbound's GraphQL endpoint, limited to the operations Riot
//  approved for the app: the signed-in player's own tournaments, one tournament's
//  pairings and standings, and the player's own result submission. The endpoint
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
        case .notSignedIn: return "Sign in on New Events first."
        case .sessionExpired: return "Your PlayRiftbound session expired. Open New Events to refresh it."
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
        "GetCompeteTournamentForRiftboundPlayer": "e384f3569a74c3090177e04205d38c126f4c61a72853ed7fa04cbe9eba8f19ec",
        "GetCompeteRbRefreshPoller": "459dbd58b231ad1767b999a1bf987836123ac86a0b5110e166de15b69723ba0d",
        "SubmitGameResults": "4f304b3a523f27d1abde2291d1b9e836e7b524f9e455d70b548680170e91c430",
    ]

    private var ids = builtIn
    private var refreshed = false

    func id(for operation: String) async -> String? {
        await refreshOnce()
        return ids[operation]
    }

    /// Drop the in-memory override so the next call fetches the feed again.
    func invalidate() { refreshed = false }

    private struct Feed: Decodable {
        struct Entry: Decodable { let id: String }
        let operations: [String: Entry]
    }

    private func refreshOnce() async {
        guard !refreshed else { return }
        refreshed = true
        do {
            let (data, response) = try await URLSession.shared.data(from: Self.feed)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let feed = try JSONDecoder().decode(Feed.self, from: data)
            for (name, entry) in feed.operations where entry.id.count == 64 {
                ids[name] = entry.id
            }
        } catch {
            // Built-in ids stay in force; the feed is an accelerator, not a dependency.
        }
    }
}

// MARK: - Client

nonisolated final class PlayRiftboundAPI: Sendable {
    static let endpoint = URL(string: "https://playriftbound.com/api/gql")!

    private let session: URLSession
    private let ids: PlayRiftboundOperationIDs
    private let log = Logger(subsystem: "pitopia.Riftcount", category: "PlayRiftboundAPI")

    init(ids: PlayRiftboundOperationIDs = .shared) {
        // No cookie jar of our own: the player's cookies are passed per request and
        // never stored outside the web view's data store.
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)
        self.ids = ids
    }

    // MARK: Approved operations

    private struct PlayerTournamentsVariables: Encodable, Sendable {
        let upcomingFirst: Int
        let pastFirst: Int
    }

    func myTournaments(credentials: PlayRiftboundCredentials, upcoming: Int = 20, past: Int = 20) async throws -> PlayerTournamentsData {
        try await query("PlayerTournaments",
                        variables: PlayerTournamentsVariables(upcomingFirst: upcoming, pastFirst: past),
                        credentials: credentials)
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
        return try await send(request, operation: operation, credentials: credentials)
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
        return try await send(request, operation: operation, credentials: credentials)
    }

    private func send<T: Decodable & Sendable>(_ request: URLRequest, operation: String,
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

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PlayRiftboundError.badResponse }
        if http.statusCode == 401 || http.statusCode == 403 { throw PlayRiftboundError.sessionExpired }

        let envelope: GraphQLEnvelope<T>
        do {
            envelope = try Self.decoder.decode(GraphQLEnvelope<T>.self, from: data)
        } catch {
            guard (200..<300).contains(http.statusCode) else { throw PlayRiftboundError.http(http.statusCode) }
            log.error("\(operation, privacy: .public): undecodable response: \(error.localizedDescription, privacy: .public)")
            throw PlayRiftboundError.badResponse
        }
        if let errors = envelope.errors, !errors.isEmpty {
            let codes = errors.compactMap { $0.extensions?.code }
            if codes.contains("PERSISTED_QUERY_NOT_FOUND") || codes.contains("PERSISTED_QUERY_ID_REQUIRED") {
                await ids.invalidate()
                throw PlayRiftboundError.staleOperationIDs
            }
            if codes.contains("UNAUTHENTICATED") { throw PlayRiftboundError.sessionExpired }
            throw PlayRiftboundError.graphQL(errors.map(\.message))
        }
        guard let payload = envelope.data else { throw PlayRiftboundError.badResponse }
        return payload
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

// MARK: - Debug probe (step 1 verification, removed once the UI exists)

#if DEBUG
extension PlayRiftboundAPI {
    /// Logs the signed-in player's upcoming PlayRiftbound events. Run from Xcode and read the console.
    @MainActor
    static func debugProbe() async {
        let log = Logger(subsystem: "pitopia.Riftcount", category: "PlayRiftboundAPI")
        guard let credentials = await PlayRiftboundSession.credentials() else {
            log.debug("probe: no PlayRiftbound session in the web view store")
            return
        }
        if credentials.isExpired {
            log.debug("probe: session expired at \(credentials.expiry?.description ?? "-")")
            return
        }
        do {
            let data = try await PlayRiftboundAPI().myTournaments(credentials: credentials)
            let upcoming = data.playerTournaments.upcoming.nodes
            log.debug("probe: \(upcoming.count) upcoming, \(data.playerTournaments.past.nodes.count) past")
            for entry in upcoming {
                let t = entry.tournament
                log.debug("probe upcoming: \(t.name) · \(t.startsAt?.description ?? "-") · \(entry.organizer?.name ?? "-") · \(t.registeredCount)/\(t.config?.participantCapacity ?? 0)")
            }
        } catch {
            log.error("probe failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
#endif
