//
//  StoresPane.swift
//  Riftbound Companiokay
//
//  Stores (Android `StoresPane.kt`, classic `PlayRiftboundStoresView` and calendar, mock's B pane): the next two
//  weeks at favourite stores and the player's own events on a light rail, favourite store cards, and the store
//  finder with a radius rail.
//

import SwiftUI

struct StoresPane: View {
    let active: Bool
    let onSheet: (EventsSheet) -> Void
    let onOpen: (EventsRoute) -> Void
    let onToast: (String) -> Void
    @EnvironmentObject private var events: PlayRiftboundEventsStore
    @EnvironmentObject private var favorites: PlayRiftboundFavorites
    @EnvironmentObject private var browser: PlayRiftboundBrowser
    @EnvironmentObject private var calendar: RiftCalendar
    @Environment(\.scenePhase) private var scenePhase
    @State private var picked = Calendar.current.startOfDay(for: Date())

    var body: some View {
        let items = calendar.items(upcoming: events.upcoming, favorites: favorites.signedIn == true ? favorites.stores : [])
        let today = Calendar.current.startOfDay(for: Date())
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                EvCaption(left: "Next two weeks · favourites and yours", top: 4) {
                    Button { onSheet(.month) } label: {
                        Text("MONTH").caps(11, tracking: 0.16, weight: .bold).foregroundStyle(RiftColor.you)
                    }
                    .buttonStyle(PressScale(scale: 0.95))
                    .accessibilityLabel("Open the month")
                }
                DayRail(items: items, today: today, picked: picked) { picked = $0 }
                DayList(items: items.filter { Calendar.current.sameDay($0.startsAt, picked) }, day: picked) { onOpen(.event($0.entry)) }
                if calendar.failedStores > 0 {
                    Text("Couldn't load the events of \(calendar.failedStores) favourite store\(calendar.failedStores == 1 ? "" : "s").")
                        .font(RiftFont.text(12.5)).foregroundStyle(.white.opacity(0.6)).padding(.top, 8)
                }
                if let error = calendar.error {
                    Text(error).font(RiftFont.text(12.5)).foregroundStyle(.white.opacity(0.6)).padding(.top, 8)
                }
                if favorites.signedIn == true {
                    EvCaption(left: "Favourite stores")
                    if favorites.stores.isEmpty {
                        EvMessage(text: "Tap the heart on a store to keep it here.").padding(.vertical, 14)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(favorites.stores, id: \.id) { store in
                                    let next = items.first { $0.entry.organizer?.id == store.id && $0.startsAt >= today }
                                    FavoriteCard(store: store, next: next?.startsAt) { onSheet(.store(store)) }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.horizontal, -16)
                    }
                }
                EvCaption(left: "Find stores")
                StoreFinder(onStore: { onSheet(.store($0)) })
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await calendar.load(events: events, favorites: favorites, browser: browser, force: true) }
        .task(id: active) { if active { await calendar.load(events: events, favorites: favorites, browser: browser) } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, active { Task { await calendar.load(events: events, favorites: favorites, browser: browser) } }
        }
    }
}

/// The 14-day light rail: a node per day, filled where you play, ringed where a favourite store has an event.
private struct DayRail: View {
    let items: [RiftCalendar.Item]
    let today: Date
    let picked: Date
    let onPick: (Date) -> Void
    private static let step: CGFloat = 52

    var body: some View {
        let cal = Calendar.current
        let days = (0..<14).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
        ScrollView(.horizontal, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.12)).frame(width: 13 * Self.step, height: 3).offset(x: 30, y: 44)
                ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                    let evs = items.filter { cal.sameDay($0.startsAt, day) }
                    DayNode(day: day, events: evs.count, registered: evs.contains { $0.registered }, on: cal.sameDay(day, picked)) { onPick(day) }
                        .offset(x: 30 + CGFloat(i) * Self.step - 22)
                }
            }
            .frame(width: 30 + 13 * Self.step + 30, height: 96, alignment: .topLeading)
        }
        .padding(.horizontal, -16)
    }
}

private struct DayNode: View {
    let day: Date
    let events: Int
    let registered: Bool
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(String(EvFmt.weekday(day).uppercased().prefix(2))).caps(10, tracking: 0.1, weight: .bold).foregroundStyle(.white.opacity(0.5))
                ZStack {
                    Circle().fill(registered ? RiftColor.you : events > 0 ? Color.black : .white.opacity(0.14))
                    if !registered && events > 0 { Circle().stroke(RiftColor.you, lineWidth: 2) }
                }
                .frame(width: 14, height: 14)
                .background { if on { Circle().fill(.white.opacity(0.15)).padding(-5) } }
                .shadow(color: registered ? RiftColor.you.opacity(0.8) : .clear, radius: 6)
                .scaleEffect(on ? 1.3 : 1)
                .padding(.top, 14)
                Text(EvFmt.day(day)).font(RiftFont.display(17)).foregroundStyle(.white.opacity(on ? 1 : 0.55)).padding(.top, 10)
            }
            .frame(width: 44, height: 96, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale(scale: 0.94))
        .animation(.rift(0.4), value: on)
        .accessibilityLabel("\(EvFmt.weekday(day)) \(EvFmt.day(day))" + (events == 0 ? "" : ", \(events) events"))
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The picked day's events; slides in from the right out of a blur when the day changes (mock's `itemIn`).
struct DayList: View {
    let items: [RiftCalendar.Item]
    let day: Date
    let onOpen: (RiftCalendar.Item) -> Void

    var body: some View {
        VStack(spacing: 8) {
            if items.isEmpty { EvMessage(text: "Nothing at your favourite stores that day.").padding(.vertical, 18) }
            ForEach(items) { item in
                let s = item.entry.tournament
                UCard(name: s.name, sub: "\(s.startsAt.map(EvFmt.time) ?? "") · \(EvFmt.storeLine(item.entry.organizer) ?? "")", action: { onOpen(item) }) {
                    EvPill(text: EvFmt.price(fee: s.entryFee, pricing: s.pricing))
                    if item.registered { EvPill(text: "Registered", bg: RiftColor.you.opacity(0.16), ink: RiftColor.you) }
                }
            }
        }
        .modifier(DaySlide())
        .id(day)
    }
}

private struct DaySlide: ViewModifier {
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(x: shown ? 0 : 14)
            .blur(radius: shown ? 0 : 8)
            .onAppear { withAnimation(.rift(0.6)) { shown = true } }
    }
}

/// `.fcard`: a favourite store with its next event.
private struct FavoriteCard: View {
    let store: CompeteOrganizer
    let next: Date?
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: "heart.fill").font(.system(size: 16, weight: .semibold)).foregroundStyle(RiftColor.you)
                // Two lines kept for every name, so the cards stand the same height side by side.
                Text(store.name).font(RiftFont.display(22)).foregroundStyle(.white).lineLimit(2, reservesSpace: true).multilineTextAlignment(.leading).padding(.top, 8)
                Text([store.physicalAddress?.city, next.map { "next \(EvFmt.shortDate($0))" } ?? "no events listed"].compactMap { $0 }.joined(separator: " · "))
                    .font(RiftFont.text(12)).foregroundStyle(.white.opacity(0.6)).lineLimit(1).padding(.top, 4)
            }
            .padding(14)
            .frame(width: 200, alignment: .leading)
            .background(Ev.card, in: shape)
            .background(RadialGradient(colors: [RiftColor.you.opacity(0.12), .clear], center: .topTrailing, startRadius: 0, endRadius: 200).clipShape(shape))
            .overlay(shape.stroke(.white.opacity(0.1), lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(PressScale(scale: 0.97))
        .accessibilityLabel("Open \(store.name)")
    }
}

/// One store found by the finder: its nearest event's distance, how many events, the next one.
private struct StoreHit: Identifiable {
    let organizer: CompeteOrganizer
    let distance: Double?
    let next: Date?
    let count: Int
    var id: String { organizer.id }
}

/// The finder: a place, the radius light rail, stores with upcoming events nearest first.
private struct StoreFinder: View {
    let onStore: (CompeteOrganizer) -> Void
    @AppStorage("riftSearchPlace") private var place = ""
    @AppStorage("riftSearchLat") private var latitude: Double = 0
    @AppStorage("riftSearchLng") private var longitude: Double = 0
    @AppStorage("riftSearchKm") private var km = 50
    @State private var draft = ""
    @State private var hits: [StoreHit]?
    @State private var message: String?
    @State private var loading = false
    @State private var generation = 0

    private var known: Bool { latitude != 0 || longitude != 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlaceField(text: $draft, onSubmit: locate)
            RadiusRail(km: km) { km = $0; search() }
            if loading && (hits ?? []).isEmpty {
                EvLoading(text: "Looking for stores")
            } else if let message {
                EvMessage(text: message).padding(.vertical, 18).padding(.horizontal, 10)
            } else if let hits {
                SettingsGroup {
                    ForEach(Array(hits.enumerated()), id: \.element.id) { i, hit in
                        Button { onStore(hit.organizer) } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(hit.organizer.name).font(RiftFont.text(15, .semibold)).foregroundStyle(.white).lineLimit(1)
                                    Text([hit.organizer.physicalAddress?.city, hit.distance.map { String(format: "%.0f km", $0 / 1000) }].compactMap { $0 }.joined(separator: " • "))
                                        .font(RiftFont.text(12.5)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                                }
                                Spacer(minLength: 8)
                                EvPill(text: "\(hit.count)" + (hit.next.map { " · next \(EvFmt.shortDate($0))" } ?? ""))
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 60)
                            .overlay(alignment: .top) { if i > 0 { Hairline() } }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressScale(scale: 0.99))
                        .accessibilityLabel("Open \(hit.organizer.name)")
                    }
                }
                .padding(.top, 12)
            }
        }
        .onAppear {
            if draft.isEmpty { draft = place }
            if !known { message = "Enter a city to see stores running events nearby." } else if hits == nil { search() }
        }
    }

    private func locate() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        loading = true
        Task {
            guard let found = await SearchPlace.geocode(text) else {
                loading = false
                hits = []
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
        let filter = PlayRiftboundAPI.SearchFilter(coords: .init(latitude: latitude, longitude: longitude), startDate: PlayRiftboundAPI.searchStartDate(),
                                                   distanceMeters: km * 1000, types: nil, formats: nil, playerFormats: nil, favoritedOrganizersOnly: nil)
        loading = true
        Task {
            defer { if request == generation { loading = false } }
            do {
                let api = PlayRiftboundAPI()
                var nodes: [CompeteSearchResult] = []
                var seen = Set<String>()
                var after: String?
                // Nearest first, up to 500 events: enough to reach the edge of the radius in a city.
                for _ in 0..<10 {
                    let page = try await api.searchTournaments(filter: filter, sort: .distance, after: after, first: 50, credentials: await PlayRiftboundSession.publicCredentials())
                    nodes += page.competeTournamentSearch.nodes.filter { seen.insert($0.tournament.id).inserted }
                    guard page.competeTournamentSearch.pageInfo?.hasNextPage == true, let cursor = page.competeTournamentSearch.pageInfo?.endCursor else { break }
                    after = cursor
                }
                guard request == generation else { return }
                let byStore = Dictionary(grouping: nodes.filter { $0.organizer != nil }) { $0.organizer?.id ?? "" }
                let found = byStore.values.compactMap { group -> StoreHit? in
                    guard let organizer = group.first?.organizer else { return nil }
                    return StoreHit(organizer: organizer, distance: group.compactMap(\.distanceMeters).min(),
                                    next: group.compactMap(\.tournament.startsAt).min(), count: group.count)
                }
                .sorted { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }
                hits = found
                message = found.isEmpty ? "No stores with upcoming events within \(km) km of \(place)." : nil
            } catch {
                guard request == generation else { return }
                message = (error as? LocalizedError)?.errorDescription ?? "Couldn't search PlayRiftbound."
            }
        }
    }
}

/// `.rad`: five stops on a line, the line lit up to the chosen radius.
private struct RadiusRail: View {
    let km: Int
    let onPick: (Int) -> Void

    var body: some View {
        let stops = SearchPlace.distances
        let index = max(stops.firstIndex(of: km) ?? 0, 0)
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.12)).frame(width: w, height: 3).offset(y: 16)
                RoundedRectangle(cornerRadius: 2)
                    .fill(RiftColor.you)
                    .frame(width: w, height: 3)
                    .shadow(color: RiftColor.you.opacity(0.8), radius: 5)
                    .scaleEffect(x: CGFloat(index) / CGFloat(stops.count - 1), y: 1, anchor: .leading)
                    .offset(y: 16)
                    .animation(.rift(0.5), value: index)
                ForEach(Array(stops.enumerated()), id: \.offset) { i, d in
                    Button { onPick(d) } label: {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(i <= index ? RiftColor.you : .white.opacity(0.2))
                                .frame(width: 16, height: 16)
                                .shadow(color: i == index ? RiftColor.you.opacity(0.8) : .clear, radius: 7)
                                .scaleEffect(i == index ? 1.3 : 1)
                                .padding(.top, 4)
                            Text("\(d) km")
                                .font(RiftFont.text(10.5, .bold))
                                .foregroundStyle(.white.opacity(i == index ? 1 : 0.55))
                                .fixedSize()
                                .padding(.top, 8)
                        }
                        .frame(width: 28, height: 48, alignment: .top)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressScale(scale: 0.9))
                    .animation(.rift(0.4), value: index)
                    .offset(x: w * CGFloat(i) / CGFloat(stops.count - 1) - 14, y: 4)
                    .accessibilityLabel("\(d) km")
                    .accessibilityAddTraits(i == index ? .isSelected : [])
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }
}
