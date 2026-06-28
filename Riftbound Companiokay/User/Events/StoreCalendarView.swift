//
//  StoreCalendarView.swift
//  Riftbound Companiokay
//
//  Month calendar of upcoming events at your favorite stores. Registered events
//  = solid green dot, not-registered = green outline. Tap a day to list its
//  events; tap an event to open it.
//

import SwiftUI

struct StoreCalendarView: View {
    @EnvironmentObject private var session: AuthSession
    @AppStorage(StoreFavorites.key) private var favRaw = "[]"
    @Environment(\.dismiss) private var dismiss
    var service: any LocatorService = RiftboundLocatorService()

    @State private var events: [CalEvent] = []
    @State private var loading = true
    @State private var loadError: String?
    @State private var month = Date()
    @State private var selectedDay: Date?

    struct CalEvent: Identifiable {
        let id: Int
        let name: String
        let date: Date
        let registered: Bool
        let storeName: String?
    }

    private let cal = Calendar.current

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                monthHeader
                weekdayRow
                grid
                legend
                if !loading, events.isEmpty { emptyOrError }
                if let day = selectedDay { dayEvents(day) }
            }
            .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 24)
        }
        .background(EventsTheme.bg.ignoresSafeArea())
        .refreshable { await load() }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 36, height: 36).background(EventsTheme.card, in: Circle())
                        .overlay(Circle().stroke(EventsTheme.hairline, lineWidth: 1))
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Calendar").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            }
        }
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
        return Button {
            selectedDay = evs.isEmpty ? nil : date
        } label: {
            VStack(spacing: 4) {
                Text("\(day)")
                    .font(.system(size: 14, weight: selected ? .bold : .regular))
                    .foregroundStyle(selected ? EventsTheme.green : .white)
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
        let noFavorites = StoreFavorites.decode(favRaw).isEmpty
        let icon: String
        let message: String
        if let loadError {
            icon = "wifi.exclamationmark"; message = loadError
        } else if noFavorites {
            icon = "heart"
            message = "No favorite stores yet. Search the Stores tab and tap the heart to save one. Its events show up here."
        } else {
            icon = "calendar"
            message = "No upcoming events at your favorite stores."
        }
        return VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28)).foregroundStyle(EventsTheme.textTertiary)
            Text(message)
                .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
                .multilineTextAlignment(.center)
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
                Text("Not registered").font(.system(size: 11)).foregroundStyle(EventsTheme.textSecondary)
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
                NavigationLink(value: EventRoute(id: event.id, alias: nil)) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(event.registered ? EventsTheme.green : Color.clear)
                            .overlay(Circle().stroke(EventsTheme.green, lineWidth: 1.5))
                            .frame(width: 9, height: 9)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
                            HStack(spacing: 8) {
                                Text(event.date.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
                                if let store = event.storeName {
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
    private var leadingBlanks: Int {
        (cal.component(.weekday, from: monthStart) - cal.firstWeekday + 7) % 7
    }
    private func dateFor(day: Int) -> Date { cal.date(byAdding: .day, value: day - 1, to: monthStart) ?? monthStart }
    private func eventsOn(_ date: Date) -> [CalEvent] {
        let start = cal.startOfDay(for: date)
        return events.filter { cal.isDate($0.date, inSameDayAs: start) }.sorted { $0.date < $1.date }
    }
    private var weekdaySymbols: [String] {
        let symbols = cal.shortWeekdaySymbols
        let offset = cal.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }
    private func changeMonth(_ delta: Int) {
        if let next = cal.date(byAdding: .month, value: delta, to: month) {
            month = next
            selectedDay = nil
        }
    }

    // MARK: - Load

    @MainActor
    private func load() async {
        loading = true
        loadError = nil
        defer { loading = false }

        // Registered ids drive the dot fill; best-effort, failure here only dims dots.
        var registeredIDs = Set<Int>()
        if let token = session.token, let page = try? await service.myEvents(token: token, page: 1) {
            for ues in page.results where isActiveRegistration(ues.registrationStatus) {
                registeredIDs.insert(ues.event.id)
            }
        }

        // Fetch every favorite store's events in parallel (nil result = that fetch failed).
        let service = self.service
        let favorites = StoreFavorites.decode(favRaw)
        let fetched: [(String, [LocatorStoreEvent]?)] = await withTaskGroup(
            of: (String, [LocatorStoreEvent]?).self
        ) { group in
            for fav in favorites {
                guard let numericID = fav.numericID else { continue }
                let name = fav.name
                group.addTask {
                    let page = try? await service.storeEvents(storeID: numericID, status: "upcoming", page: 1)
                    return (name, page?.results)
                }
            }
            var out: [(String, [LocatorStoreEvent]?)] = []
            for await result in group { out.append(result) }
            return out
        }

        var collected: [CalEvent] = []
        var anyFailed = false
        for (favName, storeEvents) in fetched {
            guard let storeEvents else { anyFailed = true; continue }
            for event in storeEvents {
                guard let date = event.startDatetime else { continue }
                collected.append(CalEvent(id: event.id, name: event.name, date: date,
                                          registered: registeredIDs.contains(event.id),
                                          storeName: favName))
            }
        }
        events = collected
        if collected.isEmpty, anyFailed {
            loadError = "Couldn't load events. Pull down to retry."
        }
        if let earliest = collected.map(\.date).min() {
            month = earliest
            selectedDay = cal.startOfDay(for: earliest)
        }
    }
}
