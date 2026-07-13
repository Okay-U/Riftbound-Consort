//
//  MyEventsView.swift
//  Riftbound Companiokay
//
//  Signed-in overview ("Arena" redesign): custom title + profile menu, a
//  "Your match is up" hero for the live event, then LIVE / Upcoming / Past
//  lists. Paginated via "Load more". Green is the only accent.
//

import SwiftUI

struct MyEventsView: View {
    @EnvironmentObject private var session: AuthSession
    var service: any LocatorService = RiftboundLocatorService()
    var embedded = false   // true when shown under the Events/Stores segmented nav

    @State private var items: [LocatorUserEventStatus] = []
    @State private var status: Status = .idle
    @State private var nextPage: Int?
    @State private var loadingMore = false
    @State private var loadMoreFailed = false
    @State private var hero: HeroMatch?
    @State private var lastLoaded: Date?

    enum Status: Equatable { case idle, loading, loaded, failed(String) }

    struct HeroMatch: Identifiable {
        let eventID: Int
        let eventName: String
        let alias: String?
        let match: ResolvedMyMatch
        let roundLabel: String?
        var id: Int { eventID }
    }

    var body: some View {
        ScrollView {
            switch status {
            case .idle, .loading:
                ProgressView("Loading your events…")
                    .frame(maxWidth: .infinity, minHeight: 400)
            case .failed(let message):
                failed(message)
            case .loaded:
                content
            }
        }
        .background(EventsTheme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await load() }
        .task { if case .idle = status { await load() } }
        .onAppear {
            // Refresh on return (to reflect drops/registrations done elsewhere),
            // but throttle so back-navigation doesn't refetch on every appear.
            guard case .loaded = status else { return }
            if let last = lastLoaded, Date().timeIntervalSince(last) < 20 { return }
            Task { await load() }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 22) {
            if !embedded { headerRow }

            if let hero {
                heroCard(hero)
            }

            if items.isEmpty {
                emptyState
            } else {
                liveSection
                upcomingSection
                pastSection
                if nextPage != nil { loadMoreRow }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    private var headerRow: some View {
        HStack {
            Text("My events")
                .font(.system(size: 31, weight: .bold))
                .foregroundStyle(EventsTheme.textPrimary)
            Spacer()
            NavigationLink(value: StoreSearchRoute()) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17))
                    .foregroundStyle(EventsTheme.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(EventsTheme.card, in: Circle())
                    .overlay(Circle().stroke(EventsTheme.hairline, lineWidth: 1))
            }
            Menu {
                if let name = session.currentUser?.displayName {
                    Text("Signed in as \(name)")
                }
                Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    session.logout()
                }
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(EventsTheme.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(EventsTheme.card, in: Circle())
                    .overlay(Circle().stroke(EventsTheme.hairline, lineWidth: 1))
            }
        }
    }

    // MARK: - Hero ("your match is up")

    @ViewBuilder
    private func heroCard(_ hero: HeroMatch) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                PulsingDot()
                Text("YOUR MATCH IS UP")
                    .font(.system(size: 12, weight: .bold)).tracking(0.4)
                    .foregroundStyle(EventsTheme.green)
            }
            Text("Table \(hero.match.tableNumber.map(String.init) ?? "—")"
                 + (hero.roundLabel.map { " · \($0)" } ?? ""))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(EventsTheme.textPrimary)

            vsRow(hero.match)

            NavigationLink(value: EventRoute(id: hero.eventID, alias: hero.alias)) {
                HStack(spacing: 6) {
                    Text("Open \(hero.eventName)").lineLimit(1)
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(EventsTheme.matchFillBottom)
                .frame(maxWidth: .infinity).frame(height: 42)
                .background(EventsTheme.green, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(alignment: .topTrailing) {
            RadialGradient(colors: [EventsTheme.green.opacity(0.3), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 200)
                .allowsHitTesting(false)
        }
        .greenGradientBorder(radius: 18)
    }

    private func vsRow(_ match: ResolvedMyMatch) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(match.me.displayName).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text("you · \(match.me.record)").font(.system(size: 12)).foregroundStyle(EventsTheme.green)
            }
            Spacer()
            Text("VS").font(.system(size: 12, weight: .bold)).foregroundStyle(EventsTheme.textTertiary)
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(match.opponent?.displayName ?? "TBD").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text(match.opponent?.record ?? "").font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var liveSection: some View {
        let live = grouped(\.event.isActuallyLive, sortDescending: true)
        if !live.isEmpty {
            VStack(alignment: .leading, spacing: 11) {
                SectionHeader("dot.radiowaves.left.and.right", "Live now") {
                    Text("\(live.count) event\(live.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(EventsTheme.textTertiary)
                }
                VStack(spacing: 9) { ForEach(live) { liveRow($0) } }
            }
        }
    }

    @ViewBuilder
    private var upcomingSection: some View {
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 11) {
                SectionHeader("calendar", "Upcoming")
                VStack(spacing: 9) { ForEach(upcoming) { dateRow($0) } }
            }
        }
    }

    @ViewBuilder
    private var pastSection: some View {
        if !past.isEmpty {
            VStack(alignment: .leading, spacing: 11) {
                SectionHeader("clock.arrow.circlepath", "Past")
                VStack(spacing: 9) { ForEach(past) { dateRow($0) } }
            }
        }
    }

    // MARK: - Rows

    private func liveRow(_ status: LocatorUserEventStatus) -> some View {
        NavigationLink(value: EventRoute(id: status.event.id, alias: status.bestIdentifier)) {
            ZStack(alignment: .leading) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(status.event.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white).lineLimit(2)
                        if let date = status.event.startDatetime {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
                        }
                    }
                    Spacer(minLength: 8)
                    LiveBadge(pulsing: true)
                }
                .padding(.vertical, 13).padding(.horizontal, 15)
                Rectangle().fill(EventsTheme.green).frame(width: 3)
            }
            .eventsCard(radius: 15)
        }
        .buttonStyle(.plain)
    }

    private func dateRow(_ status: LocatorUserEventStatus) -> some View {
        NavigationLink(value: EventRoute(id: status.event.id, alias: status.bestIdentifier)) {
            HStack(spacing: 13) {
                if let date = status.event.startDatetime {
                    VStack(spacing: 2) {
                        Text(date.formatted(.dateTime.day()))
                            .font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                        Text(date.formatted(.dateTime.month(.abbreviated)).uppercased())
                            .font(.system(size: 10)).foregroundStyle(EventsTheme.textSecondary)
                    }
                    .frame(width: 38)
                    Rectangle().fill(EventsTheme.hairline).frame(width: 1, height: 34)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(status.event.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white).lineLimit(2)
                    if let date = status.event.startDatetime {
                        Text(date.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(EventsTheme.textTertiary)
            }
            .padding(.vertical, 13).padding(.horizontal, 15)
            .eventsCard(radius: 15)
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
            .padding(.vertical, 14)
            .eventsCard(radius: 15)
        }
        .buttonStyle(.plain)
        .disabled(loadingMore)
    }

    // MARK: - Empty / failed

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "trophy").font(.system(size: 34)).foregroundStyle(EventsTheme.textTertiary)
            Text("No events yet").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
            Text("Events you register for on the Locator show up here.")
                .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    private func failed(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark").font(.system(size: 30)).foregroundStyle(EventsTheme.textSecondary)
            Text("Couldn't load events").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
            Text(message).font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary).multilineTextAlignment(.center)
            Button("Retry") { Task { await load() } }.tint(EventsTheme.green)
        }
        .frame(maxWidth: .infinity, minHeight: 400).padding(.horizontal, 24)
    }

    // MARK: - Grouping

    private func grouped(_ predicate: (LocatorUserEventStatus) -> Bool, sortDescending: Bool) -> [LocatorUserEventStatus] {
        items.filter(predicate).sorted {
            let a = $0.event.startDatetime ?? .distantPast
            let b = $1.event.startDatetime ?? .distantPast
            return sortDescending ? a > b : a < b
        }
    }

    private var upcoming: [LocatorUserEventStatus] {
        let now = Date()
        return items
            .filter { !$0.event.isLive && !$0.event.isFinished && ($0.event.startDatetime ?? .distantPast) >= now }
            .sorted { ($0.event.startDatetime ?? .distantFuture) < ($1.event.startDatetime ?? .distantFuture) }
    }

    private var past: [LocatorUserEventStatus] {
        let now = Date()
        return items
            .filter { status in
                if status.event.isActuallyLive { return false }
                if status.event.isFinished { return true }
                return (status.event.startDatetime ?? .distantFuture) < now
            }
            .sorted { ($0.event.startDatetime ?? .distantPast) > ($1.event.startDatetime ?? .distantPast) }
    }

    // MARK: - Load

    @MainActor
    private func load() async {
        guard let token = session.token else { status = .failed("Not signed in."); return }
        if items.isEmpty { status = .loading }
        do {
            let page = try await service.myEvents(token: token, page: 1)
            items = page.results.filter { !$0.isCanceledRegistration }
            nextPage = page.nextPageNumber
            status = .loaded
            lastLoaded = Date()
            await resolveHero()
        } catch {
            if session.signOutIfUnauthorized(error) { return }
            status = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    @MainActor
    private func loadMore() async {
        guard let token = session.token, let page = nextPage, !loadingMore else { return }
        loadingMore = true
        loadMoreFailed = false
        defer { loadingMore = false }
        if let next = try? await service.myEvents(token: token, page: page) {
            items += next.results.filter { !$0.isCanceledRegistration }
            nextPage = next.nextPageNumber
        } else {
            loadMoreFailed = true
        }
    }

    /// Best-effort: find the live event's current-round match for the hero card.
    @MainActor
    private func resolveHero() async {
        hero = nil
        guard let token = session.token,
              let live = items.first(where: { $0.event.isActuallyLive }),
              let event = try? await service.event(id: live.event.id),
              let round = event.currentRound,
              let match = try? await service.myMatch(roundID: round.id, token: token),
              let resolved = ResolvedMyMatch(match, myUserID: session.userID),
              !resolved.isComplete, !resolved.isBye
        else { return }
        hero = HeroMatch(eventID: event.id,
                         eventName: event.name,
                         alias: live.bestIdentifier,
                         match: resolved,
                         roundLabel: event.currentRoundLabel)
    }
}

/// Small pulsing green dot used in the hero header.
private struct PulsingDot: View {
    @State private var on = false
    var body: some View {
        Circle()
            .fill(EventsTheme.green)
            .frame(width: 7, height: 7)
            .opacity(on ? 0.3 : 1)
            .scaleEffect(on ? 0.7 : 1)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}
