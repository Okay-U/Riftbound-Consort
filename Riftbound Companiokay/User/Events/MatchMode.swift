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
    /// Feature toggle (Settings). When off, the Scoreboard never shows a match strip.
    @AppStorage("matchModeEnabled") var enabled: Bool = false

    @Published private(set) var active: ActiveTournamentMatch?
    @Published private(set) var isRefreshing = false

    private let service: any LocatorService

    init(service: any LocatorService = RiftboundLocatorService()) {
        self.service = service
    }

    /// Adopt a specific match (the "Play on Scoreboard" hand-off). Turns the
    /// feature on so the strip shows immediately.
    func setManual(_ match: ActiveTournamentMatch) {
        enabled = true
        active = match
    }

    func clear() {
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

        active = ActiveTournamentMatch(
            eventID: event.id,
            match: resolved,
            isBestOfThree: event.isBestOfThree,
            eventName: event.name,
            roundLabel: event.currentRoundLabel
        )
    }
}
