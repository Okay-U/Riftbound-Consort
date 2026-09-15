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

// MARK: - GetCompeteTournamentForRiftboundPlayer

nonisolated struct CompeteTournamentsData: Decodable, Sendable {
    let competeTournaments: [CompeteTournament]
}

/// One tournament with its bracket: stages → sections → rounds → matches. Field names follow
/// the `CompeteRb*` fragments in docs/PLAYRIFTBOUND.md.
nonisolated struct CompeteTournament: Decodable, Sendable {
    let id: String
    let name: String
    let startsAt: Date?
    let endsAt: Date?
    let registrationPolicy: String?
    let pricing: String?
    let entryFee: CompeteTournamentSummary.EntryFee?
    let registrantCounts: [CompeteTournamentSummary.RegistrantCount]?
    let config: Config?
    let stages: [Stage]
    let tournamentRegistrants: [Registrant]?
    let tournamentParticipants: [Participant]?

    nonisolated struct Config: Decodable, Sendable {
        let tournamentType: String?
        let format: String?
        let playerFormat: String?
        let structure: String?
        let matchFormat: String?
        let participantCapacity: Int?
        let roundCount: Int?
    }

    nonisolated struct Stage: Decodable, Sendable {
        let esportsStageId: String?
        let name: String?
        let sections: [Section]
    }

    nonisolated struct Section: Decodable, Sendable {
        let esportsSectionId: String?
        let rounds: [Round]
    }

    nonisolated struct Round: Decodable, Sendable {
        let roundNumber: Int
        let status: String?
        let startedAt: Date?
        let roundDuration: Int?
        let byeTeamIds: [String]?
        let droppedTeamIds: [String]?
        let matches: [Match]
        let endOfRoundStandings: [Standing]?
    }

    nonisolated struct Match: Decodable, Sendable {
        let esportsMatchId: String
        let status: String?
        let teams: [Team]
        let games: [Game]?
        let teamOutcomes: [Outcome]?

        var isComplete: Bool { status == "COMPLETED" || !(teamOutcomes ?? []).isEmpty }
    }

    nonisolated struct Team: Decodable, Sendable {
        let esportsTeamId: String
        let players: [Player]
    }

    nonisolated struct Player: Decodable, Sendable {
        let id: String
        let displayName: String
    }

    nonisolated struct Game: Decodable, Sendable {
        let esportsGameId: String
        let number: Int?
        let teamOutcomes: [Outcome]?
    }

    nonisolated struct Outcome: Decodable, Sendable {
        let esportsTeamId: String
        let outcome: String
    }

    nonisolated struct Standing: Decodable, Sendable {
        let esportsTeamId: String
        let rank: Int?
        let matchPoints: Int?
        let matchWins: Int?
        let matchLosses: Int?
        let matchDraws: Int?
    }

    nonisolated struct Registrant: Decodable, Sendable {
        let id: String
        let status: String?
        let checkedIn: Bool?
        let player: RegistrantPlayer?
    }

    nonisolated struct RegistrantPlayer: Decodable, Sendable {
        let id: String
        let displayName: String
        let tagLine: String?
    }

    nonisolated struct Participant: Decodable, Sendable {
        let esportsTeamId: String?
        let status: String?
        let player: RegistrantPlayer?
    }

    var webURL: URL? { URL(string: "https://playriftbound.com/en-US/events/\(id)") }

    /// All rounds in play order.
    var rounds: [Round] { stages.flatMap(\.sections).flatMap(\.rounds).sorted { $0.roundNumber < $1.roundNumber } }

    /// Compete player id for a Riot ID, taken from the registrant list.
    func playerID(gameName: String, tagLine: String?) -> String? {
        let match = (tournamentRegistrants ?? []).first { r in
            guard let p = r.player else { return false }
            let nameMatches = p.displayName.caseInsensitiveCompare(gameName) == .orderedSame
            let tagMatches = tagLine == nil || p.tagLine == nil || p.tagLine!.caseInsensitiveCompare(tagLine!) == .orderedSame
            return nameMatches && tagMatches
        }
        return match?.player?.id
    }
}

/// The signed-in player's situation in the latest round of a tournament.
nonisolated struct CompetePairing: Sendable, Equatable {
    let roundNumber: Int
    /// Position of the match within the round, 1-based. Riot's schema has no table field; the
    /// site's own numbering is unverified until a live event (ponytail: swap for the real rule then).
    let tableNumber: Int?
    let matchID: String?
    let opponentName: String?
    let isBye: Bool
    let isComplete: Bool

    static func resolve(in tournament: CompeteTournament, playerID: String) -> CompetePairing? {
        guard let round = tournament.rounds.last else { return nil }
        let myTeamID = (tournament.tournamentParticipants ?? []).first { $0.player?.id == playerID }?.esportsTeamId
        if let index = round.matches.firstIndex(where: { $0.teams.contains { $0.players.contains { $0.id == playerID } } }) {
            let match = round.matches[index]
            let opponent = match.teams.first { !$0.players.contains { $0.id == playerID } }?.players.first?.displayName
            return CompetePairing(roundNumber: round.roundNumber, tableNumber: index + 1, matchID: match.esportsMatchId,
                                  opponentName: opponent, isBye: false, isComplete: match.isComplete)
        }
        if let myTeamID, (round.byeTeamIds ?? []).contains(myTeamID) {
            return CompetePairing(roundNumber: round.roundNumber, tableNumber: nil, matchID: nil,
                                  opponentName: nil, isBye: true, isComplete: true)
        }
        return nil
    }
}
