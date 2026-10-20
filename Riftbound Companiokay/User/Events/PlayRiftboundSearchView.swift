//
//  PlayRiftboundSearchView.swift
//  Riftbound Companiokay
//
//  Native event finder on PlayRiftbound's search: a place, a radius, the site's type / format /
//  player-count filters, favourites only, sorted by date or distance.
//

import SwiftUI
import CoreLocation

struct PlayRiftboundSearchRoute: Hashable {}

struct PlayRiftboundSearchView: View {
    @EnvironmentObject private var browser: PlayRiftboundBrowser
    @EnvironmentObject private var events: PlayRiftboundEventsStore

    @AppStorage("riftSearchPlace") private var place = ""
    @AppStorage("riftSearchLat") private var latitude: Double = 0
    @AppStorage("riftSearchLng") private var longitude: Double = 0
    @AppStorage("riftSearchKm") private var distanceKm = 50

    @State private var types: Set<String> = []
    @State private var formats: Set<String> = []
    @State private var playerFormats: Set<String> = []
    @State private var favoritesOnly = false
    @State private var sort: PlayRiftboundAPI.SearchSort = .date
    @State private var results: [CompeteSearchResult] = []
    @State private var nextCursor: String?
    @State private var phase: Phase = .idle
    @State private var signedIn = false
    @State private var placeDraft = ""

    enum Phase: Equatable { case idle, locating, loading, loaded, failed(String) }

    private let api = PlayRiftboundAPI()
    static let distances = [10, 25, 50, 100, 250]
    static let typeOptions: [(String, String)] = [("LEARN_TO_PLAY", "Learn to Play"), ("NEXUS_NIGHT", "Nexus Night"),
                                                  ("OPEN_PLAY", "Open Play"), ("PRE_RIFT", "Pre-Rift"), ("SUMMONER_SKIRMISH", "Summoner Skirmish")]
    static let formatOptions: [(String, String)] = [("LIMITED_SEALED", "Sealed"), ("LIMITED_DRAFT", "Draft"), ("CONSTRUCTED", "Constructed")]
    static let playerOptions: [(String, String)] = [("ONE_V_ONE", "1v1"), ("TWO_V_TWO", "2v2")]

    private var hasLocation: Bool { latitude != 0 || longitude != 0 }
    private var registeredIDs: Set<String> { Set(events.upcoming.map(\.tournament.id)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                whereRow
                filterRows
                resultsSection
            }
            .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 24)
        }
        .background(EventsTheme.bg.ignoresSafeArea())
        .navigationTitle("Find events")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(EventsTheme.bg, for: .navigationBar)
        .task {
            placeDraft = place
            signedIn = (try? await PlayRiftboundSession.validCredentials(refreshingVia: browser)) != nil
            if hasLocation, results.isEmpty { await search() }
        }
    }

    // MARK: - Filters

    private var whereRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse").foregroundStyle(EventsTheme.textSecondary)
                TextField("City or address", text: $placeDraft)
                    .textInputAutocapitalization(.words).autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { Task { await geocodeAndSearch() } }
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12).frame(height: 42)
            .eventsCard(radius: 12)
            Menu {
                ForEach(Self.distances, id: \.self) { km in
                    Button("\(km) km") { distanceKm = km; Task { await search() } }
                }
            } label: {
                Text("\(distanceKm) km").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 12).frame(height: 42).eventsCard(radius: 12)
            }
        }
    }

    private var filterRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            chipRow(Self.typeOptions, selection: $types)
            HStack(spacing: 6) {
                chipRow(Self.formatOptions, selection: $formats)
                chipRow(Self.playerOptions, selection: $playerFormats)
            }
            HStack(spacing: 8) {
                Picker("Sort", selection: $sort) {
                    Text("By date").tag(PlayRiftboundAPI.SearchSort.date)
                    Text("By distance").tag(PlayRiftboundAPI.SearchSort.distance)
                }
                .pickerStyle(.segmented)
                .onChange(of: sort) { _, _ in Task { await search() } }
                if signedIn {
                    Toggle(isOn: $favoritesOnly) {
                        Image(systemName: favoritesOnly ? "heart.fill" : "heart")
                    }
                    .toggleStyle(.button).tint(EventsTheme.green)
                    .onChange(of: favoritesOnly) { _, _ in Task { await search() } }
                    .accessibilityLabel("Favourite stores only")
                }
            }
        }
    }

    private func chipRow(_ options: [(String, String)], selection: Binding<Set<String>>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(options, id: \.0) { value, label in
                    let on = selection.wrappedValue.contains(value)
                    Button {
                        if on { selection.wrappedValue.remove(value) } else { selection.wrappedValue.insert(value) }
                        Task { await search() }
                    } label: {
                        Text(label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(on ? EventsTheme.matchFillBottom : EventsTheme.textSecondary)
                            .padding(.horizontal, 11).frame(height: 30)
                            .background(on ? EventsTheme.green : EventsTheme.card, in: Capsule())
                            .overlay(Capsule().stroke(on ? Color.clear : EventsTheme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsSection: some View {
        switch phase {
        case .idle:
            Text(hasLocation ? "" : "Enter a city to find events nearby.")
                .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
                .frame(maxWidth: .infinity).padding(.top, 30)
        case .locating, .loading:
            ProgressView().tint(EventsTheme.green).frame(maxWidth: .infinity).padding(.top, 30)
        case .failed(let message):
            VStack(spacing: 10) {
                Text(message).font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary).multilineTextAlignment(.center)
                Button("Retry") { Task { await search() } }.tint(EventsTheme.green)
            }
            .frame(maxWidth: .infinity).padding(.top, 30)
        case .loaded:
            if results.isEmpty {
                Text("No events within \(distanceKm) km of \(place).")
                    .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
                    .frame(maxWidth: .infinity).padding(.top, 30)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader("calendar", "\(results.count) events") {
                        if !place.isEmpty { Text(place).foregroundStyle(EventsTheme.textTertiary).lineLimit(1) }
                    }
                    ForEach(results, id: \.tournament.id) { result in
                        NavigationLink(value: result.entry) {
                            PlayRiftboundEventCard(entry: result.entry, distanceMeters: result.distanceMeters,
                                                   registered: registeredIDs.contains(result.tournament.id))
                        }
                        .buttonStyle(.plain)
                    }
                    if nextCursor != nil {
                        Button("Load more") { Task { await loadMore() } }
                            .font(.system(size: 14, weight: .semibold)).tint(EventsTheme.green)
                            .frame(maxWidth: .infinity).padding(.top, 4)
                    }
                }
            }
        }
    }

    // MARK: - Loading

    private func geocodeAndSearch() async {
        let text = placeDraft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        phase = .locating
        do {
            guard let location = try await CLGeocoder().geocodeAddressString(text).first?.location else {
                phase = .failed("Couldn't find \"\(text)\".")
                return
            }
            place = text
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            await search()
        } catch {
            phase = .failed("Couldn't find \"\(text)\".")
        }
    }

    private var filter: PlayRiftboundAPI.SearchFilter {
        .init(coords: .init(latitude: latitude, longitude: longitude),
              startDate: PlayRiftboundAPI.searchStartDate(),
              distanceMeters: distanceKm * 1000,
              types: types.isEmpty ? nil : types.sorted(),
              formats: formats.isEmpty ? nil : formats.sorted(),
              playerFormats: playerFormats.isEmpty ? nil : playerFormats.sorted(),
              favoritedOrganizersOnly: favoritesOnly ? true : nil)
    }

    private func search() async {
        guard hasLocation else { return }
        phase = .loading
        do {
            let page = try await api.searchTournaments(filter: filter, sort: sort, credentials: await PlayRiftboundSession.publicCredentials())
            results = page.competeTournamentSearch.nodes
            nextCursor = page.competeTournamentSearch.pageInfo?.hasNextPage == true ? page.competeTournamentSearch.pageInfo?.endCursor : nil
            phase = .loaded
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func loadMore() async {
        guard let cursor = nextCursor else { return }
        nextCursor = nil
        do {
            let page = try await api.searchTournaments(filter: filter, sort: sort, after: cursor, credentials: await PlayRiftboundSession.publicCredentials())
            let known = Set(results.map(\.tournament.id))
            results += page.competeTournamentSearch.nodes.filter { !known.contains($0.tournament.id) }
            nextCursor = page.competeTournamentSearch.pageInfo?.hasNextPage == true ? page.competeTournamentSearch.pageInfo?.endCursor : nil
        } catch {
            nextCursor = cursor
        }
    }
}
