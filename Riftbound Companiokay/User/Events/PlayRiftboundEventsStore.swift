//
//  PlayRiftboundEventsStore.swift
//  Riftbound Companiokay
//
//  The player's registrations on PlayRiftbound (upcoming and past), read with
//  their own session through the `PlayerTournaments` query. Backs the
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
    private static let minInterval: TimeInterval = 30

    var hasEvents: Bool { !upcoming.isEmpty || !past.isEmpty }

    private var inFlight: Task<Void, Never>?

    /// Callers always get a finished refresh: a plain call joins one that is running, a forced
    /// call (after register / drop) waits for it and then loads again.
    func refresh(browser: PlayRiftboundBrowser, force: Bool = false) async {
        if let running = inFlight {
            await running.value
            if !force { return }
        }
        if !force, let last = lastLoaded, Date().timeIntervalSince(last) < Self.minInterval { return }
        let task = Task { await load(browser: browser) }
        inFlight = task
        await task.value
        if inFlight == task { inFlight = nil }
    }

    private func load(browser: PlayRiftboundBrowser) async {
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
        } catch is CancellationError {
            if !hasEvents { state = .idle }
        } catch let error as URLError where error.code == .cancelled {
            if !hasEvents { state = .idle }
        } catch {
            log.error("refresh failed: \(error.localizedDescription, privacy: .public)")
            // A failed refresh keeps the last list; the error state is for an empty screen.
            state = hasEvents ? .loaded : .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
