//
//  StoreSearchView.swift
//  Riftbound Companiokay
//
//  Find a store by name or city. Public (no auth). Tapping a result opens the
//  store detail. Debounced search, paginated.
//

import SwiftUI
import MapKit
import CoreLocation

struct StoreSearchView: View {
    var service: any LocatorService = RiftboundLocatorService()
    var embedded = false   // shown inside the Stores segment (no nav bar)

    @AppStorage(StoreFavorites.key) private var favRaw = "[]"

    @State private var query = ""
    @State private var results: [LocatorStoreWrapper] = []
    @State private var phase: Phase = .idle
    @State private var nextPage: Int?
    @State private var loadingMore = false
    @State private var showMap = false
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 50.0, longitude: 9.0),
        span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 12)))
    @State private var selectedPin: StorePin?
    @State private var nearbyCenter: CLLocationCoordinate2D?   // set when results are location-based
    @FocusState private var focused: Bool

    private let nearbyMiles = 30

    enum Phase: Equatable { case idle, searching, loaded, failed(String) }

    struct StorePin: Identifiable, Equatable {
        let id: String   // game-store UUID (route id)
        let name: String
        let coordinate: CLLocationCoordinate2D
        static func == (a: StorePin, b: StorePin) -> Bool { a.id == b.id }
    }

    private var pins: [StorePin] {
        results.compactMap { w in
            guard let lat = w.store.latitude, let lon = w.store.longitude else { return nil }
            return StorePin(id: w.id, name: w.store.name,
                            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                searchField
                if embedded { mapToggleButton }
            }
            .padding(.horizontal, 18).padding(.top, 10)

            if showMap, phase == .loaded, !pins.isEmpty {
                mapView
            } else {
                ScrollView {
                    resultsBody(for: phase).padding(.horizontal, 18).padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .background(EventsTheme.bg.ignoresSafeArea())
        .navigationTitle(embedded ? "" : "Find stores")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !embedded {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showMap.toggle() } label: {
                        Image(systemName: showMap ? "list.bullet" : "map")
                    }
                    .tint(EventsTheme.green)
                    .disabled(pins.isEmpty)
                }
            }
        }
        .task(id: query) { await debouncedSearch() }
        .onAppear { focused = true }
    }

    private var mapToggleButton: some View {
        Button { showMap.toggle() } label: {
            Image(systemName: showMap ? "list.bullet" : "map")
                .font(.system(size: 17))
                .foregroundStyle(pins.isEmpty ? EventsTheme.textTertiary : EventsTheme.green)
                .frame(width: 50, height: 50)
                .background(EventsTheme.card, in: RoundedRectangle(cornerRadius: EventsTheme.pillRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: EventsTheme.pillRadius, style: .continuous).stroke(EventsTheme.hairline, lineWidth: 1))
        }
        .disabled(pins.isEmpty)
    }

    // MARK: - Map

    private var mapView: some View {
        Map(position: $camera) {
            ForEach(pins) { pin in
                Annotation(pin.name, coordinate: pin.coordinate) {
                    Button { selectedPin = pin } label: {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: selectedPin == pin ? 36 : 28))
                            .foregroundStyle(EventsTheme.green)
                            .background(Circle().fill(.white).padding(5))
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let pin = selectedPin {
                NavigationLink(value: StoreRoute(id: pin.id)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pin.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                            Text("View store").font(.system(size: 12)).foregroundStyle(EventsTheme.green)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(EventsTheme.textTertiary)
                    }
                    .padding(14)
                    .background(EventsTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(EventsTheme.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18).padding(.bottom, 10)
            }
        }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").foregroundStyle(EventsTheme.textSecondary)
            TextField("", text: $query,
                      prompt: Text("City or store name").foregroundStyle(EventsTheme.textSecondary))
                .foregroundStyle(.white)
                .focused($focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(EventsTheme.textTertiary)
                }
            }
        }
        .padding(.horizontal, 16).frame(height: 50)
        .eventsCard(radius: EventsTheme.pillRadius)
    }

    // MARK: - Results

    @ViewBuilder
    private func resultsBody(for phase: Phase) -> some View {
        switch phase {
        case .idle:
            favoritesOrHint
        case .searching:
            ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
        case .failed(let message):
            hint(message)
        case .loaded:
            if results.isEmpty {
                hint("No stores found for “\(query)”.")
            } else {
                VStack(spacing: 9) {
                    ForEach(results) { storeRow($0) }
                    if nextPage != nil { loadMoreRow }
                }
            }
        }
    }

    @ViewBuilder
    private var favoritesOrHint: some View {
        let favorites = StoreFavorites.decode(favRaw)
        if favorites.isEmpty {
            hint("Search for a store by name or city. Tap the heart on a store to save it here.")
        } else {
            VStack(alignment: .leading, spacing: 11) {
                SectionHeader("heart.fill", "My local stores") {
                    NavigationLink(value: StoreCalendarRoute()) {
                        HStack(spacing: 4) { Image(systemName: "calendar"); Text("Calendar") }
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(EventsTheme.green)
                    }
                }
                VStack(spacing: 9) {
                    ForEach(favorites) { favoriteRow($0) }
                }
            }
        }
    }

    private func favoriteRow(_ fav: FavoriteStore) -> some View {
        NavigationLink(value: StoreRoute(id: fav.id)) {
            HStack(spacing: 12) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 15)).foregroundStyle(EventsTheme.green)
                    .frame(width: 38, height: 38).background(EventsTheme.greenSoft, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(fav.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                    if let sub = fav.subtitle, !sub.isEmpty {
                        Text(sub).font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(EventsTheme.textTertiary)
            }
            .padding(.vertical, 11).padding(.horizontal, 14)
            .eventsCard(radius: 14)
        }
        .buttonStyle(.plain)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14)).foregroundStyle(EventsTheme.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity).padding(.top, 50).padding(.horizontal, 24)
    }

    private func storeRow(_ wrapper: LocatorStoreWrapper) -> some View {
        let store = wrapper.store
        return NavigationLink(value: StoreRoute(id: wrapper.id)) {
            HStack(spacing: 12) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(EventsTheme.green)
                    .frame(width: 38, height: 38)
                    .background(EventsTheme.greenSoft, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(store.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                        if store.isPremium == true {
                            Image(systemName: "checkmark.seal.fill").font(.system(size: 11)).foregroundStyle(EventsTheme.green)
                        }
                    }
                    if let address = store.fullAddress, !address.isEmpty {
                        Text(address).font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(EventsTheme.textTertiary)
            }
            .padding(.vertical, 11).padding(.horizontal, 14)
            .eventsCard(radius: 14)
        }
        .buttonStyle(.plain)
    }

    private var loadMoreRow: some View {
        Button { Task { await loadMore() } } label: {
            HStack {
                Spacer()
                if loadingMore { ProgressView() }
                else { Text("Load more").font(.system(size: 15, weight: .semibold)).foregroundStyle(EventsTheme.textSecondary) }
                Spacer()
            }
            .padding(.vertical, 14).eventsCard(radius: 14)
        }
        .buttonStyle(.plain)
        .disabled(loadingMore)
    }

    // MARK: - Search

    @MainActor
    private func debouncedSearch() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else {
            results = []; nextPage = nil; nearbyCenter = nil; phase = .idle
            return
        }
        try? await Task.sleep(nanoseconds: 350_000_000)
        if Task.isCancelled { return }
        phase = .searching
        selectedPin = nil

        // City/place: geocode the text → stores near that point, map centered there.
        if q.count >= 3, let location = await geocode(q) {
            if Task.isCancelled { return }
            do {
                let page = try await service.storesNearby(latitude: location.latitude,
                                                          longitude: location.longitude,
                                                          miles: nearbyMiles, page: 1)
                if Task.isCancelled { return }
                results = dedup(page.results)
                nextPage = page.nextPageNumber
                nearbyCenter = location
                phase = .loaded
                let delta = Double(nearbyMiles) / 45.0
                camera = .region(MKCoordinateRegion(center: location,
                                                    span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)))
                showMap = true
                return
            } catch {
                phase = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
                return
            }
        }

        // Fallback: text search by store name.
        do {
            let page = try await service.searchStores(query: q, page: 1)
            if Task.isCancelled { return }
            results = dedup(page.results)
            nextPage = page.nextPageNumber
            nearbyCenter = nil
            phase = .loaded
            recenterMap()
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    /// Geocode free text to a coordinate (city name etc.). nil if it isn't a place.
    private func geocode(_ text: String) async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { continuation in
            CLGeocoder().geocodeAddressString(text) { placemarks, _ in
                continuation.resume(returning: placemarks?.first?.location?.coordinate)
            }
        }
    }

    /// Fit the region around the result pins so the map opens on the right area.
    private func recenterMap() {
        let coords = pins.map(\.coordinate)
        guard let first = coords.first else { return }
        let lats = coords.map(\.latitude), lons = coords.map(\.longitude)
        let minLat = lats.min() ?? first.latitude, maxLat = lats.max() ?? first.latitude
        let minLon = lons.min() ?? first.longitude, maxLon = lons.max() ?? first.longitude
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max(0.05, (maxLat - minLat) * 1.4),
                                    longitudeDelta: max(0.05, (maxLon - minLon) * 1.4))
        camera = .region(MKCoordinateRegion(center: center, span: span))
    }

    @MainActor
    private func loadMore() async {
        guard let page = nextPage, !loadingMore else { return }
        loadingMore = true
        defer { loadingMore = false }
        let next: LocatorPage<LocatorStoreWrapper>?
        if let center = nearbyCenter {
            next = try? await service.storesNearby(latitude: center.latitude, longitude: center.longitude,
                                                   miles: nearbyMiles, page: page)
        } else {
            next = try? await service.searchStores(query: query.trimmingCharacters(in: .whitespaces), page: page)
        }
        if let next {
            results = dedup(results + next.results)
            nextPage = next.nextPageNumber
        }
    }

    /// The API can return the same store more than once — keep first by store id.
    private func dedup(_ list: [LocatorStoreWrapper]) -> [LocatorStoreWrapper] {
        var seen = Set<Int>()
        return list.filter { seen.insert($0.store.id).inserted }
    }
}
