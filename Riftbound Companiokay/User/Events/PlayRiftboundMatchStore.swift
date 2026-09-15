//
//  PlayRiftboundMatchStore.swift
//  Riftbound Companiokay
//
//  Feeds the Scoreboard strip from PlayRiftbound: the player's next registered
//  event and, once rounds exist, their current pairing. Uses only the approved
//  operations with the player's own session. Read-only; reporting stays on the
//  site until the result-submission shape is known.
//

import SwiftUI
import os
internal import Combine

/// What the Scoreboard strip shows for PlayRiftbound.
nonisolated struct PlayRiftboundStrip: Sendable, Equatable, Identifiable {
    let tournamentID: String
    let eventName: String
    let organizerName: String?
    let startsAt: Date?
    let webURL: URL?
    /// nil until the tournament has a round with the player in it.
    let pairing: CompetePairing?

    var id: String { tournamentID + (pairing.map { "-\($0.roundNumber)" } ?? "") }
}

@MainActor
final class PlayRiftboundMatchStore: ObservableObject {
    @Published private(set) var current: PlayRiftboundStrip?
    @Published private(set) var lastError: String?

    private let api = PlayRiftboundAPI()
    private let log = Logger(subsystem: "pitopia.Riftcount", category: "PlayRiftboundMatch")
    private var isRefreshing = false
    private var lastRefresh: Date?
    private var dismissedID: String?

    /// How far ahead an event counts as "next": a week is plenty for a strip.
    private static let lookahead: TimeInterval = 7 * 24 * 60 * 60
    private static let minInterval: TimeInterval = 45

    func dismiss() {
        dismissedID = current?.id
        current = nil
    }

    /// Best effort, non-destructive: network failures keep what is shown; only a definitive
    /// "no session" or "no event" clears the strip.
    func refresh(browser: PlayRiftboundBrowser, force: Bool = false) async {
        guard !isRefreshing else { return }
        if !force, let last = lastRefresh, Date().timeIntervalSince(last) < Self.minInterval { return }
        isRefreshing = true
        defer { isRefreshing = false; lastRefresh = Date() }

        guard var credentials = await PlayRiftboundSession.credentials() else {
            current = nil
            return
        }
        if credentials.isExpired {
            await browser.refreshSession()
            guard let renewed = await PlayRiftboundSession.credentials(), !renewed.isExpired else {
                lastError = PlayRiftboundError.sessionExpired.errorDescription
                return
            }
            credentials = renewed
        }

        do {
            let mine = try await api.myTournaments(credentials: credentials)
            let horizon = Date().addingTimeInterval(Self.lookahead)
            func start(_ entry: PlayerTournamentEntry) -> Date { entry.tournament.startsAt ?? .distantFuture }
            let soon = mine.playerTournaments.upcoming.nodes.filter { start($0) <= horizon }
            guard let next = soon.min(by: { start($0) < start($1) }) else {
                current = nil
                return
            }

            var pairing: CompetePairing?
            if let tournament = try await api.tournament(id: next.tournament.id, credentials: credentials),
               let gameName = credentials.gameName,
               let playerID = tournament.playerID(gameName: gameName, tagLine: credentials.tagLine) {
                pairing = CompetePairing.resolve(in: tournament, playerID: playerID)
            }

            let strip = PlayRiftboundStrip(tournamentID: next.tournament.id,
                                           eventName: next.tournament.name,
                                           organizerName: next.organizer?.name,
                                           startsAt: next.tournament.startsAt,
                                           webURL: next.tournament.webURL,
                                           pairing: pairing)
            lastError = nil
            if strip.id == dismissedID { current = nil; return }
            dismissedID = nil
            current = strip
        } catch {
            lastError = error.localizedDescription
            log.error("refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
