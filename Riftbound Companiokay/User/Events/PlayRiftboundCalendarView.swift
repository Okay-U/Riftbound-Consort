//
//  PlayRiftboundCalendarView.swift
//  Riftbound Companiokay
//
//  Month calendar of upcoming events at the player's favourite stores plus
//  everything they are registered for. Registered = solid green dot, not
//  registered = outline. Tap a day to list its events, tap an event to open
//  it. Store events come from the search centred on each store.
//

import SwiftUI

struct PlayRiftboundCalendarRoute: Hashable {}

struct PlayRiftboundCalendarView: View {
    @EnvironmentObject private var browser: PlayRiftboundBrowser
    @EnvironmentObject private var events: PlayRiftboundEventsStore

    @State private var items: [CalEvent] = []
    @State private var loading = true
    @State private var loadError: String?
    @State private var hasFavourites = true
    @State private var month = Date()
    @State private var selectedDay: Date?

    struct CalEvent: Identifiable {
        let entry: PlayerTournamentEntry
        let registered: Bool
        var id: String { entry.tournament.id }
        var date: Date { entry.tournament.startsAt ?? .distantFuture }
    }

    private let api = PlayRiftboundAPI()
    private let cal = Calendar.current

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                monthHeader
                weekdayRow
                grid
                legend
                if !loading, items.isEmpty { emptyOrError }
                if let day = selectedDay { dayEvents(day) }
            }
            .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 24)
        }
        .background(EventsTheme.bg.ignoresSafeArea())
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(EventsTheme.bg, for: .navigationBar)
        .refreshable { await load() }
        .overlay { if loading { ProgressView().tint(.white) } }
        .task { await load() }
    }

    // MARK: - Header / grid

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
            Spacer()
            Button { changeMonth(1) } label: { Image(systemName: "chevron.right") }
        }
        .font(.system(size: 16, weight: .semibold))
        .tint(EventsTheme.green)
    }

    private var weekdayRow: some View {
        HStack(spacing: 4) {
            ForEach(weekdaySymbols, id: \.self) { sym in
                Text(sym).font(.system(size: 11, weight: .semibold)).foregroundStyle(EventsTheme.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(0..<(leadingBlanks + daysInMonth), id: \.self) { index in
                if index < leadingBlanks {
                    Color.clear.frame(height: 44)
                } else {
                    dayCell(index - leadingBlanks + 1)
                }
            }
        }
    }

    private func dayCell(_ day: Int) -> some View {
        let date = dateFor(day: day)
        let evs = eventsOn(date)
        let selected = selectedDay.map { cal.isDate($0, inSameDayAs: date) } ?? false
        let today = cal.isDateInToday(date)
        return Button {
            selectedDay = evs.isEmpty ? nil : date
        } label: {
            VStack(spacing: 4) {
                Text("\(day)")
                    .font(.system(size: 14, weight: selected || today ? .bold : .regular))
                    .foregroundStyle(selected ? EventsTheme.green : (today ? EventsTheme.gold : .white))
                dot(evs)
            }
            .frame(maxWidth: .infinity).frame(height: 44)
            .background(selected ? EventsTheme.greenSoft : Color.clear,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(evs.isEmpty)
    }

    @ViewBuilder
    private func dot(_ evs: [CalEvent]) -> some View {
        if evs.isEmpty {
            Circle().fill(.clear).frame(width: 6, height: 6)
        } else if evs.contains(where: { $0.registered }) {
            Circle().fill(EventsTheme.green).frame(width: 6, height: 6)
        } else {
            Circle().stroke(EventsTheme.green, lineWidth: 1.5).frame(width: 6, height: 6)
        }
    }

    private var emptyOrError: some View {
        let (icon, message): (String, String) = if let loadError {
            ("wifi.exclamationmark", loadError)
        } else if !hasFavourites {
            ("heart", "No favourite stores yet. Open a store and tap the heart; its events show up here.")
        } else {
            ("calendar", "No upcoming events at your favourite stores.")
        }
        return VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 28)).foregroundStyle(EventsTheme.textTertiary)
            Text(message).font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 30).padding(.horizontal, 24)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Circle().fill(EventsTheme.green).frame(width: 7, height: 7)
                Text("Registered").font(.system(size: 11)).foregroundStyle(EventsTheme.textSecondary)
            }
            HStack(spacing: 6) {
                Circle().stroke(EventsTheme.green, lineWidth: 1.5).frame(width: 7, height: 7)
                Text("At a favourite store").font(.system(size: 11)).foregroundStyle(EventsTheme.textSecondary)
            }
            Spacer()
        }
    }

    // MARK: - Selected day

    @ViewBuilder
    private func dayEvents(_ day: Date) -> some View {
        let evs = eventsOn(day)
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader("calendar", day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            ForEach(evs) { event in
                NavigationLink(value: event.entry) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(event.registered ? EventsTheme.green : Color.clear)
                            .overlay(Circle().stroke(EventsTheme.green, lineWidth: 1.5))
                            .frame(width: 9, height: 9)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.entry.tournament.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
                            HStack(spacing: 8) {
                                Text(event.date.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
                                if let store = event.entry.organizer?.name {
                                    Text(store).font(.system(size: 12)).foregroundStyle(EventsTheme.textTertiary).lineLimit(1)
                                }
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
        }
    }

    // MARK: - Date helpers

    private var monthStart: Date { cal.date(from: cal.dateComponents([.year, .month], from: month)) ?? month }
    private var daysInMonth: Int { cal.range(of: .day, in: .month, for: month)?.count ?? 30 }
    private var leadingBlanks: Int { (cal.component(.weekday, from: monthStart) - cal.firstWeekday + 7) % 7 }
    private func dateFor(day: Int) -> Date { cal.date(byAdding: .day, value: day - 1, to: monthStart) ?? monthStart }
    private func eventsOn(_ date: Date) -> [CalEvent] {
        items.filter { cal.isDate($0.date, inSameDayAs: date) }.sorted { $0.date < $1.date }
    }
    private var weekdaySymbols: [String] {
        let symbols = cal.shortWeekdaySymbols
        let offset = cal.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }
    private func changeMonth(_ delta: Int) {
        if let next = cal.date(byAdding: .month, value: delta, to: month) { month = next; selectedDay = nil }
    }

    // MARK: - Load

    /// Registered events first (always shown), then every favourite store's upcoming events.
    private func load() async {
        loading = items.isEmpty
        loadError = nil
        let credentials = await PlayRiftboundSession.credentials()
        await events.refresh(browser: browser)
        let registeredIDs = Set(events.upcoming.map(\.tournament.id))
        var collected: [String: CalEvent] = [:]
        for entry in events.upcoming { collected[entry.tournament.id] = CalEvent(entry: entry, registered: true) }

        if let credentials, !credentials.isExpired {
            do {
                let favourites = try await api.favoritedOrganizers(credentials: credentials)
                hasFavourites = !favourites.isEmpty
                let results = await withTaskGroup(of: [CompeteSearchResult].self) { group in
                    for store in favourites {
                        group.addTask { [api] in
                            guard let summary = try? await api.organizerSummary(id: store.id, credentials: credentials),
                                  let lat = summary.physicalAddress?.latitude, let lng = summary.physicalAddress?.longitude else { return [] }
                            return (try? await api.storeEvents(organizerID: store.id, latitude: lat, longitude: lng, credentials: credentials)) ?? []
                        }
                    }
                    var all: [CompeteSearchResult] = []
                    for await part in group { all += part }
                    return all
                }
                for result in results where collected[result.tournament.id] == nil {
                    collected[result.tournament.id] = CalEvent(entry: result.entry, registered: registeredIDs.contains(result.tournament.id))
                }
            } catch {
                loadError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        } else {
            hasFavourites = false
            if collected.isEmpty { loadError = PlayRiftboundError.notSignedIn.errorDescription }
        }
        items = collected.values.sorted { $0.date < $1.date }
        loading = false
    }
}
