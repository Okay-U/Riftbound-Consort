//
//  PlayRiftboundMatchStore.swift
//  Riftbound Companiokay
//
//  Feeds the Scoreboard strip from PlayRiftbound: the player's next registered
//  event and, once rounds exist, their current pairing, read with the player's
//  own session. Read-only; reporting stays on the
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
    /// The pairing's round as a chip ("R3", "QF"), for the redesign's seam.
    var roundShort: String? = nil
    /// While the round runs: its clock's end (`startedAt` plus `roundDuration`, 60 minutes when none).
    var roundEndsAt: Date? = nil

    var id: String { tournamentID + (pairing.map { "-\($0.roundID)" } ?? "") }
}

@MainActor
final class PlayRiftboundMatchStore: ObservableObject {
    @Published private(set) var current: PlayRiftboundStrip?
    @Published private(set) var lastError: String?
    /// The strip the player closed; kept so the header button can bring it back.
    @Published private(set) var hidden: PlayRiftboundStrip?

    var hasEvent: Bool { current != nil || hidden != nil }

    func toggleHidden() {
        if current != nil { dismiss() }
        else if let hidden { dismissedID = nil; self.hidden = nil; current = hidden }
    }

    private let api = PlayRiftboundAPI()
    private let log = Logger(subsystem: "pitopia.Riftcount", category: "PlayRiftboundMatch")
    @Published private(set) var isRefreshing = false
    private var lastRefresh: Date?
    private var dismissedID: String?
    /// A forced refresh that arrived while another one was running (e.g. right after a report).
    private var followUp = false

    /// How far ahead an event counts as "next": the strip is for the day at the table,
    /// not a reminder, so only events starting within a few hours (or already running).
    private static let lookahead: TimeInterval = 3 * 60 * 60
    private static let minInterval: TimeInterval = 45

    func dismiss() {
        dismissedID = current?.id
        hidden = current
        current = nil
    }

    /// Best effort, non-destructive: network failures keep what is shown; only a definitive
    /// "no session" or "no event" clears the strip.
    func refresh(browser: PlayRiftboundBrowser, force: Bool = false) async {
        if isRefreshing {
            if force { followUp = true }
            return
        }
        if !force, let last = lastRefresh, Date().timeIntervalSince(last) < Self.minInterval { return }
        isRefreshing = true
        await load(browser: browser)
        isRefreshing = false
        if followUp {
            followUp = false
            await refresh(browser: browser, force: true)
        }
    }

    /// Nothing to show any more: also forget a strip the player had hidden, so the header
    /// button cannot bring back an old event.
    private func clear() {
        current = nil
        hidden = nil
        dismissedID = nil
        lastError = nil
    }

    private func load(browser: PlayRiftboundBrowser) async {
        do {
            guard let credentials = try await PlayRiftboundSession.validCredentials(refreshingVia: browser) else {
                clear()
                lastRefresh = Date()
                return
            }
            let mine = try await api.myTournaments(credentials: credentials)
            let horizon = Date().addingTimeInterval(Self.lookahead)
            func start(_ entry: PlayerTournamentEntry) -> Date { entry.tournament.startsAt ?? .distantFuture }
            let soon = mine.playerTournaments.upcoming.nodes.filter { start($0) <= horizon }
            guard let next = soon.min(by: { start($0) < start($1) }) else {
                clear()
                lastRefresh = Date()
                return
            }

            var pairing: CompetePairing?
            var roundShort: String?
            var roundEndsAt: Date?
            if let tournament = try await api.tournament(id: next.tournament.id, credentials: credentials),
               let gameName = credentials.gameName,
               let playerID = tournament.playerID(gameName: gameName, tagLine: credentials.tagLine) {
                pairing = CompetePairing.resolve(in: tournament, playerID: playerID)
                if let roundID = pairing?.roundID, let round = tournament.rounds.first(where: { $0.id == roundID }) {
                    roundShort = tournament.shortTitle(of: round)
                    if let started = round.startedAt, round.matches.contains(where: { !$0.isComplete }) {
                        roundEndsAt = started.addingTimeInterval(TimeInterval(round.roundDuration ?? 60) * 60)
                    }
                }
            }

            let strip = PlayRiftboundStrip(tournamentID: next.tournament.id,
                                           eventName: next.tournament.name,
                                           organizerName: next.organizer?.name,
                                           startsAt: next.tournament.startsAt,
                                           webURL: next.tournament.webURL,
                                           pairing: pairing,
                                           roundShort: roundShort,
                                           roundEndsAt: roundEndsAt)
            lastError = nil
            lastRefresh = Date()
            if strip.id == dismissedID { current = nil; hidden = strip; return }
            dismissedID = nil
            hidden = nil
            current = strip
        } catch is CancellationError {
            // The view went away; keep what is shown.
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            // Failures keep the strip and do not start the 45 s back-off, so the next appear retries.
            lastError = error.localizedDescription
            log.error("refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
