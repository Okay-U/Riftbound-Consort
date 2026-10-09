//
//  PlayRiftboundAPI+Unapproved.swift
//  Riftbound Companiokay
//
//  Operations outside Riot's written approval (see PlayRiftboundFeatures).
//  Shapes verified against the live site on 2026-10-09.
//

import Foundation

extension PlayRiftboundAPI {
    /// The site's event finder: `sport: "rb"`, a location, and the filters its UI offers.
    nonisolated struct SearchFilter: Encodable, Sendable, Equatable {
        nonisolated struct Coords: Encodable, Sendable, Equatable { let latitude: Double; let longitude: Double }
        let coords: Coords
        /// ISO 8601; the site passes "now minus one hour" so running events stay listed.
        let startDate: String
        let distanceMeters: Int?
        let types: [String]?
        let formats: [String]?
        let playerFormats: [String]?
        let favoritedOrganizersOnly: Bool?
    }

    nonisolated enum SearchSort: String, Sendable { case date = "DATE", distance = "DISTANCE" }

    private nonisolated struct SearchVariables: Encodable, Sendable {
        nonisolated struct Filter: Encodable, Sendable { let rb: SearchFilter }
        nonisolated struct Sort: Encodable, Sendable { let rb: String }
        let sport = "rb"
        let first: Int
        let after: String?
        let filter: Filter
        let sortBy: Sort
    }

    /// Public search; credentials only add `isFavorited` and the favourites filter.
    func searchTournaments(filter: SearchFilter, sort: SearchSort, after: String? = nil, first: Int = 20,
                           credentials: PlayRiftboundCredentials?) async throws -> CompeteSearchData {
        try await query("CompeteTournamentSearch",
                        variables: SearchVariables(first: first, after: after, filter: .init(rb: filter), sortBy: .init(rb: sort.rawValue)),
                        credentials: credentials)
    }

    static func searchStartDate(_ now: Date = Date()) -> String {
        now.addingTimeInterval(-3600).formatted(.iso8601)
    }

    // MARK: Registration (the player's own)

    private nonisolated struct TournamentIDVariables: Encodable, Sendable { let esportsTournamentId: String }
    /// The payloads carry nothing the app needs; success is the absence of errors.
    private nonisolated struct Ignored: Decodable, Sendable {}

    func register(tournamentID: String, credentials: PlayRiftboundCredentials) async throws {
        let _: Ignored = try await mutate("RegisterCompetePlayer", variables: TournamentIDVariables(esportsTournamentId: tournamentID), credentials: credentials)
    }

    /// Before the event starts.
    func deregister(tournamentID: String, credentials: PlayRiftboundCredentials) async throws {
        let _: Ignored = try await mutate("DeregisterCompetePlayer", variables: TournamentIDVariables(esportsTournamentId: tournamentID), credentials: credentials)
    }

    /// Once rounds are running.
    func drop(tournamentID: String, credentials: PlayRiftboundCredentials) async throws {
        let _: Ignored = try await mutate("DropCompetePlayerFromTournament", variables: TournamentIDVariables(esportsTournamentId: tournamentID), credentials: credentials)
    }
}

// MARK: - Response

nonisolated struct CompeteSearchData: Decodable, Sendable {
    let competeTournamentSearch: CompeteConnection<CompeteSearchResult>
}

/// `RbTournamentSearchResult`: a registration-style entry plus the distance to the store.
nonisolated struct CompeteSearchResult: Decodable, Sendable {
    let distanceMeters: Double?
    let organizer: CompeteOrganizer?
    let tournament: CompeteTournamentSummary

    var entry: PlayerTournamentEntry { PlayerTournamentEntry(organizer: organizer, tournament: tournament) }
}
