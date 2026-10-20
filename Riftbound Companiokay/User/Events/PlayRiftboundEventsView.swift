//
//  PlayRiftboundEventsView.swift
//  Riftbound Companiokay
//
//  Native "my events" list on PlayRiftbound data: upcoming and past
//  registrations as cards (date badge, name, format line, price, players,
//  store). A card pushes the native event screen.
//

import SwiftUI

struct PlayRiftboundEventsView: View {
    @EnvironmentObject private var store: PlayRiftboundEventsStore
    @EnvironmentObject private var browser: PlayRiftboundBrowser
    /// Switches to the PlayRiftbound segment (sign-in, find an event).
    var openSite: (URL?) -> Void

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 24)
        }
        .refreshable { await store.refresh(browser: browser, force: true) }
        .task { await store.refresh(browser: browser) }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .idle, .loading:
            ProgressView().tint(EventsTheme.green).frame(maxWidth: .infinity, minHeight: 300)
        case .signedOut:
            notice("person.crop.circle.badge.questionmark", "Sign in on PlayRiftbound",
                   "Your registered events show up here once you are signed in.", button: "Open PlayRiftbound") { openSite(nil) }
        case .failed(let message):
            notice("wifi.exclamationmark", "Couldn't load events", message, button: "Retry") {
                Task { await store.refresh(browser: browser, force: true) }
            }
        case .loaded:
            if store.hasEvents {
                VStack(alignment: .leading, spacing: 22) {
                    findButton
                    if let live = liveEntry { liveHero(live) }
                    if !store.upcoming.isEmpty { section("calendar", "Upcoming", store.upcoming) }
                    if !store.past.isEmpty { section("clock.arrow.circlepath", "Past", store.past) }
                }
            } else {
                VStack(spacing: 16) {
                    findButton
                    notice("trophy", "No events yet", "Events you register for on PlayRiftbound show up here.",
                           button: "Find an event") { openSite(PlayRiftboundPolicy.home) }
                }
            }
        }
    }

    /// An event that started within the last eight hours (or starts within the hour).
    private var liveEntry: PlayerTournamentEntry? {
        let now = Date()
        return store.upcoming.first { entry in
            guard let start = entry.tournament.startsAt else { return false }
            return start <= now.addingTimeInterval(3600) && start >= now.addingTimeInterval(-8 * 3600)
        }
    }

    private func liveHero(_ entry: PlayerTournamentEntry) -> some View {
        NavigationLink(value: entry) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Circle().fill(EventsTheme.green).frame(width: 7, height: 7)
                        Text("LIVE NOW").font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(EventsTheme.green)
                    }
                    Text(entry.tournament.name).font(.system(size: 17, weight: .bold)).foregroundStyle(.white).lineLimit(2)
                    Text([entry.organizer?.name, entry.tournament.startsAt?.formatted(date: .omitted, time: .shortened)].compactMap { $0 }.joined(separator: " • "))
                        .font(.system(size: 12.5)).foregroundStyle(EventsTheme.textSecondary)
                    Text("Your pairing, standings and Report are inside.")
                        .font(.system(size: 12)).foregroundStyle(EventsTheme.textTertiary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(EventsTheme.green)
            }
            .padding(15).frame(maxWidth: .infinity, alignment: .leading)
            .greenGradientBorder(radius: 16)
        }
        .buttonStyle(.plain)
    }

    private var findButton: some View {
        NavigationLink(value: PlayRiftboundSearchRoute()) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                Text("Find events near you")
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12))
            }
            .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 14).frame(height: 44)
            .eventsCard(radius: 13)
        }
        .buttonStyle(.plain)
    }

    private func section(_ symbol: String, _ title: String, _ entries: [PlayerTournamentEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(symbol, title)
            ForEach(entries, id: \.tournament.id) { entry in
                NavigationLink(value: entry) { PlayRiftboundEventCard(entry: entry) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func notice(_ symbol: String, _ title: String, _ text: String,
                        button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 34)).foregroundStyle(EventsTheme.textTertiary)
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
            Text(text).font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button(button, action: action).tint(EventsTheme.green).padding(.top, 4)
        }
        .frame(maxWidth: .infinity).padding(.top, 60).padding(.horizontal, 24)
    }
}

// MARK: - Card

struct PlayRiftboundEventCard: View {
    let entry: PlayerTournamentEntry
    var distanceMeters: Double? = nil
    /// From the search: the player is registered for this one.
    var registered: Bool = false

    private var tournament: CompeteTournamentSummary { entry.tournament }

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            dateBadge
            VStack(alignment: .leading, spacing: 6) {
                Text(tournament.name)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
                if let line = formatLine {
                    Text(line).font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
                }
                HStack(spacing: 6) {
                    pill(priceText)
                    pill(playersText, symbol: "person.2")
                    if registered {
                        Text("Registered").font(.system(size: 11, weight: .semibold)).foregroundStyle(EventsTheme.green)
                            .padding(.horizontal, 8).padding(.vertical, 4).background(EventsTheme.greenSoft, in: Capsule())
                    }
                }
                if let store = storeLine {
                    Label(store, systemImage: entry.organizer?.isFavorited == true ? "heart.fill" : "mappin")
                        .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(EventsTheme.textTertiary)
                .padding(.top, 4)
        }
        .padding(.vertical, 13).padding(.horizontal, 15)
        .eventsCard(radius: 15)
    }

    private var dateBadge: some View {
        VStack(spacing: 2) {
            if let date = tournament.startsAt {
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                Text(date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.system(size: 10)).foregroundStyle(EventsTheme.textSecondary)
                Text(date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10)).foregroundStyle(EventsTheme.textTertiary)
            } else {
                Text("TBD").font(.system(size: 12, weight: .semibold)).foregroundStyle(EventsTheme.textSecondary)
            }
        }
        .frame(width: 44)
    }

    /// "Constructed • 1v1 • Swiss" from the config enums, as the site shows it.
    private var formatLine: String? {
        guard let config = tournament.config else { return nil }
        let parts = [config.format, config.playerFormat, config.tournamentType].compactMap { $0 }.map(Self.humanize)
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private var priceText: String {
        if let fee = tournament.entryFee, fee.minorUnits > 0 {
            let amount = Decimal(fee.minorUnits) / 100
            return amount.formatted(.currency(code: fee.currency).precision(.fractionLength(0...2)))
        }
        return tournament.pricing.map(Self.humanize) ?? "Free"
    }

    private var playersText: String {
        let count = tournament.registeredCount
        if let cap = tournament.config?.participantCapacity, cap > 0 { return "\(count)/\(cap)" }
        return "\(count)"
    }

    private var storeLine: String? {
        guard let organizer = entry.organizer else { return nil }
        var parts = [organizer.name, organizer.physicalAddress?.city].compactMap { $0 }
        if let distanceMeters { parts.append(String(format: "%.0f km", distanceMeters / 1000)) }
        return parts.joined(separator: " • ")
    }

    private func pill(_ text: String, symbol: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.system(size: 10)) }
            Text(text)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(EventsTheme.textSecondary)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(EventsTheme.cardInset, in: Capsule())
    }

    nonisolated static func humanize(_ raw: String) -> String { PlayRiftboundFormat.humanize(raw) }
}
