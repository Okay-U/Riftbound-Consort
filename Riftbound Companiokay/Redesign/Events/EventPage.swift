//
//  EventPage.swift
//  Riftbound Companiokay
//
//  One event (Android `EventPage.kt`, classic `PlayRiftboundEventView`, mock's event page): store, name, when,
//  who; with rounds the five tabs Matches · Rounds · Standings · Roster · Info, before that the details.
//  Register, cancel and drop are confirmed first.
//

import SwiftUI

private enum EventTab: String, CaseIterable { case matches = "Matches", rounds = "Rounds", standings = "Standings", roster = "Roster", info = "Info" }

enum RegistrationAction: Identifiable {
    case register, deregister, drop
    var id: Self { self }

    var title: String {
        switch self {
        case .register: return "Register for this event?"
        case .deregister: return "Cancel registration?"
        case .drop: return "Drop from event?"
        }
    }

    var text: String {
        switch self {
        case .register: return "Registers you for this event with your Riot account."
        case .deregister: return "Removes your registration. You can register again while registration is open."
        case .drop: return "Drops you from the running event. This cannot be undone."
        }
    }

    var label: String {
        switch self {
        case .register: return "Register"
        case .deregister: return "Cancel registration"
        case .drop: return "Drop from event"
        }
    }

    var done: String {
        switch self {
        case .register: return "Registered with your Riot account"
        case .deregister: return "Registration cancelled"
        case .drop: return "You dropped from the event"
        }
    }

    var danger: Bool { self != .register }
}

struct EventPage: View {
    let entry: PlayerTournamentEntry
    let onStore: (CompeteOrganizer) -> Void
    let onSite: (URL?) -> Void
    let onToast: (String) -> Void
    @EnvironmentObject private var events: PlayRiftboundEventsStore
    @EnvironmentObject private var browser: PlayRiftboundBrowser
    @EnvironmentObject private var tournaments: RiftTournaments
    @EnvironmentObject private var riftMatch: PlayRiftboundMatchStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var error: String?
    @State private var generation = 0
    @State private var tab: EventTab = .matches
    @State private var tabKey = 0
    @State private var reporting: ReportTarget?
    @State private var action: RegistrationAction?
    @State private var busy = false
    @State private var actionError: String?
    @State private var drawing = false

    private var summary: CompeteTournamentSummary { entry.tournament }

    var body: some View {
        let t = tournaments.cached(summary.id)
        let me = t.flatMap { tournaments.playerID(in: $0) }
        let state = playerState(t, me)
        let isPast = events.past.contains { $0.tournament.id == summary.id }
        let isOver = isPast || t?.isFinished == true || summary.startsAt.map { $0.addingTimeInterval(12 * 3600) < Date() } == true
        VStack(alignment: .leading, spacing: 0) {
            Hero(entry: entry, tournament: t, state: state, live: RiftTournaments.isLive(entry) && !isOver) { entry.organizer.map(onStore) }
            if let t, t.hasRounds {
                Tabs(tab: tab) { pick in
                    guard pick != tab else { return }
                    tab = pick
                    tabKey += 1
                }
                Group {
                    switch tab {
                    case .matches: MatchesTab(tournament: t, playerID: me, isPast: isPast) { reporting = ReportTarget(tournamentID: summary.id, pairing: $0) }
                    case .rounds: RoundsTab(tournament: t, myTeamID: me.flatMap { t.teamID(playerID: $0) })
                    case .standings: StandingsTab(tournament: t, myTeamID: me.flatMap { t.teamID(playerID: $0) }, canDraw: state != .dropped) { drawing = true }
                    case .roster: RosterTab(tournament: t, myPlayerID: me)
                    case .info: info(t, me: me, state: state, isOver: isOver)
                    }
                }
                .modifier(TabSlide())
                .id(tabKey)
            } else if let t {
                info(t, me: me, state: state, isOver: isOver)
            } else if let error {
                EvMessage(text: error).padding(.top, 20)
            } else {
                EvLoading(text: "Loading the event")
            }
        }
        .task(id: summary.id) { await load() }
        // Back from the lock screen between rounds: the new pairing, not the old one.
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await load() } } }
        .sheet(item: $reporting) { target in
            RiftReportSheet(target: target, onToast: onToast) {
                Task {
                    await load()
                    await riftMatch.refresh(browser: browser, force: true)
                }
            }
        }
        .sheet(isPresented: $drawing) {
            if let t, let team = me.flatMap({ t.teamID(playerID: $0) }) { DrawSheet(tournament: t, myTeamID: team) }
        }
        .sheet(item: $action) { action in
            ConfirmSheet(title: action.title, text: action.text, label: action.label, danger: action.danger) { perform(action) }
        }
    }

    private func playerState(_ t: CompeteTournament?, _ me: String?) -> CompeteTournament.PlayerState {
        if let t, let me { return t.state(of: me) }
        if t == nil, events.upcoming.contains(where: { $0.tournament.id == summary.id }) { return .registered }
        return .none
    }

    // MARK: - Info

    @ViewBuilder
    private func info(_ t: CompeteTournament, me: String?, state: CompeteTournament.PlayerState, isOver: Bool) -> some View {
        let started = t.hasStarted || t.hasRounds
        let closed = t.registrationEndAt.map { $0 < Date() } == true
            || summary.config?.participantCapacity.map { $0 > 0 && summary.registeredCount >= $0 } == true
        let available: RegistrationAction? = {
            guard tournaments.me != nil, !isOver else { return nil }
            switch state {
            case .registered, .active, .waitlisted: return started ? .drop : .deregister
            case .none: return started || closed ? nil : .register
            case .dropped, .eliminated: return nil
            }
        }()
        if let available {
            EvButton(text: busy ? "Working…" : available.label, kind: available.danger ? .dangerSoft : .green, enabled: !busy) { action = available }
                .padding(.top, 12)
        }
        if events.state == .signedOut { EvMessage(text: "Sign in on PlayRiftbound first.").padding(.vertical, 14) }
        if let actionError {
            Text(actionError).font(RiftFont.text(12.5)).foregroundStyle(RiftColor.danger).padding(.top, 8)
        }
        EvButton(text: "Open on PlayRiftbound", kind: .ghost) { onSite(summary.webURL) }.padding(.top, 8)
        EvCaption(left: "Details")
        EvCard {
            if let program = t.tournamentProgram?.programName { EvPill(text: program, height: 24) }
            VStack(alignment: .leading, spacing: 6) {
                if let line = EvFmt.formatLine(t.config?.format, t.config?.playerFormat, t.config?.structure ?? t.config?.tournamentType) {
                    DetailText(text: line)
                }
                let facts = [t.config?.roundCount.flatMap { $0 > 0 ? "\($0) rounds" : nil }, t.config?.matchFormat.map { EvFmt.humanize($0) },
                             EvFmt.price(fee: t.entryFee, pricing: t.pricing)].compactMap { $0 }
                if !facts.isEmpty { DetailText(text: facts.joined(separator: " • ")) }
                if let description = t.description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    DetailText(text: description, opacity: 0.66)
                }
                if let end = t.registrationEndAt {
                    DetailText(text: end > Date() ? "Registration closes \(EvFmt.whenLine(end))" : "Registration closed", opacity: 0.5)
                }
            }
            .padding(.top, 8)
        }
        let registrants = (t.tournamentRegistrants ?? []).filter { ($0.status ?? "REGISTERED") == "REGISTERED" }
        EvCaption(left: "Players · \(registrants.count)")
        if registrants.isEmpty {
            Text("No one registered yet.").font(RiftFont.text(12.5)).foregroundStyle(.white.opacity(0.6))
        } else {
            EvCard {
                ForEach(Array(registrants.enumerated()), id: \.element.id) { i, registrant in
                    PersonRow(name: registrant.player?.displayName ?? "Player", you: me != nil && registrant.player?.id == me, divider: i < registrants.count - 1) {
                        if registrant.checkedIn == true {
                            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(RiftColor.you).accessibilityLabel("Checked in")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Loading and actions

    private func load() async {
        generation += 1
        let request = generation
        do {
            let fresh = try await tournaments.tournament(summary.id, browser: browser, force: true)
            guard request == generation else { return }
            error = fresh == nil ? "Event not found." : nil
        } catch {
            guard request == generation, tournaments.cached(summary.id) == nil else { return }
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Once sent, Riot has the change: the call and the lists catching up finish also when the page closes.
    private func perform(_ action: RegistrationAction) {
        busy = true
        actionError = nil
        let id = summary.id
        Task {
            defer { busy = false }
            do {
                guard let credentials = try await PlayRiftboundSession.validCredentials(refreshingVia: browser) else {
                    throw PlayRiftboundError.notSignedIn
                }
                let api = PlayRiftboundAPI()
                switch action {
                case .register: try await api.register(tournamentID: id, credentials: credentials)
                case .deregister: try await api.deregister(tournamentID: id, credentials: credentials)
                case .drop: try await api.drop(tournamentID: id, credentials: credentials)
                }
                Haptics.success()
                onToast(action.done)
                await load()
                await events.refresh(browser: browser, force: true)
                await riftMatch.refresh(browser: browser, force: true)
            } catch {
                actionError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

private struct DetailText: View {
    let text: String
    var opacity = 0.82

    var body: some View {
        Text(text).font(RiftFont.text(14, .regular)).lineSpacing(5).foregroundStyle(.white.opacity(opacity))
    }
}

/// `.ehero`: the store link, name, date and the player count with the player's status.
private struct Hero: View {
    let entry: PlayerTournamentEntry
    let tournament: CompeteTournament?
    let state: CompeteTournament.PlayerState
    let live: Bool
    let onStore: () -> Void

    var body: some View {
        let s = entry.tournament
        let registered = (tournament?.tournamentRegistrants ?? []).filter { ($0.status ?? "REGISTERED") == "REGISTERED" }.count
        let count = registered > 0 ? registered : s.registeredCount
        let shape = RoundedRectangle(cornerRadius: 24)
        VStack(alignment: .leading, spacing: 0) {
            if let organizer = entry.organizer {
                Button(action: onStore) {
                    Text("\(organizer.name.uppercased()) ›").caps(11, tracking: 0.16, weight: .bold).foregroundStyle(RiftColor.you)
                }
                .buttonStyle(PressScale(scale: 0.97))
                .accessibilityLabel("Open \(organizer.name)")
            }
            Text(s.name).font(RiftFont.display(28)).foregroundStyle(.white).padding(.top, 6)
            if let date = s.startsAt {
                Text(EvFmt.whenLine(date)).font(RiftFont.text(13)).foregroundStyle(.white.opacity(0.66)).padding(.top, 6)
            }
            HStack(spacing: 8) {
                EvPill(text: "\(EvFmt.players(count, cap: s.config?.participantCapacity)) players")
                StatusPill(state: state, live: live)
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ev.card, in: shape)
        .overlay(shape.stroke(Ev.ring, lineWidth: 1))
    }
}

/// `.tabs`: text tabs whose glowing underline grows under the chosen one.
private struct Tabs: View {
    let tab: EventTab
    let onPick: (EventTab) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(EventTab.allCases, id: \.self) { t in
                    let on = t == tab
                    Button { onPick(t) } label: {
                        Text(t.rawValue)
                            .font(RiftFont.text(14, .semibold))
                            .foregroundStyle(.white.opacity(on ? 1 : 0.55))
                            .padding(.horizontal, 12)
                            .frame(height: 42)
                            .overlay(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(RiftColor.you)
                                    .frame(height: 3)
                                    .shadow(color: RiftColor.you.opacity(0.8), radius: 5)
                                    .padding(.horizontal, 10)
                                    .scaleEffect(x: on ? 1 : 0, y: 1)
                                    .opacity(on ? 1 : 0)
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressScale(scale: 0.97))
                    .animation(.rift(0.42), value: on)
                    .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
                }
            }
            .padding(.horizontal, 16)
        }
        .overlay(alignment: .bottom) { Hairline(opacity: 0.08) }
        .padding(.horizontal, -16)
        .padding(.top, 14)
    }
}

/// A tab's content slides in from the right out of a blur when the tab changes (mock's `tabA`).
private struct TabSlide: ViewModifier {
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(x: shown ? 0 : 24)
            .blur(radius: shown ? 0 : 6)
            .onAppear { withAnimation(.rift(0.52)) { shown = true } }
    }
}

/// Players with their seeds, dropped ones apart (classic `PlayRiftboundRosterTab`).
private struct RosterTab: View {
    let tournament: CompeteTournament
    let myPlayerID: String?

    var body: some View {
        let myTeam = myPlayerID.flatMap { tournament.teamID(playerID: $0) }
        let all = (tournament.tournamentParticipants ?? []).sorted {
            ($0.player?.displayName ?? "").localizedCaseInsensitiveCompare($1.player?.displayName ?? "") == .orderedAscending
        }
        let dropped = all.filter { $0.status?.uppercased().contains("DROP") == true }
        let active = all.filter { $0.status?.uppercased().contains("DROP") != true }
        VStack(alignment: .leading, spacing: 0) {
            EvCaption(left: "Players · \(active.count) active")
            EvCard {
                ForEach(Array(active.enumerated()), id: \.element.id) { i, p in
                    let mine = myPlayerID != nil && p.player?.id == myPlayerID
                    let mate = !mine && myTeam != nil && p.esportsTeamId == myTeam
                    PersonRow(name: p.player?.displayName ?? "Player", you: mine || mate, divider: i < active.count - 1, tag: mine ? "YOU" : "TEAM") {
                        Seed(position: p.position)
                    }
                }
            }
            if !dropped.isEmpty {
                EvCaption(left: "Dropped")
                EvCard {
                    ForEach(Array(dropped.enumerated()), id: \.element.id) { i, p in
                        PersonRow(name: p.player?.displayName ?? "Player", you: false, divider: i < dropped.count - 1, faded: true) { Seed(position: p.position) }
                    }
                }
            }
        }
    }
}

private struct Seed: View {
    let position: Int?

    var body: some View {
        if let position { Text("#\(position)").font(RiftFont.display(13, weight: 800)).foregroundStyle(.white.opacity(0.45)) }
    }
}

/// Register / cancel / drop, confirmed first (mock's `.dlg`).
struct ConfirmSheet: View {
    let title: String
    let text: String
    let label: String
    let danger: Bool
    let onDo: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(RiftFont.text(17, .bold)).foregroundStyle(.white)
            Text(text).font(RiftFont.text(13, .regular)).lineSpacing(4).foregroundStyle(.white.opacity(0.72)).padding(.top, 6).padding(.bottom, 14)
            HStack(spacing: 8) {
                EvButton(text: "Keep", kind: .ghost) { dismiss() }
                EvButton(text: label, kind: danger ? .danger : .green) {
                    dismiss()
                    onDo()
                }
            }
        }
        .padding(20)
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
    }
}
