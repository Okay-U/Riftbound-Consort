//
//  RiftEventsModel.swift
//  Riftbound Companiokay
//
//  What the redesign's Events tab reads beside the classic stores (Android `EventsData`): tournaments by id
//  with a short cache and a prefetch for the cards' status and placement, the calendar of registered and
//  favourite-store events, and the place the finders search around (classic keys).
//

import CoreLocation
import SwiftUI
internal import Combine

/// The signed-in player's Riot ID, from the session cookie.
struct RiotID: Equatable {
    let name: String
    let tag: String?
}

@MainActor
final class RiftTournaments: ObservableObject {
    @Published private(set) var cache: [String: CompeteTournament] = [:]
    @Published private(set) var me: RiotID?
    private var loadedAt: [String: Date] = [:]
    /// A request already on its way: a second caller (the list's prefetch, the page) waits for it.
    private var inFlight: [String: Task<CompeteTournament?, Error>] = [:]
    private let api = PlayRiftboundAPI()
    private static let ttl: TimeInterval = 20

    func cached(_ id: String) -> CompeteTournament? { cache[id] }

    /// One tournament, at most every 20 s unless forced; nil when Riot does not know it.
    func tournament(_ id: String, browser: PlayRiftboundBrowser, force: Bool = false) async throws -> CompeteTournament? {
        if !force, let at = loadedAt[id], Date().timeIntervalSince(at) < Self.ttl { return cache[id] }
        if let running = inFlight[id] { return try await running.value }
        let task = Task { try await fetch(id, browser: browser) }
        inFlight[id] = task
        defer { inFlight[id] = nil }
        return try await task.value
    }

    private func fetch(_ id: String, browser: PlayRiftboundBrowser) async throws -> CompeteTournament? {
        guard let credentials = try await PlayRiftboundSession.validCredentials(refreshingVia: browser) else {
            throw PlayRiftboundError.notSignedIn
        }
        if let name = credentials.gameName { me = RiotID(name: name, tag: credentials.tagLine) }
        let fresh = try await api.tournament(id: id, credentials: credentials)
        cache[id] = fresh
        loadedAt[id] = Date()
        return fresh
    }

    /// Details of several list entries, two at a time; failures are skipped.
    func prefetch(_ ids: [String], browser: PlayRiftboundBrowser) async {
        var queue = ids[...]
        await withTaskGroup(of: Void.self) { group in
            func next() {
                guard let id = queue.popFirst() else { return }
                group.addTask { _ = try? await self.tournament(id, browser: browser) }
            }
            next()
            next()
            for await _ in group { next() }
        }
    }

    func playerID(in tournament: CompeteTournament) -> String? {
        me.flatMap { tournament.playerID(gameName: $0.name, tagLine: $0.tag) }
    }

    /// The player's state in a listed event once its details are in.
    func state(of entry: PlayerTournamentEntry) -> CompeteTournament.PlayerState {
        guard let t = cache[entry.tournament.id], let id = playerID(in: t) else { return .none }
        return t.state(of: id)
    }

    /// An event still to play or running now: started at most eight hours ago, or starts within the hour.
    static func isLive(_ entry: PlayerTournamentEntry, now: Date = Date()) -> Bool {
        guard let start = entry.tournament.startsAt else { return false }
        return start <= now.addingTimeInterval(3600) && start >= now.addingTimeInterval(-8 * 3600)
    }
}

/// Registered events (always shown) and every favourite store's others (classic `PlayRiftboundCalendarView`).
@MainActor
final class RiftCalendar: ObservableObject {
    struct Item: Identifiable {
        let entry: PlayerTournamentEntry
        let registered: Bool
        var id: String { entry.tournament.id }
        var startsAt: Date { entry.tournament.startsAt ?? .distantFuture }
    }

    @Published private(set) var storeEvents: [PlayerTournamentEntry] = []
    @Published private(set) var loading = false
    @Published private(set) var error: String?
    /// Favourite stores whose events could not be loaded this time.
    @Published private(set) var failedStores = 0
    private var loadedAt: Date?
    private let api = PlayRiftboundAPI()
    private static let ttl: TimeInterval = 600

    /// Read from the registrations each time, so a registration or a drop shows at once; only stores that are
    /// favourites now count.
    func items(upcoming: [PlayerTournamentEntry], favorites: [CompeteOrganizer]) -> [Item] {
        let registered = Set(upcoming.map(\.tournament.id))
        let stores = Set(favorites.map(\.id))
        var seen = Set<String>()
        let others = storeEvents.filter { entry in
            !registered.contains(entry.tournament.id) && stores.contains(entry.organizer?.id ?? "") && seen.insert(entry.tournament.id).inserted
        }
        return (upcoming.map { Item(entry: $0, registered: true) } + others.map { Item(entry: $0, registered: false) })
            .sorted { $0.startsAt < $1.startsAt }
    }

    /// The next look loads again (a new favourite's events are not in yet).
    func invalidate() { loadedAt = nil }

    func load(events: PlayRiftboundEventsStore, favorites: PlayRiftboundFavorites, browser: PlayRiftboundBrowser, force: Bool = false) async {
        if loading { return }
        if !force, let loadedAt, Date().timeIntervalSince(loadedAt) < Self.ttl { return }
        loading = true
        error = nil
        defer { loading = false }
        await events.refresh(browser: browser)
        let credentials: PlayRiftboundCredentials?
        do {
            credentials = try await PlayRiftboundSession.validCredentials(refreshingVia: browser)
        } catch {
            // Signed in, but the session could not be renewed (offline?): the store events shown stay.
            self.error = "Couldn't refresh your PlayRiftbound session. Try again in a moment."
            return
        }
        guard let credentials else {
            storeEvents = []
            failedStores = 0
            return
        }
        await favorites.load(browser: browser)
        let stores = favorites.stores
        // At most four stores at a time: venue wifi, and Riot's gateway, both prefer it.
        var queue = stores[...]
        let api = api
        let (found, failed) = await withTaskGroup(of: [CompeteSearchResult]?.self) { group in
            func next() {
                guard let store = queue.popFirst() else { return }
                group.addTask {
                    guard let summary = try? await api.organizerSummary(id: store.id, credentials: credentials) else { return nil }
                    guard let lat = summary.physicalAddress?.latitude, let lng = summary.physicalAddress?.longitude else { return [] }
                    return try? await api.storeEvents(organizerID: store.id, latitude: lat, longitude: lng, credentials: credentials)
                }
            }
            for _ in 0..<4 { next() }
            var all: [CompeteSearchResult] = []
            var failures = 0
            for await part in group {
                if let part { all += part } else { failures += 1 }
                next()
            }
            return (all, failures)
        }
        failedStores = failed
        storeEvents = found.map(\.entry)
        loadedAt = Date()
    }
}

/// The place the finders search around, saved under the classic keys.
enum SearchPlace {
    static let distances = [10, 25, 50, 100, 250]

    /// City or address to coordinates; nil when the place is unknown.
    static func geocode(_ text: String) async -> CLLocationCoordinate2D? {
        try? await CLGeocoder().geocodeAddressString(text).first?.location?.coordinate
    }
}

extension Calendar {
    func sameDay(_ a: Date, _ b: Date) -> Bool { isDate(a, inSameDayAs: b) }
}
