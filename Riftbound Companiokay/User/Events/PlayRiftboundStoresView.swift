//
//  PlayRiftboundStoresView.swift
//  Riftbound Companiokay
//
//  Stores on PlayRiftbound data: the player's favourite stores and a finder that
//  groups nearby events by store. Each store opens PlayRiftboundStoreView.
//

import SwiftUI
import CoreLocation

struct PlayRiftboundStoresView: View {
    @EnvironmentObject private var browser: PlayRiftboundBrowser
    @EnvironmentObject private var favorites: PlayRiftboundFavorites

    @AppStorage("riftSearchPlace") private var place = ""
    @AppStorage("riftSearchLat") private var latitude: Double = 0
    @AppStorage("riftSearchLng") private var longitude: Double = 0
    @AppStorage("riftSearchKm") private var distanceKm = 50

    @State private var placeDraft = ""
    @State private var hits: [StoreHit] = []
    @State private var phase: Phase = .idle

    enum Phase: Equatable { case idle, loading, loaded, failed(String) }

    /// One store from the event search: nearest event, how many, how far.
    struct StoreHit: Identifiable {
        let organizer: CompeteOrganizer
        let distanceMeters: Double?
        let nextEvent: CompeteTournamentSummary?
        let eventCount: Int
        var id: String { organizer.id }
    }

    private let api = PlayRiftboundAPI()
    private var hasLocation: Bool { latitude != 0 || longitude != 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                calendarCard
                if favorites.signedIn == true {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader("heart.fill", "Favourite stores")
                        if favorites.stores.isEmpty {
                            Text("Tap the heart on a store to keep it here.")
                                .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(favorites.stores, id: \.id) { organizer in
                                    NavigationLink(value: organizer) { storeRow(organizer, subtitle: organizer.physicalAddress?.formattedAddress, trailing: nil) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader("magnifyingglass", "Find stores")
                    whereRow
                    results
                }
            }
            .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 24)
        }
        .refreshable { await favorites.load(browser: browser); await search() }
        .task {
            placeDraft = place
            await favorites.load(browser: browser)
            if hasLocation, hits.isEmpty { await search() }
        }
    }

    /// Prominent entry to the favourite-stores event calendar, the standout of the Stores segment.
    private var calendarCard: some View {
        NavigationLink(value: PlayRiftboundCalendarRoute()) {
            HStack(spacing: 14) {
                Image(systemName: "calendar")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(EventsTheme.matchFillBottom)
                    .frame(width: 48, height: 48)
                    .background(EventsTheme.green, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Store Calendar")
                        .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    Text(favorites.stores.isEmpty
                         ? "All your favourite stores' events in one place"
                         : "Every event at your \(favorites.stores.count) favourite store\(favorites.stores.count == 1 ? "" : "s"), by date")
                        .font(.system(size: 12.5)).foregroundStyle(EventsTheme.textSecondary).lineLimit(2)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(EventsTheme.green)
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .greenGradientBorder(radius: 16)
        }
        .buttonStyle(.plain)
    }

    private var whereRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse").foregroundStyle(EventsTheme.textSecondary)
                TextField("City or address", text: $placeDraft)
                    .textInputAutocapitalization(.words).autocorrectionDisabled().submitLabel(.search)
                    .onSubmit { Task { await geocodeAndSearch() } }
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12).frame(height: 42).eventsCard(radius: 12)
            Menu {
                ForEach(PlayRiftboundSearchView.distances, id: \.self) { km in
                    Button("\(km) km") { distanceKm = km; Task { await search() } }
                }
            } label: {
                Text("\(distanceKm) km").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 12).frame(height: 42).eventsCard(radius: 12)
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        switch phase {
        case .idle:
            if !hasLocation {
                Text("Enter a city to see stores running events nearby.")
                    .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
            }
        case .loading:
            ProgressView().tint(EventsTheme.green).frame(maxWidth: .infinity).padding(.top, 20)
        case .failed(let message):
            Text(message).font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
        case .loaded:
            if hits.isEmpty {
                Text("No stores with upcoming events within \(distanceKm) km of \(place).")
                    .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(hits) { hit in
                        NavigationLink(value: hit.organizer) {
                            storeRow(hit.organizer,
                                     subtitle: [hit.organizer.physicalAddress?.city, hit.distanceMeters.map { String(format: "%.0f km", $0 / 1000) }].compactMap { $0 }.joined(separator: " • "),
                                     trailing: hit.nextEvent?.startsAt.map { "\(hit.eventCount) · next \($0.formatted(.dateTime.day().month(.abbreviated)))" })
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func storeRow(_ organizer: CompeteOrganizer, subtitle: String?, trailing: String?) -> some View {
        let favorite = favorites.contains(organizer.id)
        return HStack(spacing: 12) {
            Image(systemName: favorite ? "heart.fill" : "storefront")
                .font(.system(size: 15)).foregroundStyle(favorite ? EventsTheme.green : EventsTheme.textSecondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(organizer.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let trailing { Text(trailing).font(.system(size: 11)).foregroundStyle(EventsTheme.textTertiary) }
            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(EventsTheme.textTertiary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .eventsCard(radius: 14)
    }

    // MARK: - Loading

    private func geocodeAndSearch() async {
        let text = placeDraft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        phase = .loading
        guard let location = try? await CLGeocoder().geocodeAddressString(text).first?.location else {
            phase = .failed("Couldn't find \"\(text)\"."); return
        }
        place = text; latitude = location.coordinate.latitude; longitude = location.coordinate.longitude
        await search()
    }

    private func search() async {
        guard hasLocation else { return }
        phase = .loading
        let filter = PlayRiftboundAPI.SearchFilter(coords: .init(latitude: latitude, longitude: longitude),
                                                   startDate: PlayRiftboundAPI.searchStartDate(), distanceMeters: distanceKm * 1000,
                                                   types: nil, formats: nil, playerFormats: nil, favoritedOrganizersOnly: nil)
        do {
            var nodes: [CompeteSearchResult] = []
            var seen: Set<String> = []
            var after: String? = nil
            // Nearest first, up to 500 events: enough to reach the edge of the radius in a city.
            for _ in 0..<10 {
                let page = try await api.searchTournaments(filter: filter, sort: .distance, after: after, first: 50,
                                                           credentials: await PlayRiftboundSession.publicCredentials())
                nodes += page.competeTournamentSearch.nodes.filter { seen.insert($0.tournament.id).inserted }
                guard page.competeTournamentSearch.pageInfo?.hasNextPage == true,
                      let cursor = page.competeTournamentSearch.pageInfo?.endCursor else { break }
                after = cursor
            }
            var byStore: [String: [CompeteSearchResult]] = [:]
            for node in nodes { if let id = node.organizer?.id { byStore[id, default: []].append(node) } }
            hits = byStore.values.compactMap { group -> StoreHit? in
                guard let organizer = group.first?.organizer else { return nil }
                let sorted = group.sorted { ($0.tournament.startsAt ?? .distantFuture) < ($1.tournament.startsAt ?? .distantFuture) }
                return StoreHit(organizer: organizer, distanceMeters: group.compactMap(\.distanceMeters).min(),
                                nextEvent: sorted.first?.tournament, eventCount: group.count)
            }
            .sorted { ($0.distanceMeters ?? .infinity) < ($1.distanceMeters ?? .infinity) }
            phase = .loaded
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
