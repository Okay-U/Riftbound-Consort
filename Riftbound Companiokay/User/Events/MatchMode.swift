//
//  MatchMode.swift
//  Riftbound Companiokay
//
//  Links the local Scoreboard to a live tournament match. When match mode is on
//  and the signed-in player has a pairing in an in-progress event, the Scoreboard
//  shows a slim "Table N · You vs Opp" strip plus a Report button that reuses the
//  Events report flow. Two entry paths: auto-detect (refresh) and an explicit
//  "Play on Scoreboard" hand-off from the event screen (setManual).
//

import SwiftUI
internal import Combine

/// A tournament match adopted by the Scoreboard. Carries everything the strip
/// and the report sheet need, so the Scoreboard never has to re-fetch.
nonisolated struct ActiveTournamentMatch: Sendable, Identifiable {
    let eventID: Int
    let match: ResolvedMyMatch
    let isBestOfThree: Bool
    let eventName: String?
    let roundLabel: String?

    var id: Int { match.matchID }
    var tableNumber: Int? { match.tableNumber }
    var myName: String { match.me.displayName }
    var opponentName: String? { match.opponent?.displayName }
    var isComplete: Bool { match.isComplete }
    /// 1v1 only — multiplayer pods can't be reported via our sheet.
    var isReportable: Bool { match.opponent != nil && !match.isMultiplayer }
}

@MainActor
final class MatchModeStore: ObservableObject {
    /// Feature toggle (Settings). On by default; when off, the Scoreboard never
    /// shows a match strip. (Harmless when on but not signed into Events: refresh
    /// no-ops without a token, so nothing appears.)
    @AppStorage("matchModeEnabled") var enabled: Bool = true

    @Published private(set) var active: ActiveTournamentMatch?
    @Published private(set) var isRefreshing = false

    /// A pairing the user manually dismissed from the strip. Auto-detect won't
    /// re-adopt this exact match; a new round/event (different matchID) clears it.
    private var dismissedMatchID: Int?

    private let service: any LocatorService

    init(service: any LocatorService = RiftboundLocatorService()) {
        self.service = service
    }

    /// Adopt a specific match (the "Play on Scoreboard" hand-off). Turns the
    /// feature on so the strip shows immediately.
    func setManual(_ match: ActiveTournamentMatch) {
        enabled = true
        dismissedMatchID = nil
        active = match
    }

    func clear() {
        active = nil
    }

    /// User tapped the strip's dismiss button: hide it and remember this pairing so
    /// the next auto-refresh doesn't immediately bring it back.
    func dismiss() {
        dismissedMatchID = active?.match.matchID
        active = nil
    }

    /// Auto-detect the player's current live match: my-events → first live event →
    /// current round → my-match. Best-effort and non-destructive — a transient
    /// network failure keeps any match already adopted, and the strip is only
    /// dropped when there is definitively no live event (or we're signed out/off).
    func refresh(session: AuthSession) async {
        guard enabled, let token = session.token, let userID = session.userID else {
            active = nil
            return
        }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        // Find the live event. A failure here leaves any existing match intact.
        guard let page = try? await service.myEvents(token: token, page: 1) else { return }

        guard let live = page.results.first(where: {
            $0.event.isActuallyLive && !$0.isCanceledRegistration
        }) else {
            active = nil   // definitively no live event → drop the strip
            return
        }

        // Resolve this round's match; transient failures keep the existing strip.
        guard let event = try? await service.event(id: live.event.id),
              let round = event.currentRound,
              let myMatch = try? await service.myMatch(roundID: round.id, token: token),
              let resolved = ResolvedMyMatch(myMatch, myUserID: userID)
        else { return }

        // Honor a manual dismiss until the pairing actually changes (next round/event).
        if resolved.matchID == dismissedMatchID {
            active = nil
            return
        }
        dismissedMatchID = nil

        active = ActiveTournamentMatch(
            eventID: event.id,
            match: resolved,
            isBestOfThree: event.isBestOfThree,
            eventName: event.name,
            roundLabel: event.currentRoundLabel
        )
    }
}
