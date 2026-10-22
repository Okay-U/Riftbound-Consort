//
//  SearchPage.swift
//  Riftbound Companiokay
//
//  Find events (Android `SearchPage.kt`, classic `PlayRiftboundSearchView`, mock's search page): a place, a
//  radius, the site's type / format / player-count filters, favourite stores only, by date or distance.
//

import SwiftUI

struct SearchPage: View {
    let onOpen: (EventsRoute) -> Void
    let onToast: (String) -> Void
    @EnvironmentObject private var events: PlayRiftboundEventsStore
    @AppStorage("riftSearchPlace") private var place = ""
    @AppStorage("riftSearchLat") private var latitude: Double = 0
    @AppStorage("riftSearchLng") private var longitude: Double = 0
    @AppStorage("riftSearchKm") private var km = 50
    @State private var draft = ""
    @State private var types: Set<String> = []
    @State private var formats: Set<String> = []
    @State private var players: Set<String> = []
    @State private var favoritesOnly = false
    @State private var sort: PlayRiftboundAPI.SearchSort = .date
    @State private var results: [CompeteSearchResult] = []
    @State private var next: String?
    @State private var message: String?
    @State private var loading = false
    @State private var generation = 0

    private static let typeOptions = [("LEARN_TO_PLAY", "Learn to Play"), ("NEXUS_NIGHT", "Nexus Night"), ("OPEN_PLAY", "Open Play"), ("PRE_RIFT", "Pre-Rift"), ("SUMMONER_SKIRMISH", "Summoner Skirmish")]
    private static let formatOptions = [("LIMITED_SEALED", "Sealed"), ("LIMITED_DRAFT", "Draft"), ("CONSTRUCTED", "Constructed")]
    private static let playerOptions = [("ONE_V_ONE", "1v1"), ("TWO_V_TWO", "2v2")]

    private var known: Bool { latitude != 0 || longitude != 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlaceField(text: $draft, onSubmit: locate)
            FlowLayout(spacing: 6) {
                ForEach(SearchPlace.distances, id: \.self) { d in
                    EvChip(text: "\(d) km", on: km == d) {
                        km = d
                        search()
                    }
                }
            }
            .padding(.top, 10)
            FlowLayout(spacing: 6) {
                ForEach(Self.typeOptions, id: \.0) { value, label in EvChip(text: label, on: types.contains(value)) { types.toggleMember(value); search() } }
                ForEach(Self.formatOptions, id: \.0) { value, label in EvChip(text: label, on: formats.contains(value)) { formats.toggleMember(value); search() } }
                ForEach(Self.playerOptions, id: \.0) { value, label in EvChip(text: label, on: players.contains(value)) { players.toggleMember(value); search() } }
            }
            .padding(.top, 10)
            FlowLayout(spacing: 6) {
                EvChip(text: "By date", on: sort == .date) { sort = .date; search() }
                EvChip(text: "By distance", on: sort == .distance) { sort = .distance; search() }
                if events.state != .signedOut {
                    EvChip(text: "♥\u{FE0E} Favourite stores only", on: favoritesOnly) { favoritesOnly.toggle(); search() }
                }
            }
            .padding(.top, 10)
            list
        }
        .onAppear {
            if draft.isEmpty { draft = place }
            if !known { message = "Enter a city to find events nearby." } else if results.isEmpty, !loading { search() }
        }
    }

    @ViewBuilder
    private var list: some View {
        if loading && results.isEmpty {
            EvLoading(text: "Searching PlayRiftbound")
        } else if let message {
            EvMessage(text: message).padding(.vertical, 26).padding(.horizontal, 10)
        } else {
            let registered = Set(events.upcoming.map(\.tournament.id))
            EvCaption(left: "\(results.count) events · \(place)")
            ForEach(Array(results.enumerated()), id: \.element.tournament.id) { i, result in
                let s = result.tournament
                EvRowCard(label: "Open \(s.name)", action: { onOpen(.event(result.entry)) }) {
                    DateBadge(date: s.startsAt)
                    EventInfo(name: s.name, format: EvFmt.summaryLine(s), storeLine: EvFmt.storeLine(result.organizer, distance: result.distanceMeters),
                              favoriteStore: result.organizer?.isFavorited == true) {
                        EvPill(text: EvFmt.price(fee: s.entryFee, pricing: s.pricing))
                        EvPill(text: EvFmt.players(s.registeredCount, cap: s.config?.participantCapacity))
                        if registered.contains(s.id) { EvPill(text: "Registered", bg: RiftColor.you.opacity(0.16), ink: RiftColor.you) }
                    }
                }
                .padding(.bottom, 10)
                .softIn(delay: Double(min(i, 8)) * 0.05, duration: 0.7)
            }
            if next != nil {
                EvButton(text: "Load more", kind: .ghost, action: loadMore)
            }
        }
    }

    private var filter: PlayRiftboundAPI.SearchFilter {
        .init(coords: .init(latitude: latitude, longitude: longitude),
              startDate: PlayRiftboundAPI.searchStartDate(),
              distanceMeters: km * 1000,
              types: types.isEmpty ? nil : types.sorted(),
              formats: formats.isEmpty ? nil : formats.sorted(),
              playerFormats: players.isEmpty ? nil : players.sorted(),
              favoritedOrganizersOnly: favoritesOnly ? true : nil)
    }

    private func locate() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        loading = true
        Task {
            guard let found = await SearchPlace.geocode(text) else {
                loading = false
                results = []
                message = "Couldn’t find “\(text)”."
                return
            }
            place = text
            latitude = found.latitude
            longitude = found.longitude
            search()
        }
    }

    private func search() {
        guard known else { return }
        generation += 1
        let request = generation
        let filter = filter
        loading = true
        Task {
            defer { if request == generation { loading = false } }
            do {
                let page = try await PlayRiftboundAPI().searchTournaments(filter: filter, sort: sort, credentials: await PlayRiftboundSession.publicCredentials())
                guard request == generation else { return }
                results = page.competeTournamentSearch.nodes
                next = page.competeTournamentSearch.pageInfo?.hasNextPage == true ? page.competeTournamentSearch.pageInfo?.endCursor : nil
                message = results.isEmpty ? "No events within \(km) km of \(place)." : nil
            } catch {
                guard request == generation else { return }
                message = (error as? LocalizedError)?.errorDescription ?? "Couldn't search PlayRiftbound."
            }
        }
    }

    private func loadMore() {
        guard let cursor = next else { return }
        let request = generation
        let filter = filter
        next = nil
        Task {
            do {
                let page = try await PlayRiftboundAPI().searchTournaments(filter: filter, sort: sort, after: cursor, credentials: await PlayRiftboundSession.publicCredentials())
                guard request == generation else { return }
                let known = Set(results.map(\.tournament.id))
                results += page.competeTournamentSearch.nodes.filter { !known.contains($0.tournament.id) }
                next = page.competeTournamentSearch.pageInfo?.hasNextPage == true ? page.competeTournamentSearch.pageInfo?.endCursor : nil
            } catch {
                guard request == generation else { return }
                next = cursor
                onToast((error as? LocalizedError)?.errorDescription ?? "Couldn't load more")
            }
        }
    }
}
