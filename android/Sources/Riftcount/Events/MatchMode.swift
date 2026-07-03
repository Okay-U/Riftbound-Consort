import Foundation
import Observation
import SkipFuse

/// Links the local Scoreboard to a live tournament match, ported from iOS
/// (ObservableObject → @Observable; @AppStorage → UserDefaults-backed var).
struct ActiveTournamentMatch: Sendable, Identifiable {
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

@Observable @MainActor
final class MatchModeStore {
    /// Feature toggle (Settings). On by default; when off, the Scoreboard never
    /// shows a match strip.
    var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: "matchModeEnabled") }
    }

    private(set) var active: ActiveTournamentMatch?
    private(set) var isRefreshing = false

    /// A pairing the user manually dismissed from the strip. Auto-detect won't
    /// re-adopt this exact match; a new round/event (different matchID) clears it.
    private var dismissedMatchID: Int?

    private let service: any LocatorService

    init(service: any LocatorService = RiftboundLocatorService()) {
        self.service = service
        self.enabled = UserDefaults.standard.object(forKey: "matchModeEnabled") as? Bool ?? true
    }

    /// Adopt a specific match (the "Play on Scoreboard" hand-off).
    func setManual(_ match: ActiveTournamentMatch) {
        enabled = true
        dismissedMatchID = nil
        active = match
    }

    func clear() {
        active = nil
    }

    /// User dismissed the strip: hide it and remember this pairing so the next
    /// auto-refresh doesn't immediately bring it back.
    func dismiss() {
        dismissedMatchID = active?.match.matchID
        active = nil
    }

    /// Auto-detect the player's current live match. Best-effort and
    /// non-destructive — transient failures keep any adopted match; the strip
    /// only drops when there is definitively no live event (or signed out/off).
    func refresh(session: AuthSession) async {
        guard enabled, let token = session.token, let userID = session.userID else {
            active = nil
            return
        }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        guard let page = try? await service.myEvents(token: token, page: 1) else { return }

        guard let live = page.results.first(where: {
            $0.event.isActuallyLive && !$0.isCanceledRegistration
        }) else {
            active = nil   // definitively no live event → drop the strip
            return
        }

        guard let event = try? await service.event(id: live.event.id),
              let round = event.currentRound,
              let myMatch = try? await service.myMatch(roundID: round.id, token: token),
              let resolved = ResolvedMyMatch(myMatch, myUserID: userID)
        else { return }

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
