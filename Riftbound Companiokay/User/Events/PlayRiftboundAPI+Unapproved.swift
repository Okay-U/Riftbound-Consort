//
//  PlayRiftboundAPI+Unapproved.swift
//  Riftbound Companiokay
//
//  Operations beyond the reads and the report (docs/PLAYRIFTBOUND.md §4).
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

// MARK: - Stores

extension PlayRiftboundAPI {
    private nonisolated struct OrganizerIDVariables: Encodable, Sendable { let organizerId: String }
    private nonisolated struct IDVariables: Encodable, Sendable { let id: String }
    private nonisolated struct NoVariables: Encodable, Sendable {}
    private nonisolated struct Nothing: Decodable, Sendable {}

    /// The player's favourite stores (name and address only).
    func favoritedOrganizers(credentials: PlayRiftboundCredentials) async throws -> [CompeteOrganizer] {
        let data: FavoritedOrganizersData = try await query("FavoritedOrganizers", variables: NoVariables(), credentials: credentials)
        return data.favoritedOrganizers
    }

    func setFavorite(organizerID: String, on: Bool, credentials: PlayRiftboundCredentials) async throws {
        let _: Nothing = try await mutate(on ? "FavoriteOrganizer" : "UnfavoriteOrganizer",
                                          variables: OrganizerIDVariables(organizerId: organizerID), credentials: credentials)
    }

    /// Contact card and coordinates of a store. Public.
    func organizerSummary(id: String, credentials: PlayRiftboundCredentials?) async throws -> CompeteOrganizerSummary? {
        let data: OrganizerSummaryData = try await query("OrganizerSummary", variables: IDVariables(id: id), credentials: credentials)
        return data.organizerSummary
    }

    /// A store's upcoming events: the search centred on the store, kept to that organizer.
    func storeEvents(organizerID: String, latitude: Double, longitude: Double,
                     credentials: PlayRiftboundCredentials?) async throws -> [CompeteSearchResult] {
        let filter = SearchFilter(coords: .init(latitude: latitude, longitude: longitude),
                                  startDate: Self.searchStartDate(), distanceMeters: 2000,
                                  types: nil, formats: nil, playerFormats: nil, favoritedOrganizersOnly: nil)
        var results: [CompeteSearchResult] = []
        var after: String? = nil
        for _ in 0..<5 {
            let page: CompeteSearchData
            do {
                page = try await searchTournaments(filter: filter, sort: .date, after: after, first: 50, credentials: credentials)
            } catch {
                if after == nil { throw error }
                break   // a later page failed: keep the events already found
            }
            results += page.competeTournamentSearch.nodes.filter { $0.organizer?.id == organizerID }
            guard page.competeTournamentSearch.pageInfo?.hasNextPage == true,
                  let cursor = page.competeTournamentSearch.pageInfo?.endCursor else { break }
            after = cursor
        }
        return results
    }
}

nonisolated struct FavoritedOrganizersData: Decodable, Sendable {
    let favoritedOrganizers: [CompeteOrganizer]
}

nonisolated struct OrganizerSummaryData: Decodable, Sendable {
    let organizerSummary: CompeteOrganizerSummary?
}

nonisolated struct CompeteOrganizerSummary: Decodable, Sendable {
    let id: String
    let name: String
    let email: String?
    let website: String?
    let phone: Phone?
    let physicalAddress: CompeteOrganizer.Address?
    let type: String?

    nonisolated struct Phone: Decodable, Sendable {
        let countryDialingCode: String?
        let number: String?
        var display: String? {
            guard let number, !number.isEmpty else { return nil }
            return [countryDialingCode.map { $0.hasPrefix("+") ? $0 : "+" + $0 }, number].compactMap { $0 }.joined(separator: " ")
        }
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
