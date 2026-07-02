import SwiftUI

/// Find stores by city, ported from iOS. The typed text is geocoded (Photon —
/// CLGeocoder is iOS-only) to a coordinate, then stores near it are listed.
/// The iOS map view is omitted on Android v1 (MapKit is not bridged);
/// list-only with the same rows, favorites and calendar entry.
struct StoreSearchView: View {
    var service: any LocatorService = RiftboundLocatorService()
    var embedded = false

    @AppStorage(StoreFavorites.key) var favRaw = "[]"

    @State var query = ""
    @State var results: [LocatorStoreWrapper] = []
    @State var phase: Phase = .idle
    @State var nextPage: Int?
    @State var loadingMore = false
    @State var loadMoreFailed = false
    @State var nearbyCenter: HTTPGeocoder.Coordinate?

    private let nearbyMiles = 30

    enum Phase: Equatable { case idle, searching, loaded, failed(String) }

    var body: some View {
        VStack(spacing: 12) {
            searchField
                .padding(.horizontal, 18).padding(.top, 10)

            ScrollView {
                resultsBody(for: phase).padding(.horizontal, 18).padding(.bottom, 24)
            }
        }
        .background(EventsTheme.bg.ignoresSafeArea())
        .task(id: query) { await debouncedSearch() }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").foregroundStyle(EventsTheme.textSecondary)
            TextField("Search by city", text: $query)
                .foregroundStyle(.white)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark").foregroundStyle(EventsTheme.textTertiary)
                }
                .buttonStyle(.plain)
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
                hint("No stores found near \"\(query)\".")
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
                    EventsSectionHeader("My local stores") {
                        Image(systemName: "heart.fill")
                    }
                    VStack(spacing: 9) {
                        ForEach(favorites) { favoriteRow($0) }
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    /// Prominent entry to the favorite-stores event calendar.
    private func calendarCard(favoritesCount: Int) -> some View {
        NavigationLink(value: StoreCalendarRoute()) {
            HStack(spacing: 14) {
                Image(systemName: "calendar")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(EventsTheme.matchFillBottom)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(EventsTheme.green)
                    )
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
                BuildingGlyph()
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(EventsTheme.greenSoft))
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
                BuildingGlyph()
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(EventsTheme.greenSoft))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(store.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                        if store.isPremium == true {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(EventsTheme.green)
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
                        .foregroundStyle(loadMoreFailed ? Color.red : EventsTheme.textSecondary)
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

        guard let location = await HTTPGeocoder.shared.geocode(q) else {
            if Task.isCancelled { return }
            results = []; nextPage = nil; nearbyCenter = nil
            phase = .failed("Couldn't find a place called \"\(q)\". Try a city or town name.")
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
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
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

struct StoresHomeView: View {
    var body: some View {
        StoreSearchView(embedded: true)
    }
}

/// Drawn storefront glyph (building.2.fill is not in SkipUI's map).
struct BuildingGlyph: View {
    var body: some View {
        VStack(spacing: 0) {
            // Awning
            RoundedRectangle(cornerRadius: 1.5)
                .frame(width: 16, height: 4)
            // Body with door notch
            ZStack(alignment: .bottom) {
                Rectangle()
                    .frame(width: 12, height: 9)
                Rectangle()
                    .fill(EventsTheme.greenSoft)
                    .frame(width: 4, height: 5)
            }
        }
        .foregroundStyle(EventsTheme.green)
    }
}
