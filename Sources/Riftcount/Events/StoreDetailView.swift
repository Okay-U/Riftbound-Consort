import SwiftUI

/// Store info + its events (Upcoming / Live / Past), ported from iOS.
/// Heart toggles the store as a local favorite. Store ranking card
/// (eloshowdown) arrives with stage 3e. Android system back replaces the
/// custom back button; the favorite heart moves inline next to the name.
struct StoreDetailView: View {
    let storeID: String   // game-store UUID
    var service: any LocatorService = RiftboundLocatorService()

    @AppStorage(StoreFavorites.key) var favRaw = "[]"
    @State var store: LocatorStore?
    @State var phase: Phase = .loading
    @State var events: [LocatorStoreEvent] = []
    @State var when: When = .upcoming
    @State var eventsLoading = false
    @State var eventsError = false
    @State var nextPage: Int?

    enum Phase: Equatable { case loading, loaded, failed(String) }

    enum When: String, CaseIterable {
        case upcoming = "Upcoming", live = "Live", past = "Past"
        var status: String {
            switch self {
            case .upcoming: return "upcoming"
            case .live: return "inProgress"
            case .past: return "complete"
            }
        }
    }

    var body: some View {
        ScrollView {
            switch phase {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, minHeight: 300).padding(.top, 60)
            case .failed(let message):
                Text(message).font(.system(size: 14)).foregroundStyle(EventsTheme.textSecondary)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 80).padding(.horizontal, 24)
            case .loaded:
                VStack(alignment: .leading, spacing: 18) {
                    if let store {
                        header(store)
                    }
                    whenPicker
                    eventsList
                }
                .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 24)
            }
        }
        .background(EventsTheme.bg.ignoresSafeArea())
        .refreshable { await loadEvents(reset: true) }
        .navigationTitle(store?.name ?? "Store")
        .task { await load() }
    }

    // MARK: - Favorite

    private var isFavorite: Bool { StoreFavorites.contains(storeID, in: favRaw) }

    private func toggleFavorite() {
        guard let store else { return }
        let fav = FavoriteStore(id: storeID, name: store.name, subtitle: store.fullAddress, numericID: store.id)
        favRaw = StoreFavorites.toggling(fav, in: favRaw)
    }

    // MARK: - Header

    @ViewBuilder
    private func header(_ store: LocatorStore) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(store.name).font(.system(size: 21, weight: .heavy)).foregroundStyle(.white)
                if store.isPremium == true {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundStyle(EventsTheme.green)
                }
                Spacer(minLength: 8)
                Button { toggleFavorite() } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isFavorite ? EventsTheme.green : Color.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(EventsTheme.cardInset))
                }
                .buttonStyle(.plain)
            }
            if let address = store.fullAddress, !address.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "location")
                    Text(address)
                }
                .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
            }
            HStack(spacing: 16) {
                if let url = websiteURL(store.website) {
                    Link(destination: url) {
                        Text("Website").font(.system(size: 13, weight: .medium))
                            .foregroundStyle(EventsTheme.green)
                    }
                }
                if let url = locatorURL {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                            Text("Locator")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(EventsTheme.green)
                    }
                }
                if let seats = store.seatCount, seats > 0 {
                    Text("\(seats) seats")
                        .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(colors: [EventsTheme.overviewFillTop, EventsTheme.overviewFillBottom],
                           startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(EventsTheme.hairline, lineWidth: 1))
    }

    // MARK: - When filter

    private var whenPicker: some View {
        HStack(spacing: 8) {
            ForEach(When.allCases, id: \.self) { option in
                let selected = when == option
                Button {
                    when = option
                    Task { await loadEvents(reset: true) }
                } label: {
                    Text(option.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected ? EventsTheme.matchFillBottom : EventsTheme.textSecondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selected ? EventsTheme.green : EventsTheme.card)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Events

    @ViewBuilder
    private var eventsList: some View {
        if eventsLoading && events.isEmpty {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
        } else if events.isEmpty {
            Text(eventsError ? "Couldn't load events. Pull down to retry." : "No \(when.rawValue.lowercased()) events.")
                .font(.system(size: 14)).foregroundStyle(eventsError ? Color.red : EventsTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity).padding(.top, 30).padding(.horizontal, 24)
        } else {
            VStack(spacing: 9) {
                ForEach(events) { eventRow($0) }
                if nextPage != nil { loadMoreRow }
            }
        }
    }

    private func eventRow(_ event: LocatorStoreEvent) -> some View {
        NavigationLink(value: EventRoute(id: event.id, alias: nil)) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
                    HStack(spacing: 8) {
                        if let date = event.startDatetime {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
                        }
                        Text(event.priceText).font(.system(size: 12)).foregroundStyle(EventsTheme.textTertiary)
                    }
                }
                Spacer(minLength: 8)
                if event.isLive { LiveBadge(pulsing: true) }
                else { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(EventsTheme.textTertiary) }
            }
            .padding(.vertical, 12).padding(.horizontal, 14)
            .eventsCard(radius: 14)
        }
        .buttonStyle(.plain)
    }

    /// The store's page on the Riftbound Locator website (keyed by the game-store UUID).
    private var locatorURL: URL? {
        URL(string: "https://locator.riftbound.uvsgames.com/stores/\(storeID)?view=grid")
    }

    /// Build a URL from a store website string, defaulting to https:// when
    /// the site omits a scheme.
    private func websiteURL(_ raw: String?) -> URL? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        return URL(string: withScheme)
    }

    private var loadMoreRow: some View {
        Button { Task { await loadEvents(reset: false) } } label: {
            HStack {
                Spacer()
                if eventsLoading {
                    ProgressView()
                } else {
                    Text(eventsError ? "Couldn't load more. Tap to retry." : "Load more")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(eventsError ? Color.red : EventsTheme.textSecondary)
                }
                Spacer()
            }
            .padding(.vertical, 14).eventsCard(radius: 14)
        }
        .buttonStyle(.plain)
        .disabled(eventsLoading)
    }

    // MARK: - Load

    @MainActor
    private func load() async {
        phase = .loading
        do {
            store = try await service.store(id: storeID).store
            phase = .loaded
            await loadEvents(reset: true)
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    @MainActor
    private func loadEvents(reset: Bool) async {
        guard let sid = store?.id, !eventsLoading else { return }
        if reset { events = []; nextPage = nil }
        let page = reset ? 1 : (nextPage ?? 1)
        eventsLoading = true
        eventsError = false
        defer { eventsLoading = false }
        if let result = try? await service.storeEvents(storeID: sid, status: when.status, page: page) {
            events = reset ? result.results : events + result.results
            nextPage = result.nextPageNumber
        } else {
            eventsError = true
        }
    }
}
