//
//  StoreSearchView.swift
//  Riftbound Companiokay
//
//  Find stores by city. Public (no auth). The typed text is geocoded to a
//  coordinate, then we list stores near it (store-name text search proved
//  unreliable on the API, so we stick to city/place lookup). Debounced,
//  paginated, with a map view. Tapping a result opens the store detail.
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
    @State private var loadMoreFailed = false
    @State private var showMap = false
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 50.0, longitude: 9.0),
        span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 12)))
    @State private var selectedPin: StorePin?
    @State private var nearbyCenter: CLLocationCoordinate2D?   // set when results are location-based
    @State private var userToggledMap = false   // once the user picks list/map, stop auto-flipping
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
                    Button { userToggledMap = true; showMap.toggle() } label: {
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
        Button { userToggledMap = true; showMap.toggle() } label: {
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
                      prompt: Text("Search by city").foregroundStyle(EventsTheme.textSecondary))
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
                hint("No stores found near “\(query)”.")
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
        VStack(alignment: .leading, spacing: 16) {
            calendarCard(favoritesCount: favorites.count)

            if favorites.isEmpty {
                Text("Search by city to find stores near you, then tap the heart to save one. Your saved stores fill the calendar above.")
                    .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 11) {
                    SectionHeader("heart.fill", "My local stores")
                    VStack(spacing: 9) {
                        ForEach(favorites) { favoriteRow($0) }
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    /// Prominent entry to the favorite-stores event calendar — the standout
    /// feature of the Stores tab (see every local store's events by date).
    private func calendarCard(favoritesCount: Int) -> some View {
        NavigationLink(value: StoreCalendarRoute()) {
            HStack(spacing: 14) {
                Image(systemName: "calendar")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(EventsTheme.matchFillBottom)
                    .frame(width: 48, height: 48)
                    .background(EventsTheme.green, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Store Calendar")
                        .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    Text(favoritesCount > 0
                         ? "Every event at your \(favoritesCount) saved store\(favoritesCount == 1 ? "" : "s"), by date"
                         : "All your local stores' events in one place")
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
                if loadingMore {
                    ProgressView()
                } else {
                    Text(loadMoreFailed ? "Couldn't load more. Tap to retry." : "Load more")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(loadMoreFailed ? .red : EventsTheme.textSecondary)
                }
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
        guard q.count >= 3 else {
            results = []; nextPage = nil; nearbyCenter = nil; phase = .idle
            return
        }
        try? await Task.sleep(nanoseconds: 350_000_000)
        if Task.isCancelled { return }
        phase = .searching
        selectedPin = nil

        // City/place only: geocode the text → stores near that point, map centered there.
        guard let location = await geocode(q) else {
            if Task.isCancelled { return }
            results = []; nextPage = nil; nearbyCenter = nil
            phase = .failed("Couldn't find a place called “\(q)”. Try a city or town name.")
            return
        }
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
            // Auto-open the map for the first search; once the user has picked a
            // view themselves, respect it and don't keep flipping back.
            if !userToggledMap { showMap = true }
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    /// Geocode free text to a coordinate (city name etc.). nil if it isn't a place.
    /// One request per settled query — the 350ms debounce + `.task(id:)` cancellation
    /// upstream means this only runs once the user stops typing, so a fresh geocoder
    /// per call won't pile up against Apple's rate limit.
    private func geocode(_ text: String) async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { continuation in
            CLGeocoder().geocodeAddressString(text) { placemarks, _ in
                continuation.resume(returning: placemarks?.first?.location?.coordinate)
            }
        }
    }

    @MainActor
    private func loadMore() async {
        guard let page = nextPage, let center = nearbyCenter, !loadingMore else { return }
        loadingMore = true
        loadMoreFailed = false
        defer { loadingMore = false }
        if let next = try? await service.storesNearby(latitude: center.latitude, longitude: center.longitude,
                                                      miles: nearbyMiles, page: page) {
            results = dedup(results + next.results)
            nextPage = next.nextPageNumber
        } else {
            loadMoreFailed = true
        }
    }

    /// The API can return the same store more than once — keep first by store id.
    private func dedup(_ list: [LocatorStoreWrapper]) -> [LocatorStoreWrapper] {
        var seen = Set<Int>()
        return list.filter { seen.insert($0.store.id).inserted }
    }
}
