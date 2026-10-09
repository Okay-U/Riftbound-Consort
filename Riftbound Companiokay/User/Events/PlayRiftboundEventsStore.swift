//
//  PlayRiftboundEventsStore.swift
//  Riftbound Companiokay
//
//  The player's registrations on PlayRiftbound (upcoming and past), read with
//  their own session through the approved `PlayerTournaments` query. Backs the
//  native Events segment.
//

import SwiftUI
import os
internal import Combine

@MainActor
final class PlayRiftboundEventsStore: ObservableObject {
    enum State: Equatable { case idle, signedOut, loading, loaded, failed(String) }

    @Published private(set) var state: State = .idle
    @Published private(set) var upcoming: [PlayerTournamentEntry] = []
    @Published private(set) var past: [PlayerTournamentEntry] = []
    @Published private(set) var lastLoaded: Date?

    private let api = PlayRiftboundAPI()
    private let log = Logger(subsystem: "pitopia.Riftcount", category: "PlayRiftboundEvents")
    private var isRefreshing = false
    private static let minInterval: TimeInterval = 30

    var hasEvents: Bool { !upcoming.isEmpty || !past.isEmpty }

    func refresh(browser: PlayRiftboundBrowser, force: Bool = false) async {
        guard !isRefreshing else { return }
        if !force, let last = lastLoaded, Date().timeIntervalSince(last) < Self.minInterval { return }
        isRefreshing = true
        defer { isRefreshing = false }
        if !hasEvents { state = .loading }
        do {
            guard let credentials = try await PlayRiftboundSession.validCredentials(refreshingVia: browser) else {
                upcoming = []; past = []
                state = .signedOut
                return
            }
            let mine = try await api.myTournaments(credentials: credentials, upcoming: 50, past: 50)
            func start(_ e: PlayerTournamentEntry) -> Date { e.tournament.startsAt ?? .distantFuture }
            upcoming = mine.playerTournaments.upcoming.nodes.sorted { start($0) < start($1) }
            past = mine.playerTournaments.past.nodes.sorted { start($0) > start($1) }
            lastLoaded = Date()
            state = .loaded
        } catch {
            log.error("refresh failed: \(error.localizedDescription, privacy: .public)")
            // A failed refresh keeps the last list; the error state is for an empty screen.
            state = hasEvents ? .loaded : .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
