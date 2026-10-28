//
//  MyEventsPane.swift
//  Riftbound Companiokay
//
//  The Events section (Android `MyEventsPane.kt`, classic `PlayRiftboundEventsView`, mock's feed): the finder
//  pill, the event running now with its round clock, table and Report, then upcoming cards with the player's
//  status and past cards with where they finished.
//

import SwiftUI

/// A pairing to report from a list or the event page.
struct ReportTarget: Identifiable {
    let tournamentID: String
    let pairing: CompetePairing
    var id: String { tournamentID + pairing.roundID }
}

struct MyEventsPane: View {
    let active: Bool
    let onOpen: (EventsRoute) -> Void
    let onSite: (URL?) -> Void
    let onToast: (String) -> Void
    @EnvironmentObject private var events: PlayRiftboundEventsStore
    @EnvironmentObject private var browser: PlayRiftboundBrowser
    @EnvironmentObject private var favorites: PlayRiftboundFavorites
    @EnvironmentObject private var tournaments: RiftTournaments
    @EnvironmentObject private var riftMatch: PlayRiftboundMatchStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var reporting: ReportTarget?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 30)
                .readableWidth()
        }
        .refreshable { await reload(force: true) }
        // Each time the section shows and on every return: signing in on the PlayRiftbound section counts at once.
        .task(id: active) { if active { await reload(force: events.state == .signedOut) } }
        .onChange(of: scenePhase) { _, phase in if phase == .active, active { Task { await reload(force: false) } } }
        .onChange(of: events.lastLoaded) { Task { await prefetch() } }
        .sheet(item: $reporting) { target in
            RiftReportSheet(target: target, onToast: onToast) {
                Task { await riftMatch.refresh(browser: browser, force: true) }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch events.state {
        case .idle, .loading:
            EvLoading(text: "Picking up your PlayRiftbound session")
        case .signedOut:
            // Says where the session stays and how it goes (a privacy question from a tester, 2026-10-28).
            EmptyState(
                title: "Sign in on PlayRiftbound",
                text: "Your registered events show up here once you are signed in. Your Riot sign-in then stays in the app's browser on this phone until you sign out of Riot in the PlayRiftbound menu.",
                button: "Open PlayRiftbound"
            ) {
                onSite(PlayRiftboundPolicy.home)
            }
        case .failed(let message):
            EmptyState(title: "Couldn't load events", text: message, button: "Retry") { Task { await reload(force: true) } }
        case .loaded:
            FindPill { onOpen(.search) }
            if events.hasEvents { lists } else {
                EmptyState(title: "No events yet", text: "Events you register for on PlayRiftbound show up here.", button: "Find an event") { onOpen(.search) }
            }
        }
    }

    @ViewBuilder
    private var lists: some View {
        let live = events.upcoming.first { RiftTournaments.isLive($0) }
        if let live, tournaments.state(of: live) != .dropped {
            LiveCard(entry: live, onReport: { reporting = ReportTarget(tournamentID: live.tournament.id, pairing: $0) },
                     onReported: { onToast("Already reported on PlayRiftbound") }) { onOpen(.event(live)) }
        }
        EvCaption(left: "Upcoming", right: "\(events.upcoming.count)")
        ForEach(Array(events.upcoming.filter { $0 != live }.enumerated()), id: \.element.tournament.id) { i, entry in
            UpcomingCard(entry: entry) { onOpen(.event(entry)) }
                .padding(.bottom, 10)
                .softIn(delay: Double(min(i, 8)) * 0.05, duration: 0.7)
        }
        if !events.past.isEmpty {
            EvCaption(left: "Past", right: "\(events.past.count)")
            ForEach(Array(events.past.enumerated()), id: \.element.tournament.id) { i, entry in
                PastCard(entry: entry) { onOpen(.event(entry)) }
                    .padding(.bottom, 10)
                    .softIn(delay: Double(min(i, 8)) * 0.05, duration: 0.7)
            }
        }
    }

    private func reload(force: Bool) async {
        await events.refresh(browser: browser, force: force)
        if favorites.signedIn == nil { await favorites.load(browser: browser) }
        await prefetch()
    }

    /// The cards' status and placement need each event's details: the live ones first.
    private func prefetch() async {
        let live = events.upcoming.filter { RiftTournaments.isLive($0) }
        var seen = Set<String>()
        let ids = (live + events.upcoming + events.past.prefix(12)).map(\.tournament.id).filter { seen.insert($0).inserted }
        await tournaments.prefetch(ids, browser: browser)
    }
}

/// `.live`: the event running now, its round clock and the player's table, with Report.
private struct LiveCard: View {
    let entry: PlayerTournamentEntry
    let onReport: (CompetePairing) -> Void
    let onReported: () -> Void
    let onOpen: () -> Void
    @EnvironmentObject private var tournaments: RiftTournaments

    var body: some View {
        let t = tournaments.cached(entry.tournament.id)
        let me = t.flatMap { tournaments.playerID(in: $0) }
        let round = t?.rounds.last
        let pairing = t.flatMap { tt in me.flatMap { CompetePairing.resolve(in: tt, playerID: $0) } }
        let running = round?.startedAt != nil && round?.matches.contains { !$0.isComplete } == true
        let shape = RoundedRectangle(cornerRadius: 26)
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Circle().fill(RiftColor.you).frame(width: 8, height: 8).shadow(color: RiftColor.you, radius: 5)
                    Text("LIVE NOW").caps(11, tracking: 0.16, weight: .bold).foregroundStyle(RiftColor.you)
                }
                Text(entry.tournament.name).font(RiftFont.display(26)).foregroundStyle(.white).multilineTextAlignment(.leading).padding(.top, 8)
                Text([entry.organizer?.name, entry.tournament.startsAt.map(EvFmt.time)].compactMap { $0 }.joined(separator: " • "))
                    .font(RiftFont.text(13)).foregroundStyle(.white.opacity(0.66)).padding(.top, 4)
                if running, let round { LiveClock(round: round) }
                HStack(alignment: .firstTextBaseline) {
                    Text(pairingLine(pairing)).font(RiftFont.text(15, .semibold)).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
                    if let pairing {
                        Text((pairing.roundTitle + (pairing.tableNumber.map { " · Table \($0)" } ?? "")).uppercased())
                            .caps(11, tracking: 0.12).foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.top, 14)
                HStack(spacing: 8) {
                    if let pairing, pairing.isReportable {
                        EvButton(text: "Report", kind: .green) { onReport(pairing) }
                    } else if let pairing, pairing.isComplete, !pairing.isBye {
                        EvButton(text: "Reported", kind: .green, action: onReported)
                    }
                    EvButton(text: "Open event", kind: .ghost, action: onOpen)
                }
                .padding(.top, 14)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "0B0B0B"), in: shape)
            .background(RadialGradient(colors: [RiftColor.you.opacity(0.16), .clear], center: .topLeading, startRadius: 0, endRadius: 300).clipShape(shape))
            .overlay(shape.stroke(RiftColor.you.opacity(0.5), lineWidth: 1))
            .shadow(color: RiftColor.you.opacity(0.12), radius: 15)
            .contentShape(shape)
        }
        .buttonStyle(PressScale(scale: 0.98))
        .padding(.top, 14)
        .softIn(duration: 0.7)
        .accessibilityHint("Opens the live event")
    }

    private func pairingLine(_ pairing: CompetePairing?) -> String {
        guard let pairing else { return "Your pairing shows here once round 1 is up" }
        if pairing.isBye { return "Bye this round" }
        if pairing.isComplete { return "Reported · \(pairing.mySide) \(pairing.scoreText ?? "")".trimmingCharacters(in: .whitespaces) }
        return "\(pairing.mySide) vs \(pairing.opponentName ?? "?")"
    }
}

/// The live card's clock; ticks in its own view so the card around it does not redraw every second.
private struct LiveClock: View {
    let round: CompeteTournament.Round

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let clock = RoundClock(round, now: context.date) {
                let ink = clock.over ? RiftColor.danger : .white
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .lastTextBaseline, spacing: 10) {
                        Text(clock.text).font(RiftFont.display(52)).foregroundStyle(ink)
                        Text(clock.over ? "TIME OVER" : "LEFT · ENDS \(EvFmt.time(clock.endsAt))")
                            .caps(12, tracking: 0.12).foregroundStyle(.white.opacity(0.66))
                    }
                    ClockRail(fraction: clock.fraction, color: ink)
                }
                .padding(.top, 14)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(clock.over ? "Round time over by \(clock.text)" : "\(clock.text) left in the round")
            }
        }
    }
}

private struct UpcomingCard: View {
    let entry: PlayerTournamentEntry
    let action: () -> Void
    @EnvironmentObject private var tournaments: RiftTournaments
    @EnvironmentObject private var favorites: PlayRiftboundFavorites

    var body: some View {
        let s = entry.tournament
        let favorite = entry.organizer.map { o in favorites.signedIn == true ? favorites.contains(o.id) : o.isFavorited == true } ?? false
        EvRowCard(label: "Open \(s.name)", action: action) {
            DateBadge(date: s.startsAt)
            EventInfo(name: s.name, format: EvFmt.summaryLine(s), storeLine: EvFmt.storeLine(entry.organizer), favoriteStore: favorite) {
                EvPill(text: EvFmt.price(fee: s.entryFee, pricing: s.pricing))
                EvPill(text: EvFmt.players(s.registeredCount, cap: s.config?.participantCapacity))
                StatusPill(state: tournaments.state(of: entry), live: RiftTournaments.isLive(entry))
            }
        }
    }
}

/// A past event: where the player finished, their Swiss record, the store.
private struct PastCard: View {
    let entry: PlayerTournamentEntry
    let action: () -> Void
    @EnvironmentObject private var tournaments: RiftTournaments

    var body: some View {
        let s = entry.tournament
        let t = tournaments.cached(s.id)
        let team = t.flatMap { tt in tournaments.playerID(in: tt).flatMap { tt.teamID(playerID: $0) } }
        let placement = team.flatMap { t?.placement(teamID: $0) }
        let standing = team.flatMap { t?.finalSwissStanding(teamID: $0) }
        let (place, crown): (String, Bool) = switch placement {
        case .rank(let n)?: (EvFmt.ordinal(n), n == 1)
        case .top(let n)?: ("Top \(n)", false)
        case nil: ("—", false)
        }
        let ink: Color = crown ? .black : .white
        EvRowCard(label: "Open \(s.name)", action: action) {
            VStack(spacing: 2) {
                Text(place).font(RiftFont.display(place.count > 4 ? 17 : 24)).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.7)
                if let date = s.startsAt {
                    Text("\(EvFmt.month(date)) \(EvFmt.day(date))").caps(9.5, tracking: 0.12, weight: .bold).foregroundStyle(ink)
                }
            }
            .frame(width: 60)
            .padding(.vertical, 10)
            .background(crown ? RiftColor.gold : placement != nil ? .white.opacity(0.1) : .white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
            EventInfo(name: s.name,
                      format: standing.map { "\($0.record) · \($0.matchPoints ?? 0) pts" } ?? EvFmt.formatLine(s.config?.format, s.config?.playerFormat),
                      storeLine: EvFmt.storeLine(entry.organizer), favoriteStore: false) { EmptyView() }
        }
    }
}
