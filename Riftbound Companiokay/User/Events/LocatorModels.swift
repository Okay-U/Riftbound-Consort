//
//  LocatorModels.swift
//  Riftbound Companiokay
//
//  Codable models for the Riftbound Locator (UVS Games Hydra) API.
//  Only the fields the Events tab needs are decoded; unknown keys are ignored.
//  Decoder uses .convertFromSnakeCase, so snake_case JSON maps to camelCase here.
//

import Foundation

// MARK: - Pagination

nonisolated struct LocatorPage<Item: Decodable & Sendable>: Decodable, Sendable {
    let total: Int?
    let results: [Item]
}

// MARK: - Event

nonisolated struct LocatorEvent: Decodable, Sendable, Identifiable {
    let id: Int
    let name: String
    let eventStatus: String?
    let displayStatus: String?
    let fullAddress: String?
    let startingPlayerCount: Int?
    let numberOfRounds: Int?
    let topCutSize: Int?
    let tournamentPhases: [LocatorPhase]

    /// A phase you must rank into (the elimination/cut phase), if any.
    var cutPhase: LocatorPhase? {
        tournamentPhases.first { ($0.rankRequiredToEnterPhase ?? 0) > 0 }
    }

    /// Top-cut size: the explicit field if set, else the rank gate on the cut phase.
    var resolvedCutSize: Int? {
        if let size = topCutSize, size > 0 { return size }
        return cutPhase?.rankRequiredToEnterPhase
    }

    var hasTopCut: Bool { (resolvedCutSize ?? 0) > 0 }

    /// The Swiss phase (the one that feeds the cut), else the first phase.
    var swissPhase: LocatorPhase? {
        tournamentPhases.first(where: { ($0.roundType ?? "").uppercased() == "SWISS" })
            ?? tournamentPhases.first
    }

    var swissRoundsTotal: Int? { swissPhase?.numberOfRounds ?? numberOfRounds }

    var swissRoundsCompleted: Int {
        swissPhase?.rounds.filter { ($0.status ?? "").uppercased() == "COMPLETE" }.count ?? 0
    }

    /// Swiss rounds still to play (the in-progress round counts as remaining).
    var swissRoundsLeft: Int? {
        guard let total = swissRoundsTotal else { return nil }
        return max(0, total - swissRoundsCompleted)
    }

    /// Best-of for the first phase: 2 = best of 3, 1 = best of 1.
    var maxGameWinsPerMatch: Int? {
        tournamentPhases.first?.effectiveMaximumNumberOfGameWinsPerMatch
    }

    var isBestOfThree: Bool { (maxGameWinsPerMatch ?? 1) >= 2 }

    /// All rounds across every phase, in order.
    var allRounds: [LocatorRound] { tournamentPhases.flatMap(\.rounds) }

    /// The round being played now, else the latest one with pairings.
    var currentRound: LocatorRound? {
        let rounds = allRounds
        return rounds.first(where: { $0.status == "IN_PROGRESS" })
            ?? rounds.last(where: { $0.pairingsStatus == "GENERATED" })
            ?? rounds.last
    }
}

nonisolated struct LocatorPhase: Decodable, Sendable, Identifiable {
    let id: Int
    let phaseName: String?
    let roundType: String?
    let numberOfRounds: Int?
    let rankRequiredToEnterPhase: Int?   // e.g. 8 on the elimination phase = top-cut size
    let effectiveMaximumNumberOfGameWinsPerMatch: Int?
    let rounds: [LocatorRound]
}

nonisolated struct LocatorRound: Decodable, Sendable, Identifiable {
    let id: Int
    let roundNumber: Int
    let status: String?
    let pairingsStatus: String?
    let standingsStatus: String?
}

// MARK: - Navigation

/// Pushes the event screen, carrying your per-event alias so the screen can
/// identify "you" in standings even when you have no live match this round.
nonisolated struct EventRoute: Hashable, Sendable {
    let id: Int
    let alias: String?
}

// MARK: - My events (registrations)

nonisolated struct LocatorUserEventStatus: Decodable, Sendable, Identifiable {
    let id: Int
    let registrationStatus: String?
    let queueCheckInStatus: String?
    let bestIdentifier: String?
    let event: LocatorEventSummary
}

nonisolated struct LocatorEventSummary: Decodable, Sendable, Identifiable {
    let id: Int
    let name: String
    let startDatetime: Date?
    let endDatetime: Date?
    let displayStatus: String?
    let fullHeaderImageUrl: String?

    var isLive: Bool { (displayStatus ?? "").lowercased().contains("progress") }
    var isFinished: Bool {
        let status = (displayStatus ?? "").lowercased()
        return status == "complete" || status == "canceled" || status == "cancelled"
    }
}

// MARK: - Pairings (public "TV" feed)

nonisolated struct LocatorMatch: Decodable, Sendable, Identifiable {
    let tableNumber: Int?
    let podNumber: Int?
    let status: String?
    let matchIsBye: Bool?
    let players: [LocatorMatchPlayer]

    var isBye: Bool { (matchIsBye ?? false) || players.count == 1 }

    var id: String {
        "\(tableNumber ?? -1)|" + players.map(\.tvDisplayName).joined(separator: "|")
    }
}

nonisolated struct LocatorMatchPlayer: Decodable, Sendable {
    let tvDisplayName: String
    let matchesWon: Int?
    let matchesLost: Int?
    let matchesDrawn: Int?
    let gamesWon: Int?
    let isWinner: Bool?
    let playerOrder: Int?
    let profileImageUrl: String?

    var record: String {
        let drawn = matchesDrawn ?? 0
        let base = "\(matchesWon ?? 0)-\(matchesLost ?? 0)"
        return drawn > 0 ? base + "-\(drawn)" : base
    }
}

// MARK: - My match (authed, per round)

nonisolated struct LocatorMyMatch: Decodable, Sendable {
    let id: Int
    let tableNumber: Int?
    let status: String?
    let tournamentRoundId: Int?
    let playerMatchRelationships: [LocatorMatchRelationship]
}

nonisolated struct LocatorMatchRelationship: Decodable, Sendable, Identifiable {
    let id: Int                       // player_match_relationship id — used when reporting
    let playerOrder: Int?
    let isStartingPlayer: Bool?
    let userEventStatus: LocatorMatchUserStatus

    var displayName: String { userEventStatus.bestIdentifier ?? "Player" }
    var record: String {
        let s = userEventStatus
        return "\(s.matchesWon ?? 0)-\(s.matchesLost ?? 0)-\(s.matchesDrawn ?? 0)"
    }
}

nonisolated struct LocatorMatchUserStatus: Decodable, Sendable {
    let id: Int
    let bestIdentifier: String?
    let matchesWon: Int?
    let matchesLost: Int?
    let matchesDrawn: Int?
    let totalMatchPoints: Int?
    let user: LocatorMatchUser?
}

nonisolated struct LocatorMatchUser: Decodable, Sendable {
    let id: Int
    let bestIdentifier: String?
    let gameUserProfilePictureUrl: String?
}

/// My match resolved against the signed-in user id.
nonisolated struct ResolvedMyMatch: Sendable, Identifiable {
    let matchID: Int
    let tableNumber: Int?
    let status: String?
    let me: LocatorMatchRelationship
    let opponent: LocatorMatchRelationship?
    let isBye: Bool

    var id: Int { matchID }
    var isComplete: Bool { (status ?? "").uppercased() == "COMPLETE" }

    init?(_ match: LocatorMyMatch, myUserID: Int?) {
        let relationships = match.playerMatchRelationships
        guard let myUserID,
              let mine = relationships.first(where: { $0.userEventStatus.user?.id == myUserID })
        else { return nil }
        self.matchID = match.id
        self.tableNumber = match.tableNumber
        self.status = match.status
        self.me = mine
        self.opponent = relationships.first(where: { $0.id != mine.id })
        self.isBye = relationships.count <= 1
    }
}

// MARK: - Standings (public "TV" feed)

nonisolated struct LocatorStanding: Decodable, Sendable, Identifiable {
    let rank: Int
    let tvDisplayName: String
    let matchesWon: Int?
    let matchesLost: Int?
    let matchesDrawn: Int?
    let totalMatchPoints: Int?
    let opponentMatchWinPercentage: Double?

    var id: Int { rank }

    var record: String {
        "\(matchesWon ?? 0)-\(matchesLost ?? 0)-\(matchesDrawn ?? 0)"
    }

    var omwText: String {
        guard let value = opponentMatchWinPercentage else { return "—" }
        return "\(Int((value * 100).rounded()))%"
    }
}
