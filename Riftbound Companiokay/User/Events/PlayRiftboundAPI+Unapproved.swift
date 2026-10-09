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
        struct Coords: Encodable, Sendable, Equatable { let latitude: Double; let longitude: Double }
        let coords: Coords
        /// ISO 8601; the site passes "now minus one hour" so running events stay listed.
        let startDate: String
        let distanceMeters: Int?
        let types: [String]?
        let formats: [String]?
        let playerFormats: [String]?
        let favoritedOrganizersOnly: Bool?
    }

    enum SearchSort: String, Sendable { case date = "DATE", distance = "DISTANCE" }

    private struct SearchVariables: Encodable, Sendable {
        struct Filter: Encodable, Sendable { let rb: SearchFilter }
        struct Sort: Encodable, Sendable { let rb: String }
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
