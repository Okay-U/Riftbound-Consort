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
    @Environment(\.dismiss) private var dismiss
    @State private var tournament: CompeteTournament?
    @State private var me: (name: String, tag: String?)?
    @State private var error: String?

    private let api = PlayRiftboundAPI()
    private var summary: CompeteTournamentSummary { entry.tournament }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                actions
                if let tournament {
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
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let organizer = entry.organizer?.name {
                Text(organizer.uppercased())
                    .font(.system(size: 11, weight: .bold)).tracking(0.5)
                    .foregroundStyle(EventsTheme.green)
            }
            Text(summary.name)
                .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
            if let date = summary.startsAt {
                Label(date.formatted(date: .complete, time: .shortened), systemImage: "calendar")
                    .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
            }
            HStack(spacing: 8) {
                Label(playersText, systemImage: "person.2")
                pill("Registered", tint: EventsTheme.green)
            }
            .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .eventsCard()
    }

    /// Register / drop / store contact live on the site (not approved for the session client).
    private var actions: some View {
        webButton("Manage on PlayRiftbound", symbol: "safari", url: summary.webURL)
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
enum PlayRiftboundFormat {
    /// `ONE_V_ONE` → "1v1", `BEST_OF_THREE` → "Best of three", `SWISS` → "Swiss".
    static func humanize(_ raw: String) -> String {
        switch raw.uppercased() {
        case "ONE_V_ONE", "1V1": return "1v1"
        case "TWO_V_TWO", "2V2": return "2v2"
        default: return raw.replacingOccurrences(of: "_", with: " ").lowercased().capitalized
        }
    }
}
