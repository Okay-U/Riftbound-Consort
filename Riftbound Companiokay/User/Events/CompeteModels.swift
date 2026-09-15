//
//  CompeteModels.swift
//  Riftbound Companiokay
//
//  Response types for the PlayRiftbound (Riot "Compete") GraphQL operations the
//  app is approved to use with the player's own session. Shapes follow the
//  persisted documents recorded in docs/PLAYRIFTBOUND.md; every field the app
//  does not need is left out, unknown fields are ignored by Decodable.
//

import Foundation

// MARK: - GraphQL envelope

nonisolated struct GraphQLEnvelope<T: Decodable & Sendable>: Decodable, Sendable {
    let data: T?
    let errors: [GraphQLError]?
}

nonisolated struct GraphQLError: Decodable, Sendable {
    let message: String
    let extensions: Extensions?

    nonisolated struct Extensions: Decodable, Sendable {
        let code: String?
    }
}

// MARK: - Relay paging

nonisolated struct CompeteConnection<Node: Decodable & Sendable>: Decodable, Sendable {
    let edges: [Edge]
    let pageInfo: PageInfo?

    nonisolated struct Edge: Decodable, Sendable {
        let cursor: String?
        let node: Node?
    }

    nonisolated struct PageInfo: Decodable, Sendable {
        let endCursor: String?
        let hasNextPage: Bool
    }

    var nodes: [Node] { edges.compactMap(\.node) }
}

// MARK: - PlayerTournaments

nonisolated struct PlayerTournamentsData: Decodable, Sendable {
    let playerTournaments: PlayerTournaments

    nonisolated struct PlayerTournaments: Decodable, Sendable {
        let upcoming: CompeteConnection<PlayerTournamentEntry>
        let past: CompeteConnection<PlayerTournamentEntry>
    }
}

/// One `RbPlayerTournamentResult`: the tournament plus the store running it.
nonisolated struct PlayerTournamentEntry: Decodable, Sendable {
    let organizer: CompeteOrganizer?
    let tournament: CompeteTournamentSummary
}

nonisolated struct CompeteOrganizer: Decodable, Sendable, Hashable {
    let id: String
    let name: String
    let isFavorited: Bool?
    let physicalAddress: Address?

    nonisolated struct Address: Decodable, Sendable, Hashable {
        let city: String?
        let adminArea1: String?
    }
}

nonisolated struct CompeteTournamentSummary: Decodable, Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let startsAt: Date?
    let pricing: String?
    let entryFee: EntryFee?
    let registrantCounts: [RegistrantCount]?
    let config: Config?

    nonisolated struct EntryFee: Decodable, Sendable, Hashable {
        let currency: String
        let minorUnits: Int
    }

    nonisolated struct RegistrantCount: Decodable, Sendable, Hashable {
        let status: String
        let count: Int
    }

    nonisolated struct Config: Decodable, Sendable, Hashable {
        let tournamentType: String?
        let format: String?
        let playerFormat: String?
        let participantCapacity: Int?
    }

    var registeredCount: Int {
        registrantCounts?.first { $0.status == "REGISTERED" }?.count ?? 0
    }

    /// Player page for this tournament on PlayRiftbound, for deep links into the New Events segment.
    var webURL: URL? { URL(string: "https://playriftbound.com/en-US/events/\(id)") }
}
