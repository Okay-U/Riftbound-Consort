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
nonisolated struct PlayerTournamentEntry: Decodable, Sendable, Hashable {
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
        let formattedAddress: String?
        let latitude: Double?
        let longitude: Double?
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
    let description: String?
    let tournamentProgram: Program?
    let startsAt: Date?
    let endsAt: Date?
    let registrationEndAt: Date?
    let registrationPolicy: String?
    let pricing: String?
    let entryFee: CompeteTournamentSummary.EntryFee?
    let registrantCounts: [CompeteTournamentSummary.RegistrantCount]?
    let config: Config?
    let stages: [Stage]
    let tournamentRegistrants: [Registrant]?
    let tournamentParticipants: [Participant]?

    nonisolated struct Program: Decodable, Sendable {
        let id: String?
        let programName: String?
    }

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
        /// Final placement, filled once the section is over.
        let ranks: [Rank]?
    }

    nonisolated struct Rank: Decodable, Sendable {
        let position: Int?
        let esportsTeamId: String?
    }

    nonisolated struct Round: Decodable, Sendable {
        let roundNumber: Int
        let status: String?
        let startedAt: Date?
        /// Minutes. Decoded leniently: Riot has sent numbers as strings elsewhere.
        let roundDuration: Int?
        let byeTeamIds: [String]?
        let droppedTeamIds: [String]?
        let matches: [Match]
        let endOfRoundStandings: [Standing]?

        private enum Keys: String, CodingKey {
            case roundNumber, status, startedAt, roundDuration, byeTeamIds, droppedTeamIds, matches, endOfRoundStandings
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            roundNumber = Lenient.int(c, .roundNumber) ?? 0
            status = try c.decodeIfPresent(String.self, forKey: .status)
            startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt)
            roundDuration = Lenient.int(c, .roundDuration)
            byeTeamIds = try c.decodeIfPresent([String].self, forKey: .byeTeamIds)
            droppedTeamIds = try c.decodeIfPresent([String].self, forKey: .droppedTeamIds)
            matches = try c.decodeIfPresent([Match].self, forKey: .matches) ?? []
            endOfRoundStandings = try c.decodeIfPresent([Standing].self, forKey: .endOfRoundStandings)
        }
    }

    nonisolated struct Match: Decodable, Sendable {
        let esportsMatchId: String
        let status: String?
        let config: MatchConfig?
        let teams: [Team]
        let games: [Game]?
        let teamOutcomes: [Outcome]?

        var isComplete: Bool { status == "COMPLETED" || !(teamOutcomes ?? []).isEmpty }
    }

    /// `CompeteBestOfConfig` / `CompetePlayAllConfig`: both carry `count`.
    nonisolated struct MatchConfig: Decodable, Sendable {
        let count: Int?
    }

    nonisolated struct Team: Decodable, Sendable {
        let esportsTeamId: String
        let players: [Player]
    }

    nonisolated struct Player: Decodable, Sendable {
        let id: String
        let displayName: String?
    }

    nonisolated struct Game: Decodable, Sendable {
        let esportsGameId: String
        let number: Int?
        let teamOutcomes: [Outcome]?
    }

    nonisolated struct Outcome: Decodable, Sendable {
        let esportsTeamId: String?
        /// WIN / LOSS / DRAW …; nil while a game is still open.
        let outcome: String?
        var isWin: Bool { outcome?.uppercased().contains("WIN") == true }
    }

    nonisolated struct Standing: Decodable, Sendable {
        let esportsTeamId: String
        let rank: Int?
        let matchPoints: Int?
        let matchWins: Int?
        let matchLosses: Int?
        let matchDraws: Int?
        let matchWinPercentage: Double?
        let opponentMatchWinPercentage: Double?
        let gameWinPercentage: Double?
        let opponentGameWinPercentage: Double?

        var record: String { "\(matchWins ?? 0)-\(matchLosses ?? 0)-\(matchDraws ?? 0)" }

        private enum Keys: String, CodingKey {
            case esportsTeamId, rank, matchPoints, matchWins, matchLosses, matchDraws
            case matchWinPercentage, opponentMatchWinPercentage, gameWinPercentage, opponentGameWinPercentage
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            esportsTeamId = try c.decodeIfPresent(String.self, forKey: .esportsTeamId) ?? ""
            rank = Lenient.int(c, .rank)
            matchPoints = Lenient.int(c, .matchPoints)
            matchWins = Lenient.int(c, .matchWins)
            matchLosses = Lenient.int(c, .matchLosses)
            matchDraws = Lenient.int(c, .matchDraws)
            matchWinPercentage = Lenient.double(c, .matchWinPercentage)
            opponentMatchWinPercentage = Lenient.double(c, .opponentMatchWinPercentage)
            gameWinPercentage = Lenient.double(c, .gameWinPercentage)
            opponentGameWinPercentage = Lenient.double(c, .opponentGameWinPercentage)
        }
    }

    nonisolated struct Registrant: Decodable, Sendable {
        let id: String
        let status: String?
        let checkedIn: Bool?
        let player: RegistrantPlayer?
    }

    nonisolated struct RegistrantPlayer: Decodable, Sendable {
        let id: String
        let displayName: String?
        let tagLine: String?
    }

    nonisolated struct Participant: Decodable, Sendable {
        /// Participant id; this is what `SubmitGameResults` wants as `winnerParticipantId`.
        let id: String
        let esportsTeamId: String?
        let status: String?
        /// Seed, as the site shows it (#n).
        let position: Int?
        let player: RegistrantPlayer?

        private enum Keys: String, CodingKey { case id, esportsTeamId, status, position, player }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            id = try c.decode(String.self, forKey: .id)
            esportsTeamId = try c.decodeIfPresent(String.self, forKey: .esportsTeamId)
            status = try c.decodeIfPresent(String.self, forKey: .status)
            position = Lenient.int(c, .position)
            player = try c.decodeIfPresent(RegistrantPlayer.self, forKey: .player)
        }
    }

    func participant(teamID: String) -> Participant? {
        (tournamentParticipants ?? []).first { $0.esportsTeamId == teamID }
    }

    func teamID(playerID: String) -> String? {
        (tournamentParticipants ?? []).first { $0.player?.id == playerID }?.esportsTeamId
    }

    /// Display name of a team, from the participant list or any match it played.
    func teamName(_ teamID: String) -> String {
        if let name = participant(teamID: teamID)?.player?.displayName { return name }
        for round in rounds {
            for match in round.matches {
                if let team = match.teams.first(where: { $0.esportsTeamId == teamID }),
                   let name = team.players.first?.displayName { return name }
            }
        }
        return "Player"
    }

    /// Final placement from the section ranks, else the rank after the last round.
    func finalRank(teamID: String) -> Int? {
        if let rank = stages.flatMap(\.sections).compactMap(\.ranks).joined().first(where: { $0.esportsTeamId == teamID }),
           let position = rank.position {
            return position
        }
        return rounds.last?.endOfRoundStandings?.first { $0.esportsTeamId == teamID }?.rank
    }

    func standing(teamID: String, after round: Round) -> Standing? {
        round.endOfRoundStandings?.first { $0.esportsTeamId == teamID }
    }

    var hasRounds: Bool { !rounds.isEmpty }

    var webURL: URL? { URL(string: "https://playriftbound.com/en-US/events/\(id)") }

    /// All rounds in play order.
    var rounds: [Round] { stages.flatMap(\.sections).flatMap(\.rounds).sorted { $0.roundNumber < $1.roundNumber } }

    /// Compete player id for a Riot ID, from the registrant list or, once the
    /// event runs, the participant list.
    func playerID(gameName: String, tagLine: String?) -> String? {
        func matches(_ p: RegistrantPlayer?) -> Bool {
            guard let p, let displayName = p.displayName else { return false }
            let nameMatches = displayName.caseInsensitiveCompare(gameName) == .orderedSame
            let tagMatches = tagLine == nil || p.tagLine == nil || p.tagLine!.caseInsensitiveCompare(tagLine!) == .orderedSame
            return nameMatches && tagMatches
        }
        return (tournamentRegistrants ?? []).first { matches($0.player) }?.player?.id
            ?? (tournamentParticipants ?? []).first { matches($0.player) }?.player?.id
    }
}

/// The signed-in player's situation in the latest round of a tournament.
nonisolated struct CompetePairing: Sendable, Equatable {
    let roundNumber: Int
    /// Riot's schema has no table field. The site numbers tables by ascending match id within the
    /// round (verified against a live event, 2026-10-05: ids …840/…844/…848 = tables 1/2/3).
    let tableNumber: Int?
    let matchID: String?
    let opponentName: String?
    let isBye: Bool
    let isComplete: Bool
    /// What a result report needs: game ids in play order, both participant ids, series length.
    let gameIDs: [String]
    let myParticipantID: String?
    let opponentParticipantID: String?
    let bestOf: Int
    let myTeamID: String?
    let opponentTeamID: String?
    /// Games won so far, from the per-game outcomes.
    let myGameWins: Int
    let opponentGameWins: Int
    let result: Result?

    enum Result: Sendable, Equatable { case win, loss, draw }

    /// "2–1", or nothing before a game is in.
    var scoreText: String? { myGameWins + opponentGameWins > 0 ? "\(myGameWins)–\(opponentGameWins)" : nil }

    var isReportable: Bool {
        !isBye && !isComplete && matchID != nil && !gameIDs.isEmpty
            && myParticipantID != nil && opponentParticipantID != nil
    }

    static func resolve(in tournament: CompeteTournament, playerID: String) -> CompetePairing? {
        guard let round = tournament.rounds.last else { return nil }
        return resolve(in: tournament, playerID: playerID, round: round)
    }

    static func resolve(in tournament: CompeteTournament, playerID: String, round: CompeteTournament.Round) -> CompetePairing? {
        let myTeamID = tournament.teamID(playerID: playerID)
        // Same-length numeric strings, so a (count, lexical) sort equals a numeric sort without overflow.
        let byTable = round.matches.sorted {
            ($0.esportsMatchId.count, $0.esportsMatchId) < ($1.esportsMatchId.count, $1.esportsMatchId)
        }
        if let index = byTable.firstIndex(where: { $0.teams.contains { $0.players.contains { $0.id == playerID } } }) {
            let match = byTable[index]
            let myTeam = match.teams.first { $0.players.contains { $0.id == playerID } }
            let oppTeam = match.teams.first { !$0.players.contains { $0.id == playerID } }
            let sortedGames = (match.games ?? []).sorted { ($0.number ?? 0) < ($1.number ?? 0) }
            func wins(_ teamID: String?) -> Int {
                guard let teamID else { return 0 }
                return sortedGames.filter { game in
                    (game.teamOutcomes ?? []).contains { $0.esportsTeamId == teamID && $0.isWin }
                }.count
            }
            let mine = myTeam?.esportsTeamId, theirs = oppTeam?.esportsTeamId
            let result: Result? = (match.teamOutcomes ?? []).first { $0.esportsTeamId == mine }.flatMap {
                guard let o = $0.outcome?.uppercased() else { return nil }
                return o.contains("WIN") ? .win : o.contains("LOS") ? .loss : o.contains("DRAW") || o.contains("TIE") ? .draw : nil
            }
            return CompetePairing(roundNumber: round.roundNumber, tableNumber: index + 1, matchID: match.esportsMatchId,
                                  opponentName: oppTeam?.players.first?.displayName ?? oppTeam.map { tournament.teamName($0.esportsTeamId) },
                                  isBye: false, isComplete: match.isComplete,
                                  gameIDs: sortedGames.map(\.esportsGameId),
                                  myParticipantID: mine.flatMap { tournament.participant(teamID: $0)?.id },
                                  opponentParticipantID: theirs.flatMap { tournament.participant(teamID: $0)?.id },
                                  bestOf: match.config?.count ?? max(sortedGames.count, 1),
                                  myTeamID: mine, opponentTeamID: theirs,
                                  myGameWins: wins(mine), opponentGameWins: wins(theirs), result: result)
        }
        if let myTeamID, (round.byeTeamIds ?? []).contains(myTeamID) {
            return CompetePairing(roundNumber: round.roundNumber, tableNumber: nil, matchID: nil,
                                  opponentName: nil, isBye: true, isComplete: true,
                                  gameIDs: [], myParticipantID: nil, opponentParticipantID: nil, bestOf: 1,
                                  myTeamID: myTeamID, opponentTeamID: nil, myGameWins: 0, opponentGameWins: 0, result: .win)
        }
        return nil
    }
}


// MARK: - Lenient decoding

/// Riot's gateway has returned numbers as strings and nulls where the schema says a value;
/// these readers accept number, numeric string, null or a missing key instead of failing the
/// whole payload.
nonisolated enum Lenient {
    static func int<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Int? {
        if let v = try? c.decodeIfPresent(Int.self, forKey: key) { return v }
        if let v = try? c.decodeIfPresent(Double.self, forKey: key) { return Int(v) }
        if let s = try? c.decodeIfPresent(String.self, forKey: key) { return Int(s) ?? Double(s).map { Int($0) } }
        return nil
    }

    static func double<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Double? {
        if let v = try? c.decodeIfPresent(Double.self, forKey: key) { return v }
        if let s = try? c.decodeIfPresent(String.self, forKey: key) { return Double(s.replacingOccurrences(of: "%", with: "")) }
        return nil
    }
}
