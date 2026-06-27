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
    let nextPageNumber: Int?
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
    let queueStatus: String?
    let costInCents: Int?
    let currency: String?
    let settings: LocatorEventSettings?
    let tournamentPhases: [LocatorPhase]

    /// Registration is open (you can join; payment, if any, is in person).
    var isOpenForRegistration: Bool {
        (queueStatus ?? "").uppercased() == "ACCEPTING_SIGNUPS"
    }

    /// Event collects payment online (Stripe) — must register/pay on the website,
    /// not via our one-tap "pay in person" flow.
    var requiresOnlinePayment: Bool { settings?.paymentOnSpicerack == true }

    /// Event collects decklists on the platform (show the decklist card).
    var usesDecklists: Bool { settings?.decklistsOnSpicerack == true }

    /// Public web page for this event.
    var webURL: URL? { URL(string: "https://locator.riftbound.uvsgames.com/events/\(id)") }

    var priceText: String {
        guard let cents = costInCents, cents > 0 else { return "Free" }
        let amount = Double(cents) / 100
        let symbol = (currency == "EUR") ? "€" : (currency == "USD" ? "$" : "\(currency ?? "") ")
        return "\(symbol)\(String(format: "%.2f", amount))"
    }

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

    var isFinished: Bool {
        let status = (displayStatus ?? "").lowercased()
        return status == "complete" || status == "canceled" || status == "cancelled"
    }

    func phase(of round: LocatorRound) -> LocatorPhase? {
        tournamentPhases.first { $0.rounds.contains(where: { $0.id == round.id }) }
    }

    /// Phase-aware label for the current round. Swiss → "Round N of M";
    /// elimination → stage name (Final / Semifinal / Top N); nil when the
    /// event is finished or there's no active round. Round numbers run
    /// continuously across phases, so never mix an elim round with the Swiss total.
    var currentRoundLabel: String? {
        guard !isFinished, let round = currentRound, let phase = phase(of: round) else { return nil }
        if (phase.roundType ?? "").uppercased().contains("ELIMINATION") {
            return Self.eliminationStage(of: round, in: phase)
        }
        if let total = phase.numberOfRounds {
            return "Round \(round.roundNumber) of \(total)"
        }
        return "Round \(round.roundNumber)"
    }

    /// Final / Semifinal / Quarterfinal / Top N from the round's position in the bracket.
    private static func eliminationStage(of round: LocatorRound, in phase: LocatorPhase) -> String {
        let ordered = phase.rounds.sorted { $0.roundNumber < $1.roundNumber }
        guard let index = ordered.firstIndex(where: { $0.id == round.id }) else { return "Top cut" }
        switch ordered.count - 1 - index {
        case 0:  return "Final"
        case 1:  return "Semifinal"
        case 2:  return "Quarterfinal"
        case let fromEnd: return "Top \(1 << (fromEnd + 1))"
        }
    }
}

nonisolated struct LocatorEventSettings: Decodable, Sendable {
    let paymentInStore: Bool?
    let paymentOnSpicerack: Bool?
    let decklistStatus: String?
    let decklistsOnSpicerack: Bool?
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

/// Pushes the store search screen.
nonisolated struct StoreSearchRoute: Hashable, Sendable {}

/// Pushes a store's detail screen (game-store UUID).
nonisolated struct StoreRoute: Hashable, Sendable {
    let id: String
}

/// Pushes the favorite-stores events calendar.
nonisolated struct StoreCalendarRoute: Hashable, Sendable {}

// MARK: - My events (registrations)

nonisolated struct LocatorUserEventStatus: Decodable, Sendable, Identifiable {
    let id: Int
    let registrationStatus: String?
    let queueCheckInStatus: String?
    let bestIdentifier: String?
    let event: LocatorEventSummary

    /// You dropped out / cancelled — should be hidden from "my events".
    var isCanceledRegistration: Bool {
        let s = (registrationStatus ?? "").uppercased()
        return s == "CANCELED" || s == "CANCELLED" || s == "DROPPED"
    }
}

/// Registration statuses that mean "you're in the event" (offer Drop).
nonisolated func isActiveRegistration(_ status: String?) -> Bool {
    guard let status else { return false }
    return ["COMPLETE", "CHECKED_IN"].contains(status.uppercased())
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

    /// "In progress" but started >4 days ago — the organizer likely forgot to
    /// close it. Treat as over, not live.
    var isStaleLive: Bool {
        guard isLive, let start = startDatetime else { return false }
        return start < Date().addingTimeInterval(-4 * 24 * 60 * 60)
    }

    /// Genuinely live right now (not a stale, never-closed event).
    var isActuallyLive: Bool { isLive && !isStaleLive }
}

// MARK: - Pairings (public "TV" feed)

nonisolated struct LocatorMatch: Decodable, Sendable, Identifiable {
    let tableNumber: Int?
    let podNumber: Int?
    let status: String?
    let matchIsBye: Bool?
    let players: [LocatorMatchPlayer]

    var isBye: Bool { (matchIsBye ?? false) || players.count == 1 }
    /// 3+ players in one match = a multiplayer pod (not a 1v1 pairing).
    var isPod: Bool { players.count > 2 }

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
    let opponents: [LocatorMatchRelationship]
    let isBye: Bool

    var id: Int { matchID }
    var isComplete: Bool { (status ?? "").uppercased() == "COMPLETE" }
    var opponent: LocatorMatchRelationship? { opponents.first }
    /// More than one opponent = a multiplayer pod (our 1v1 report can't express it).
    var isMultiplayer: Bool { opponents.count > 1 }

    init?(_ match: LocatorMyMatch, myUserID: Int?) {
        let relationships = match.playerMatchRelationships
        guard let myUserID,
              let mine = relationships.first(where: { $0.userEventStatus.user?.id == myUserID })
        else { return nil }
        self.matchID = match.id
        self.tableNumber = match.tableNumber
        self.status = match.status
        self.me = mine
        self.opponents = relationships.filter { $0.id != mine.id }
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

/// Current user's registration status for an event.
nonisolated struct LocatorRegistrationStatus: Decodable, Sendable {
    let registrationStatus: String?
}

/// The signed-in user's decklist submission(s) for an event.
nonisolated struct LocatorDeckSubmissions: Decodable, Sendable {
    let totalSubmissions: Int?
    let submissions: [LocatorDeckSubmission]
}

nonisolated struct LocatorDeckSubmission: Decodable, Sendable, Identifiable {
    let id: String
    let deckId: String?
    let deckName: String?
    let bestIdentifier: String?
}

// MARK: - Stores

/// A game-stores result wraps the real store under `.store`. The wrapper `id`
/// is a UUID; the inner `store.id` is the integer used to filter events.
nonisolated struct LocatorStoreWrapper: Decodable, Sendable, Identifiable {
    let id: String
    let store: LocatorStore
}

nonisolated struct LocatorStore: Decodable, Sendable, Identifiable {
    let id: Int
    let name: String
    let latitude: Double?
    let longitude: Double?
    let fullAddress: String?
    let website: String?
    let isPremium: Bool?
    let seatCount: Int?
    let bio: String?
    let googlePlacesPhotoUrl: String?
    let organizerHeroImage: String?

    var hasCoordinate: Bool { latitude != nil && longitude != nil }
    var headerImageURL: String? {
        let candidate = organizerHeroImage ?? googlePlacesPhotoUrl
        guard let candidate, candidate.hasPrefix("http") else { return nil }
        return candidate
    }
}

/// A store's event (the events list, filtered by `store`). Lighter than LocatorEvent.
nonisolated struct LocatorStoreEvent: Decodable, Sendable, Identifiable {
    let id: Int
    let name: String
    let startDatetime: Date?
    let displayStatus: String?
    let costInCents: Int?
    let currency: String?
    let queueStatus: String?

    var isOpen: Bool { (queueStatus ?? "").uppercased() == "ACCEPTING_SIGNUPS" }
    var isLive: Bool { (displayStatus ?? "").lowercased().contains("progress") }
    var isFinished: Bool {
        let s = (displayStatus ?? "").lowercased()
        return s == "complete" || s == "canceled" || s == "cancelled"
    }

    var priceText: String {
        guard let cents = costInCents, cents > 0 else { return "Free" }
        let amount = Double(cents) / 100
        let symbol = (currency == "EUR") ? "€" : (currency == "USD" ? "$" : "\(currency ?? "") ")
        return "\(symbol)\(String(format: "%.2f", amount))"
    }
}
