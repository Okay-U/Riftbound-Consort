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

        private enum Keys: String, CodingKey { case cursor, node }

        // A node of an unexpected union member (or with a field we cannot read) drops out
        // of the list instead of failing the whole page.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            cursor = try? c.decodeIfPresent(String.self, forKey: .cursor)
            node = try? c.decodeIfPresent(Node.self, forKey: .node)
        }
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

        private enum Keys: String, CodingKey { case currency, minorUnits }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            currency = (try? c.decodeIfPresent(String.self, forKey: .currency)) ?? "EUR"
            minorUnits = Lenient.int(c, .minorUnits) ?? 0
        }
    }

    nonisolated struct RegistrantCount: Decodable, Sendable, Hashable {
        let status: String
        let count: Int

        private enum Keys: String, CodingKey { case status, count }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            status = (try? c.decodeIfPresent(String.self, forKey: .status)) ?? ""
            count = Lenient.int(c, .count) ?? 0
        }
    }

    nonisolated struct Config: Decodable, Sendable, Hashable {
        let tournamentType: String?
        let format: String?
        let playerFormat: String?
        let participantCapacity: Int?

        private enum Keys: String, CodingKey { case tournamentType, format, playerFormat, participantCapacity }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            tournamentType = try? c.decodeIfPresent(String.self, forKey: .tournamentType)
            format = try? c.decodeIfPresent(String.self, forKey: .format)
            playerFormat = try? c.decodeIfPresent(String.self, forKey: .playerFormat)
            participantCapacity = Lenient.int(c, .participantCapacity)
        }
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

        private enum Keys: String, CodingKey {
            case tournamentType, format, playerFormat, structure, matchFormat, participantCapacity, roundCount
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            tournamentType = try? c.decodeIfPresent(String.self, forKey: .tournamentType)
            format = try? c.decodeIfPresent(String.self, forKey: .format)
            playerFormat = try? c.decodeIfPresent(String.self, forKey: .playerFormat)
            structure = try? c.decodeIfPresent(String.self, forKey: .structure)
            matchFormat = try? c.decodeIfPresent(String.self, forKey: .matchFormat)
            participantCapacity = Lenient.int(c, .participantCapacity)
            roundCount = Lenient.int(c, .roundCount)
        }
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

        private enum Keys: String, CodingKey { case position, esportsTeamId }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            position = Lenient.int(c, .position)
            esportsTeamId = try? c.decodeIfPresent(String.self, forKey: .esportsTeamId)
        }
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
        /// Riot's own table number (in the document since 2026-10); nil on older ids.
        let tableNumber: Int?
        let status: String?
        let config: MatchConfig?
        let teams: [Team]
        let games: [Game]?
        let teamOutcomes: [Outcome]?

        var isComplete: Bool { status == "COMPLETED" || !(teamOutcomes ?? []).isEmpty }

        private enum Keys: String, CodingKey { case esportsMatchId, tableNumber, status, config, teams, games, teamOutcomes }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            esportsMatchId = try c.decode(String.self, forKey: .esportsMatchId)
            tableNumber = Lenient.int(c, .tableNumber)
            status = try c.decodeIfPresent(String.self, forKey: .status)
            config = try c.decodeIfPresent(MatchConfig.self, forKey: .config)
            teams = try c.decodeIfPresent([Team].self, forKey: .teams) ?? []
            games = try c.decodeIfPresent([Game].self, forKey: .games)
            teamOutcomes = try c.decodeIfPresent([Outcome].self, forKey: .teamOutcomes)
        }
    }

    /// Matches of a round in table order: Riot's `tableNumber` when the document carries it,
    /// else ascending match id (verified against the site's numbering on three rounds).
    nonisolated static func tableOrder(_ matches: [Match]) -> [(table: Int, match: Match)] {
        if matches.allSatisfy({ $0.tableNumber != nil }) {
            return matches.sorted { ($0.tableNumber ?? 0) < ($1.tableNumber ?? 0) }.map { ($0.tableNumber ?? 0, $0) }
        }
        let byID = matches.sorted { ($0.esportsMatchId.count, $0.esportsMatchId) < ($1.esportsMatchId.count, $1.esportsMatchId) }
        return byID.enumerated().map { ($0.offset + 1, $0.element) }
    }

    /// `CompeteBestOfConfig` / `CompetePlayAllConfig`: both carry `count`.
    nonisolated struct MatchConfig: Decodable, Sendable {
        let count: Int?

        private enum Keys: String, CodingKey { case count }
        init(from decoder: Decoder) throws {
            count = Lenient.int(try decoder.container(keyedBy: Keys.self), .count)
        }
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

        private enum Keys: String, CodingKey { case esportsGameId, number, teamOutcomes }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            esportsGameId = try c.decode(String.self, forKey: .esportsGameId)
            number = Lenient.int(c, .number)
            teamOutcomes = try? c.decodeIfPresent([Outcome].self, forKey: .teamOutcomes)
        }
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

        /// For standings computed on the device (CompeteStandings).
        init(esportsTeamId: String, rank: Int?, matchPoints: Int?, matchWins: Int?, matchLosses: Int?, matchDraws: Int?,
             matchWinPercentage: Double?, opponentMatchWinPercentage: Double?,
             gameWinPercentage: Double?, opponentGameWinPercentage: Double?) {
            self.esportsTeamId = esportsTeamId
            self.rank = rank
            self.matchPoints = matchPoints
            self.matchWins = matchWins
            self.matchLosses = matchLosses
            self.matchDraws = matchDraws
            self.matchWinPercentage = matchWinPercentage
            self.opponentMatchWinPercentage = opponentMatchWinPercentage
            self.gameWinPercentage = gameWinPercentage
            self.opponentGameWinPercentage = opponentGameWinPercentage
        }

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

    /// Over once Riot publishes final placements, or once every planned Swiss round is fully
    /// reported. (Not `endsAt`: that is the scheduled end and events run late.)
    var isFinished: Bool {
        if stages.flatMap(\.sections).contains(where: { !($0.ranks ?? []).isEmpty }) { return true }
        guard let planned = config?.roundCount, planned > 0, rounds.count >= planned,
              let last = rounds.last, !last.matches.isEmpty else { return false }
        return last.matches.allSatisfy(\.isComplete)
    }

    /// The player's registration as Riot reports it: participant status once the event runs
    /// (ACTIVE / DROPPED), registrant status before that.
    enum PlayerState: Equatable { case none, registered, waitlisted, active, dropped }

    func state(of playerID: String) -> PlayerState {
        if let participant = (tournamentParticipants ?? []).first(where: { $0.player?.id == playerID }) {
            return participant.status?.uppercased().contains("DROP") == true ? .dropped : .active
        }
        if let registrant = (tournamentRegistrants ?? []).first(where: { $0.player?.id == playerID }) {
            switch registrant.status?.uppercased() ?? "REGISTERED" {
            case let s where s.contains("WAIT"): return .waitlisted
            case let s where s.contains("REGISTER") && !s.contains("UNREGISTER") && !s.contains("DEREGISTER"): return .registered
            case let s where s.contains("CHECK"): return .registered
            default: return .none
            }
        }
        return .none
    }

    var webURL: URL? { URL(string: "https://playriftbound.com/en-US/events/\(id)") }

    /// All rounds in play order.
    var rounds: [Round] { stages.flatMap(\.sections).flatMap(\.rounds).sorted { $0.roundNumber < $1.roundNumber } }

    /// Compete player id for a Riot ID, from the registrant list or, once the
    /// event runs, the participant list.
    /// Riot IDs are only unique with the tag: an exact name + tag match wins; a name alone is
    /// accepted only when nobody else in the event has that name. Nil when it is ambiguous.
    func playerID(gameName: String, tagLine: String?) -> String? {
        var byID: [String: RegistrantPlayer] = [:]
        for p in (tournamentRegistrants ?? []).compactMap(\.player) + (tournamentParticipants ?? []).compactMap(\.player) {
            byID[p.id] = byID[p.id] ?? p
        }
        let named = byID.values.filter { $0.displayName?.caseInsensitiveCompare(gameName) == .orderedSame }
        if let tagLine {
            let exact = named.filter { $0.tagLine?.caseInsensitiveCompare(tagLine) == .orderedSame }
            if exact.count == 1 { return exact[0].id }
            if !exact.isEmpty { return nil }
            // Riot's data may omit the tag; fall back to the name only if it is unique and untagged.
            let untagged = named.filter { $0.tagLine == nil }
            return named.count == 1 && untagged.count == 1 ? untagged[0].id : nil
        }
        return named.count == 1 ? named[0].id : nil
    }
}

/// The signed-in player's situation in the latest round of a tournament.
nonisolated struct CompetePairing: Sendable, Equatable {
    let roundNumber: Int
    /// Riot's `tableNumber` where the document has it, else the site's rule of ascending match
    /// id within the round (verified 2026-10-05 and against the site's own numbers on 2026-10-20).
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
        let ordered = CompeteTournament.tableOrder(round.matches)
        if let slot = ordered.first(where: { $0.match.teams.contains { $0.players.contains { $0.id == playerID } } }) {
            let match = slot.match
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
            return CompetePairing(roundNumber: round.roundNumber, tableNumber: slot.table, matchID: match.esportsMatchId,
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
        if let v = try? c.decodeIfPresent(Double.self, forKey: key) { return clamp(v) }
        if let s = try? c.decodeIfPresent(String.self, forKey: key) {
            let trimmed = s.trimmingCharacters(in: .whitespaces)
            return Int(trimmed) ?? Double(trimmed).flatMap(clamp)
        }
        return nil
    }

    /// `Int(_: Double)` traps on NaN, infinity and out-of-range values from the network.
    private static func clamp(_ v: Double) -> Int? {
        guard v.isFinite, abs(v) < 1e15 else { return nil }
        return Int(v.rounded())
    }

    static func double<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Double? {
        if let v = try? c.decodeIfPresent(Double.self, forKey: key) { return v }
        if let s = try? c.decodeIfPresent(String.self, forKey: key) { return Double(s.replacingOccurrences(of: "%", with: "")) }
        return nil
    }
}
