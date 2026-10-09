//
//  PlayRiftboundEventView.swift
//  Riftbound Companiokay
//
//  Native event screen on PlayRiftbound data: header (store, name, when, who),
//  details, registered players. Registering, dropping and the store's contact
//  card are not approved for the session client, so those open the event page
//  in the PlayRiftbound segment.
//

import SwiftUI

struct PlayRiftboundEventView: View {
    let entry: PlayerTournamentEntry

    @EnvironmentObject private var browser: PlayRiftboundBrowser
    @EnvironmentObject private var events: PlayRiftboundEventsStore
    @EnvironmentObject private var riftMatch: PlayRiftboundMatchStore
    @Environment(\.dismiss) private var dismiss
    @State private var tournament: CompeteTournament?
    @State private var me: (name: String, tag: String?)?
    @State private var error: String?
    @State private var tab: Tab = .matches
    @State private var reporting: PlayRiftboundStrip?
    @State private var pendingAction: RegistrationAction?
    @State private var busy = false
    @State private var actionError: String?

    enum RegistrationAction: Identifiable {
        case register, deregister, drop
        var id: Self { self }
        var title: String {
            switch self { case .register: "Register"; case .deregister: "Cancel registration"; case .drop: "Drop from event" }
        }
        var message: String {
            switch self {
            case .register:   "Registers you for this event with your Riot account."
            case .deregister: "Removes your registration. You can register again while registration is open."
            case .drop:       "Drops you from the running event. This cannot be undone."
            }
        }
    }

    enum Tab: String, CaseIterable { case matches = "Matches", rounds = "Rounds", standings = "Standings", roster = "Roster", info = "Info" }

    private let api = PlayRiftboundAPI()
    private var summary: CompeteTournamentSummary { entry.tournament }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if let tournament, tournament.hasRounds {
                    tabStrip
                    switch tab {
                    case .matches:
                        PlayRiftboundMatchesTab(tournament: tournament, playerID: playerID(in: tournament),
                                                isPast: isPast) { pairing in reporting = strip(for: pairing) }
                    case .rounds:
                        PlayRiftboundRoundsTab(tournament: tournament, myTeamID: myTeamID(in: tournament))
                    case .standings:
                        PlayRiftboundStandingsTab(tournament: tournament, myTeamID: myTeamID(in: tournament))
                    case .roster:
                        PlayRiftboundRosterTab(tournament: tournament, myTeamID: myTeamID(in: tournament))
                    case .info:
                        actions
                        details(tournament)
                        players(tournament)
                    }
                } else if let tournament {
                    actions
                    details(tournament)
                    players(tournament)
                } else if let error {
                    Text(error).font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
                        .frame(maxWidth: .infinity).padding(.top, 20)
                } else {
                    ProgressView().tint(EventsTheme.green).frame(maxWidth: .infinity).padding(.top, 30)
                }
            }
            .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 24)
        }
        .background(EventsTheme.bg.ignoresSafeArea())
        .navigationTitle(summary.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(EventsTheme.bg, for: .navigationBar)
        .refreshable { await load() }
        .task { await load() }
        .sheet(item: $reporting) { strip in
            if let pairing = strip.pairing {
                PlayRiftboundReportSheet(strip: strip, pairing: pairing) {
                    Task {
                        await load()
                        await riftMatch.refresh(browser: browser, force: true)
                    }
                }
            }
        }
    }

    private var isPast: Bool { events.past.contains { $0.tournament.id == summary.id } }

    private func playerID(in tournament: CompeteTournament) -> String? {
        guard let me else { return nil }
        return tournament.playerID(gameName: me.name, tagLine: me.tag)
    }

    private func myTeamID(in tournament: CompeteTournament) -> String? {
        playerID(in: tournament).flatMap(tournament.teamID(playerID:))
    }

    private func strip(for pairing: CompetePairing) -> PlayRiftboundStrip {
        PlayRiftboundStrip(tournamentID: summary.id, eventName: summary.name, organizerName: entry.organizer?.name,
                           startsAt: summary.startsAt, webURL: summary.webURL, pairing: pairing)
    }

    private var tabStrip: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { t in
                let on = tab == t
                Button { withAnimation(.easeInOut(duration: 0.15)) { tab = t } } label: {
                    Text(t.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.75)
                        .foregroundStyle(on ? EventsTheme.matchFillBottom : EventsTheme.textSecondary)
                        .frame(maxWidth: .infinity).frame(height: 32)
                        .background(on ? EventsTheme.green : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(EventsTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(EventsTheme.hairline, lineWidth: 1))
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let organizer = entry.organizer {
                NavigationLink(value: organizer) {
                    HStack(spacing: 4) {
                        Text(organizer.name.uppercased())
                        if PlayRiftboundFeatures.unapproved { Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)) }
                    }
                    .font(.system(size: 11, weight: .bold)).tracking(0.5)
                    .foregroundStyle(EventsTheme.green)
                }
                .buttonStyle(.plain)
                .disabled(!PlayRiftboundFeatures.unapproved)
            }
            Text(summary.name)
                .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
            if let date = summary.startsAt {
                Label(date.formatted(date: .complete, time: .shortened), systemImage: "calendar")
                    .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
            }
            HStack(spacing: 8) {
                Label(playersText, systemImage: "person.2")
                if isRegistered { pill("Registered", tint: EventsTheme.green) }
            }
            .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .eventsCard()
    }

    private var actions: some View {
        VStack(spacing: 8) {
            if PlayRiftboundFeatures.unapproved, let action = availableAction {
                Button { pendingAction = action } label: {
                    Group {
                        if busy { ProgressView().tint(action == .register ? EventsTheme.matchFillBottom : .white) }
                        else { Label(action.title, systemImage: action == .register ? "person.badge.plus" : "person.badge.minus") }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(action == .register ? EventsTheme.matchFillBottom : Color.red)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(action == .register ? EventsTheme.green : Color.red.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(busy)
                .confirmationDialog(action.title, isPresented: Binding(get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } }),
                                    titleVisibility: .visible) {
                    Button(action.title, role: action == .register ? nil : .destructive) { Task { await perform(action) } }
                    Button("Cancel", role: .cancel) {}
                } message: { Text(action.message) }
            }
            if let actionError {
                Text(actionError).font(.system(size: 12)).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
            }
            webButton("Open on PlayRiftbound", symbol: "safari", url: summary.webURL)
        }
    }

    private var isRegistered: Bool {
        if events.upcoming.contains(where: { $0.tournament.id == summary.id }) { return true }
        guard let tournament, me != nil else { return false }
        return (tournament.tournamentRegistrants ?? []).contains { ($0.status ?? "REGISTERED") == "REGISTERED" && isMe($0.player) }
    }

    private var isOver: Bool { isPast || summary.startsAt.map { $0.addingTimeInterval(12 * 3600) < Date() } == true }

    private var availableAction: RegistrationAction? {
        guard me != nil, !isOver else { return nil }
        let started = tournament?.hasRounds == true
        if isRegistered { return started ? .drop : .deregister }
        return started ? nil : .register
    }

    private func perform(_ action: RegistrationAction) async {
        busy = true; actionError = nil
        defer { busy = false }
        do {
            guard let credentials = try await PlayRiftboundSession.validCredentials(refreshingVia: browser) else {
                actionError = PlayRiftboundError.notSignedIn.errorDescription; return
            }
            switch action {
            case .register:   try await api.register(tournamentID: summary.id, credentials: credentials)
            case .deregister: try await api.deregister(tournamentID: summary.id, credentials: credentials)
            case .drop:       try await api.drop(tournamentID: summary.id, credentials: credentials)
            }
            await load()
            await events.refresh(browser: browser, force: true)
            await riftMatch.refresh(browser: browser, force: true)
        } catch {
            actionError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func details(_ t: CompeteTournament) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("info.circle", "Details")
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    if let program = t.tournamentProgram?.programName { pill(program, tint: EventsTheme.textSecondary) }
                    if let line = formatLine(t.config) {
                        Text(line).font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
                    }
                }
                if let structure = structureLine(t) {
                    Text(structure).font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
                }
                if let description = t.description, !description.isEmpty {
                    Text(description).font(.system(size: 14)).foregroundStyle(.white)
                }
                if let end = t.registrationEndAt {
                    Text("Registration closes \(end.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 12)).foregroundStyle(EventsTheme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .eventsCard(radius: 15)
        }
    }

    private func players(_ t: CompeteTournament) -> some View {
        let registrants = (t.tournamentRegistrants ?? []).filter { ($0.status ?? "REGISTERED") == "REGISTERED" }
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader("person.3", "Players") {
                Text("\(registrants.count)").foregroundStyle(EventsTheme.textTertiary)
            }
            if registrants.isEmpty {
                Text("No one registered yet.").font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(registrants.enumerated()), id: \.element.id) { index, registrant in
                        HStack {
                            Text(registrant.player?.displayName ?? "Player")
                                .font(.system(size: 14, weight: isMe(registrant.player) ? .semibold : .regular))
                                .foregroundStyle(.white)
                            if isMe(registrant.player) { pill("You", tint: EventsTheme.green) }
                            Spacer()
                            if registrant.checkedIn == true {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 13)).foregroundStyle(EventsTheme.green)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        if index < registrants.count - 1 { Divider().overlay(EventsTheme.hairline) }
                    }
                }
                .eventsCard(radius: 15)
            }
        }
    }

    // MARK: - Pieces

    private func webButton(_ title: String, symbol: String, url: URL?) -> some View {
        Button {
            guard let url else { return }
            dismiss()
            browser.open(url)
        } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 40)
                .eventsCard(radius: 12)
        }
        .buttonStyle(.plain)
        .disabled(url == nil)
    }

    private func pill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold)).foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(tint.opacity(0.14), in: Capsule())
    }

    private var playersText: String {
        let count = tournament.map { ($0.tournamentRegistrants ?? []).filter { ($0.status ?? "REGISTERED") == "REGISTERED" }.count }
            ?? summary.registeredCount
        if let cap = summary.config?.participantCapacity, cap > 0 { return "\(count)/\(cap) players" }
        return "\(count) players"
    }

    private func formatLine(_ config: CompeteTournament.Config?) -> String? {
        guard let config else { return nil }
        let parts = [config.format, config.playerFormat, config.structure ?? config.tournamentType]
            .compactMap { $0 }.map(PlayRiftboundFormat.humanize)
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func structureLine(_ t: CompeteTournament) -> String? {
        var parts: [String] = []
        if let rounds = t.config?.roundCount, rounds > 0 { parts.append("\(rounds) rounds") }
        if let match = t.config?.matchFormat { parts.append(PlayRiftboundFormat.humanize(match)) }
        if let fee = t.entryFee, fee.minorUnits > 0 {
            parts.append((Decimal(fee.minorUnits) / 100).formatted(.currency(code: fee.currency).precision(.fractionLength(0...2))))
        } else if let pricing = t.pricing {
            parts.append(PlayRiftboundFormat.humanize(pricing))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func isMe(_ player: CompeteTournament.RegistrantPlayer?) -> Bool {
        guard let player, let me else { return false }
        guard player.displayName.caseInsensitiveCompare(me.name) == .orderedSame else { return false }
        if let tag = me.tag, let theirs = player.tagLine { return theirs.caseInsensitiveCompare(tag) == .orderedSame }
        return true
    }

    // MARK: - Loading

    private func load() async {
        do {
            guard let credentials = try await PlayRiftboundSession.validCredentials(refreshingVia: browser) else {
                error = PlayRiftboundError.notSignedIn.errorDescription
                return
            }
            if let name = credentials.gameName { me = (name, credentials.tagLine) }
            tournament = try await api.tournament(id: summary.id, credentials: credentials)
            error = tournament == nil ? "Event not found." : nil
        } catch {
            if tournament == nil { self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
        }
    }
}

/// Display strings for PlayRiftbound's config enums.
nonisolated enum PlayRiftboundFormat {
    /// `ONE_V_ONE` → "1v1", `BEST_OF_THREE` → "Best of three", `SWISS` → "Swiss".
    static func humanize(_ raw: String) -> String {
        switch raw.uppercased() {
        case "ONE_V_ONE", "1V1": return "1v1"
        case "TWO_V_TWO", "2V2": return "2v2"
        default: return raw.replacingOccurrences(of: "_", with: " ").lowercased().capitalized
        }
    }
}
