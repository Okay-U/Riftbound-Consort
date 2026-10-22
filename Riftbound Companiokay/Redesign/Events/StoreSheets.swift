//
//  StoreSheets.swift
//  Riftbound Companiokay
//
//  One store and the month (Android `StoreSheets.kt`, classic `PlayRiftboundStoreView` and
//  `PlayRiftboundCalendarView`): contact rows, the favourite heart and the store's upcoming events; the month
//  with a solid dot where the player is registered and a ring where a favourite store has an event.
//

import SwiftUI

struct StoreSheet: View {
    let store: CompeteOrganizer
    let onOpen: (EventsRoute) -> Void
    let onToast: (String) -> Void
    @EnvironmentObject private var events: PlayRiftboundEventsStore
    @EnvironmentObject private var favorites: PlayRiftboundFavorites
    @EnvironmentObject private var browser: PlayRiftboundBrowser
    @EnvironmentObject private var calendar: RiftCalendar
    @Environment(\.openURL) private var openURL
    @State private var summary: CompeteOrganizerSummary?
    @State private var upcoming: [CompeteSearchResult]?
    @State private var error: String?

    var body: some View {
        RiftSheet(title: store.name, detents: [.large]) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(store.name).font(RiftFont.display(26)).foregroundStyle(.white)
                    if let address = summary?.physicalAddress?.formattedAddress ?? store.physicalAddress?.formattedAddress {
                        Text(address).font(RiftFont.text(13)).lineSpacing(4).foregroundStyle(.white.opacity(0.7)).padding(.top, 6).padding(.bottom, 12)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if favorites.signedIn == true { heart }
            }
            contact
            EvCaption(left: "Upcoming events", right: upcoming.map { "\($0.count)" })
            list
        }
        .task(id: store.id) { await load() }
    }

    private var heart: some View {
        let on = favorites.contains(store.id)
        return Button {
            Task {
                do {
                    try await favorites.toggle(store, browser: browser)
                    let now = favorites.contains(store.id)
                    Haptics.selection()
                    onToast(now ? "\(store.name) is a favourite" : "\(store.name) removed from favourites")
                    // A new favourite's events join the rail and the month.
                    calendar.invalidate()
                    if now { await calendar.load(events: events, favorites: favorites, browser: browser) }
                } catch {
                    onToast((error as? LocalizedError)?.errorDescription ?? "Couldn't change the favourite")
                }
            }
        } label: {
            Image(systemName: on ? "heart.fill" : "heart")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(on ? RiftColor.you : .white)
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.06), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(PressScale(scale: 0.92))
        .disabled(favorites.pending.contains(store.id))
        .opacity(favorites.pending.contains(store.id) ? 0.3 : 1)
        .accessibilityLabel(on ? "Remove from favourites" : "Add to favourites")
    }

    @ViewBuilder
    private var contact: some View {
        if let summary {
            let rows = contactRows(summary)
            if !rows.isEmpty {
                SettingsGroup {
                    ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                        Button { openURL(row.url) } label: {
                            HStack(spacing: 12) {
                                Text(row.label).font(RiftFont.text(14.5, .semibold)).foregroundStyle(.white)
                                Text(row.value).font(RiftFont.text(12.5)).foregroundStyle(.white.opacity(0.55)).lineLimit(1).frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 54)
                            .overlay(alignment: .top) { if i > 0 { Hairline() } }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressScale(scale: 0.99))
                        .accessibilityLabel("\(row.label) \(row.value)")
                    }
                }
            }
        }
    }

    private func contactRows(_ s: CompeteOrganizerSummary) -> [(label: String, value: String, url: URL)] {
        var rows: [(String, String, URL)] = []
        if let lat = s.physicalAddress?.latitude, let lng = s.physicalAddress?.longitude,
           let url = URL(string: "https://maps.apple.com/?ll=\(lat),\(lng)&q=\(store.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            rows.append(("Directions", s.physicalAddress?.city ?? "Map", url))
        }
        if let website = s.website, !website.trimmingCharacters(in: .whitespaces).isEmpty,
           let url = URL(string: website.hasPrefix("http") ? website : "https://" + website) {
            rows.append(("Website", website.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: ""), url))
        }
        if let email = s.email, !email.isEmpty, let url = URL(string: "mailto:\(email)") { rows.append(("Email", email, url)) }
        if let phone = s.phone?.display, let url = URL(string: "tel:\(phone.filter { !$0.isWhitespace })") { rows.append(("Phone", phone, url)) }
        return rows
    }

    @ViewBuilder
    private var list: some View {
        if let upcoming {
            if upcoming.isEmpty {
                EvMessage(text: error ?? "No upcoming events listed for this store.").padding(.vertical, 18)
            } else {
                let registered = Set(events.upcoming.map(\.tournament.id))
                VStack(spacing: 8) {
                    ForEach(upcoming, id: \.tournament.id) { result in
                        let s = result.tournament
                        let when = s.startsAt.map { "\(EvFmt.weekday($0)) \(EvFmt.shortDate($0)) · \(EvFmt.time($0))" }
                        UCard(name: s.name, sub: [when, EvFmt.formatLine(s.config?.format, s.config?.playerFormat)].compactMap { $0 }.joined(separator: " · "),
                              action: { onOpen(.event(result.entry)) }) {
                            EvPill(text: EvFmt.price(fee: s.entryFee, pricing: s.pricing))
                            EvPill(text: EvFmt.players(s.registeredCount, cap: s.config?.participantCapacity))
                            if registered.contains(s.id) { EvPill(text: "Registered", bg: RiftColor.you.opacity(0.16), ink: RiftColor.you) }
                        }
                    }
                }
            }
        } else {
            EvLoading(text: "Loading the store's events")
        }
    }

    private func load() async {
        if favorites.signedIn == nil { await favorites.load(browser: browser) }
        let api = PlayRiftboundAPI()
        do {
            let credentials = try? await PlayRiftboundSession.validCredentials(refreshingVia: browser)
            let found = try await api.organizerSummary(id: store.id, credentials: credentials ?? nil)
            summary = found
            guard let lat = found?.physicalAddress?.latitude ?? store.physicalAddress?.latitude,
                  let lng = found?.physicalAddress?.longitude ?? store.physicalAddress?.longitude else {
                error = "This store has no location on PlayRiftbound, so its events can't be listed."
                upcoming = []
                return
            }
            upcoming = try await api.storeEvents(organizerID: store.id, latitude: lat, longitude: lng, credentials: credentials ?? nil)
                .sorted { ($0.tournament.startsAt ?? .distantFuture) < ($1.tournament.startsAt ?? .distantFuture) }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            upcoming = []
        }
    }
}

/// The month: a solid dot where you are registered, a ring where a favourite store has an event; a day lists its events.
struct MonthSheet: View {
    let onOpen: (EventsRoute) -> Void
    @EnvironmentObject private var events: PlayRiftboundEventsStore
    @EnvironmentObject private var favorites: PlayRiftboundFavorites
    @EnvironmentObject private var browser: PlayRiftboundBrowser
    @EnvironmentObject private var calendar: RiftCalendar
    @Environment(\.dismiss) private var dismiss
    @State private var month = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var day = Calendar.current.startOfDay(for: Date())

    var body: some View {
        let cal = Calendar.current
        let items = calendar.items(upcoming: events.upcoming, favorites: favorites.signedIn == true ? favorites.stores : [])
        let days = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let lead = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        let cells: [Date?] = Array(repeating: nil, count: lead) + (0..<days).map { cal.date(byAdding: .day, value: $0, to: month) }
        let symbols = cal.shortWeekdaySymbols
        let names = Array(symbols[(cal.firstWeekday - 1)...] + symbols[..<(cal.firstWeekday - 1)]).map { String($0.uppercased().prefix(2)) }
        RiftSheet(title: "Calendar", detents: [.large]) {
            HStack {
                arrow("chevron.left", "Previous month") { shift(-1) }
                Text(EvFmt.monthYear(month)).font(RiftFont.display(26)).foregroundStyle(.white).frame(maxWidth: .infinity)
                arrow("chevron.right", "Next month") { shift(1) }
            }
            .padding(.top, 6)
            HStack(spacing: 4) {
                ForEach(Array(names.enumerated()), id: \.offset) { _, name in
                    Text(name).caps(10.5, tracking: 0.1).foregroundStyle(.white.opacity(0.45)).frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 12)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let evs = items.filter { cal.sameDay($0.startsAt, date) }
                        DayCell(date: date, events: evs.count, registered: evs.contains { $0.registered }, on: cal.sameDay(date, day), today: cal.isDateInToday(date)) { day = date }
                    } else {
                        Color.clear.frame(height: 48)
                    }
                }
            }
            .padding(.top, 6)
            Text("Solid dot: you're registered. Ring: an event at a favourite store.")
                .font(RiftFont.text(12.5)).foregroundStyle(.white.opacity(0.6)).padding(.vertical, 10)
            DayList(items: items.filter { cal.sameDay($0.startsAt, day) }, day: day) { item in
                dismiss()
                onOpen(.event(item.entry))
            }
            EvButton(text: "Done", kind: .ghost) { dismiss() }.padding(.top, 12)
        }
        .task { await calendar.load(events: events, favorites: favorites, browser: browser) }
    }

    private func arrow(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        RoundIcon(symbol: symbol, label: label, fill: .white.opacity(0.06), action: action)
            .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
    }

    private func shift(_ by: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: by, to: month) { month = next }
    }
}

private struct DayCell: View {
    let date: Date
    let events: Int
    let registered: Bool
    let on: Bool
    let today: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14)
        Button(action: action) {
            ZStack(alignment: .bottom) {
                Text(EvFmt.day(date))
                    .font(RiftFont.display(16, weight: 800))
                    .foregroundStyle(on ? Color.black : today ? RiftColor.gold : .white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if events > 0 {
                    Group {
                        if registered {
                            Circle().fill(on ? Color.black : RiftColor.you)
                        } else {
                            Circle().stroke(on ? Color.black : RiftColor.you, lineWidth: 1.5)
                        }
                    }
                    .frame(width: 6, height: 6)
                    .padding(.bottom, 7)
                }
            }
            .frame(height: 48)
            .background(on ? RiftColor.you : .clear, in: shape)
            .overlay(shape.stroke(today && !on ? RiftColor.gold : .clear, lineWidth: 1.5))
            .contentShape(shape)
        }
        .buttonStyle(PressScale(scale: 0.94))
        .accessibilityLabel("\(EvFmt.weekday(date)) \(EvFmt.day(date))" + (events == 0 ? "" : ", \(events) events"))
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
