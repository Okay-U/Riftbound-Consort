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
    let startDatetime: Date?
    let endDatetime: Date?
    let startingPlayerCount: Int?
    let numberOfRounds: Int?
    let topCutSize: Int?
    let queueStatus: String?
    let costInCents: Int?
    let currency: String?
    let settings: LocatorEventSettings?
    let tournamentPhases: [LocatorPhase]
    /// Scorekeeper's round clock. Only meaningful while `timerIsRunning`.
    let timerEndDatetime: Date?
    let timerIsRunning: Bool?

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

    /// When the current round's clock runs out (nil when no clock is running).
    var roundEndsAt: Date? { timerIsRunning == true ? timerEndDatetime : nil }

    /// Event hasn't begun yet: no round has pairings and the start time is ahead.
    var isUpcoming: Bool {
        guard !isFinished else { return false }
        if allRounds.contains(where: { $0.pairingsStatus == "GENERATED" }) { return false }
        guard let start = startDatetime else { return true }
        return start > Date()
    }

    /// Rounds whose pairings exist — the ones worth offering in the round switcher.
    var browsableRounds: [LocatorRound] {
        allRounds.filter { $0.pairingsStatus == "GENERATED" }
    }

    /// Phase-aware label for any round: "Round 3 of 5", or the bracket stage.
    func label(for round: LocatorRound) -> String {
        guard let phase = phase(of: round) else { return "Round \(round.roundNumber)" }
        if (phase.roundType ?? "").uppercased().contains("ELIMINATION") {
            return Self.eliminationStage(of: round, in: phase)
        }
        if let total = phase.numberOfRounds { return "Round \(round.roundNumber) of \(total)" }
        return "Round \(round.roundNumber)"
    }

    /// Short label for a round chip: "R3", or the bracket stage for elim rounds.
    func shortLabel(for round: LocatorRound) -> String {
        guard let phase = phase(of: round),
              (phase.roundType ?? "").uppercased().contains("ELIMINATION") else {
            return "R\(round.roundNumber)"
        }
        let stage = Self.eliminationStage(of: round, in: phase)
        switch stage {
        case "Final":        return "F"
        case "Semifinal":    return "SF"
        case "Quarterfinal": return "QF"
        default:             return stage
        }
    }

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

    /// The TV feed only ever exposes finalised matches — every sampled match,
    /// live events included, comes back COMPLETE — so a decided pairing with no
    /// winner is a draw rather than a result nobody entered yet.
    var isDraw: Bool {
        (status ?? "").uppercased() == "COMPLETE"
            && !isBye
            && players.count == 2
            && !players.contains { $0.isWinner == true }
    }

    /// Games won by each side in *this* match, in table order — "2–1", not the
    /// players' tournament records. Nil when nobody recorded a game, which is
    /// every best-of-one draw.
    var gameScore: String? {
        guard players.count == 2, !isBye else { return nil }
        let games = players.map { $0.gamesWon ?? 0 }
        guard games.contains(where: { $0 > 0 }) else { return nil }
        return "\(games[0])–\(games[1])"
    }

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
    /// Games this side won in this match — the same field the report sends
    /// back. Optional because it isn't guaranteed on every payload; a nil here
    /// just means no reported score is shown.
    let gamesWon: Int?
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

    /// The score that was actually reported for this match, from your side —
    /// "2–1", not just "you won". Nil for byes, pods, and matches where no
    /// games were recorded (every best-of-one draw).
    var reportedScore: String? {
        guard !isBye, let opponent, isComplete else { return nil }
        let mineGames = me.gamesWon ?? 0
        let theirGames = opponent.gamesWon ?? 0
        guard mineGames > 0 || theirGames > 0 else { return nil }
        return "\(mineGames)–\(theirGames)"
    }

    /// Reported, but nobody won it.
    var isDraw: Bool {
        guard !isBye, let opponent, isComplete else { return false }
        return (me.gamesWon ?? 0) == (opponent.gamesWon ?? 0)
    }
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
/// A registered player, from the roster endpoint. This is the only player list
/// an event has before pairings are generated — standings and matches are both
/// empty until the first round starts.
nonisolated struct LocatorRosterEntry: Decodable, Sendable, Identifiable {
    let tvDisplayName: String
    let registrationStatus: String?
    let checkedIn: Bool?
    let profileImageUrl: String?

    var id: String { tvDisplayName }

    /// Dropped players stay in the roster with a non-COMPLETE status.
    var isActive: Bool {
        let status = (registrationStatus ?? "").uppercased()
        return status.isEmpty || status == "COMPLETE"
    }
}

nonisolated struct LocatorRegistrationStatus: Decodable, Sendable {
    let registrationStatus: String?
}

/// Event-level sign-up counters (public): how full the event is.
nonisolated struct LocatorEventCapacity: Decodable, Sendable {
    let registrationOpen: Bool?
    let registeredUserCount: Int?
    let capacity: Int?
    let isAtCapacity: Bool?

    /// 0…1 fill ratio, nil when the event has no seat cap.
    var fillRatio: Double? {
        guard let capacity, capacity > 0, let count = registeredUserCount else { return nil }
        return min(1, Double(count) / Double(capacity))
    }
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
