//
//  LocatorCache.swift
//  Riftcount
//
//  Session cache in front of RiftboundLocatorService. Opening a big event costs
//  several seconds of server time — standings alone are ~4s per page, and the
//  deck-defining-card fetch is 1.4 MB — and backing out of an event and going
//  straight back in used to pay all of it again.
//
//  In memory only, on purpose: it lives exactly as long as the app process and
//  is gone when the app closes. Nothing here is written to disk. A tournament's
//  standings change every round, and a stale snapshot restored from an earlier
//  launch would show a dead round with complete confidence — worse than waiting.
//  Short windows for anything that moves during an event, long ones for what
//  cannot.
//
//  Views keep talking to `any LocatorService`; only their default service
//  instance points here. Authed reads and every write bypass the cache, and
//  writes drop it — reporting a result must not leave stale standings behind.
//

import Foundation

actor LocatorCache: LocatorService {
    /// nonisolated so non-UI callers can reach it: under the project's
    /// default-MainActor isolation a plain `static let` is MainActor-bound, and
    /// MatchMode builds its service from a nonisolated init. Safe — an actor is
    /// Sendable, and every method on it is already async.
    nonisolated static let shared = LocatorCache()

    private let upstream = RiftboundLocatorService()

    /// Anything that moves while an event is running.
    private let liveTTL: TimeInterval = 45
    /// Sign-ups and submitted decks: settled well before the first round.
    private let slowTTL: TimeInterval = 15 * 60
    /// Store records and their calendars barely change day to day.
    private let storeTTL: TimeInterval = 30 * 60

    private var entries: [String: (stamp: Date, value: Any)] = [:]

    /// Drop everything — pull-to-refresh and post-write path.
    func invalidate() { entries.removeAll() }

    // MARK: - Cached reads

    func event(id: Int) async throws -> LocatorEvent {
        try await cached("event:\(id)", liveTTL) { try await self.upstream.event(id: id) }
    }

    func pairings(eventID: Int) async throws -> [LocatorMatch] {
        try await cached("pairings:\(eventID)", liveTTL) { try await self.upstream.pairings(eventID: eventID) }
    }

    func pairings(eventID: Int, roundID: Int) async throws -> [LocatorMatch] {
        try await cached("pairings:\(eventID):\(roundID)", liveTTL) {
            try await self.upstream.pairings(eventID: eventID, roundID: roundID)
        }
    }

    func standings(eventID: Int) async throws -> [LocatorStanding] {
        try await cached("standings:\(eventID)", liveTTL) { try await self.upstream.standings(eventID: eventID) }
    }

    func roster(eventID: Int) async throws -> [LocatorRosterEntry] {
        try await cached("roster:\(eventID)", slowTTL) { try await self.upstream.roster(eventID: eventID) }
    }

    /// The heaviest call in the app, and the most worth keeping: a submitted
    /// deck is locked for the event, so this only refetches on a hard refresh.
    func eventDecks(roundID: Int) async throws -> [LocatorPlayerDeck] {
        try await cached("decks:\(roundID)", slowTTL) { try await self.upstream.eventDecks(roundID: roundID) }
    }

    func capacity(eventID: Int) async throws -> LocatorEventCapacity {
        try await cached("capacity:\(eventID)", liveTTL) { try await self.upstream.capacity(eventID: eventID) }
    }

    func store(id: String) async throws -> LocatorStoreWrapper {
        try await cached("store:\(id)", storeTTL) { try await self.upstream.store(id: id) }
    }

    func storesNearby(latitude: Double, longitude: Double, miles: Int, page: Int) async throws -> LocatorPage<LocatorStoreWrapper> {
        // Coordinates are rounded into the key: a few metres of GPS drift is not
        // a different search, and unrounded keys would never hit.
        let key = "stores:\(round(latitude * 100) / 100),\(round(longitude * 100) / 100):\(miles):\(page)"
        return try await cached(key, storeTTL) {
            try await self.upstream.storesNearby(latitude: latitude, longitude: longitude, miles: miles, page: page)
        }
    }

    func storeEvents(storeID: Int, status: String?, page: Int) async throws -> LocatorPage<LocatorStoreEvent> {
        try await cached("storeEvents:\(storeID):\(status ?? "all"):\(page)", storeTTL) {
            try await self.upstream.storeEvents(storeID: storeID, status: status, page: page)
        }
    }

    // MARK: - Never cached
    //
    // Per-user state and anything that reflects a write. A cached "you are
    // registered" or a cached match to report is a bug waiting to happen.

    func myEvents(token: String, page: Int) async throws -> LocatorPage<LocatorUserEventStatus> {
        try await upstream.myEvents(token: token, page: page)
    }

    func myMatch(roundID: Int, token: String) async throws -> LocatorMyMatch {
        try await upstream.myMatch(roundID: roundID, token: token)
    }

    func registrationStatus(eventID: Int, token: String) async throws -> String? {
        try await upstream.registrationStatus(eventID: eventID, token: token)
    }

    func myDeckSubmission(eventID: Int, token: String) async throws -> LocatorDeckSubmission? {
        try await upstream.myDeckSubmission(eventID: eventID, token: token)
    }

    // MARK: - Writes (drop the cache afterwards)

    func register(eventID: Int, token: String) async throws {
        try await upstream.register(eventID: eventID, token: token)
        entries.removeAll()
    }

    func drop(eventID: Int, token: String) async throws {
        try await upstream.drop(eventID: eventID, token: token)
        entries.removeAll()
    }

    func reportResult(matchID: Int,
                      token: String,
                      myPMRID: Int,
                      myGamesWon: Int,
                      opponentPMRID: Int,
                      opponentGamesWon: Int,
                      gamesDrawn: Int) async throws {
        try await upstream.reportResult(matchID: matchID,
                                        token: token,
                                        myPMRID: myPMRID,
                                        myGamesWon: myGamesWon,
                                        opponentPMRID: opponentPMRID,
                                        opponentGamesWon: opponentGamesWon,
                                        gamesDrawn: gamesDrawn)
        entries.removeAll()
    }

    // MARK: - Plumbing

    private func fresh(_ stamp: Date, _ window: TimeInterval) -> Bool {
        Date().timeIntervalSince(stamp) < window
    }

    /// Failures are never stored — a timeout on venue wifi must retry, not stick.
    private func cached<T: Sendable>(_ key: String, _ window: TimeInterval,
                                     _ fetch: () async throws -> T) async throws -> T {
        if let hit = entries[key], fresh(hit.stamp, window), let value = hit.value as? T {
            return value
        }
        let value = try await fetch()
        entries[key] = (Date(), value)
        return value
    }
}
