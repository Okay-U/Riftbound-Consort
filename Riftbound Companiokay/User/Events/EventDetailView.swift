//
//  EventDetailView.swift
//  Riftbound Companiokay
//
//  Live event screen: overview, your current-round match (table + opponent),
//  pairings, and standings. Public TV data + authed my-match.
//

import SwiftUI

struct EventDetailView: View {
    let eventID: Int
    var myAlias: String? = nil          // per-event display name, fallback when no live match
    var service: any LocatorService = RiftboundLocatorService()

    @EnvironmentObject private var session: AuthSession
    @State private var state: LoadState = .idle
    @State private var reporting: ResolvedMyMatch?

    enum LoadState {
        case idle
        case loading
        case loaded(Loaded)
        case failed(String)
    }

    struct Loaded {
        let event: LocatorEvent
        let matches: [LocatorMatch]
        let standings: [LocatorStanding]
        let myMatch: ResolvedMyMatch?
        let myName: String?
    }

    var body: some View {
        Group {
            switch state {
            case .idle, .loading:
                ProgressView("Loading event…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't load event", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry") { Task { await load() } }
                }
            case .loaded(let data):
                content(data)
            }
        }
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
        .task { if case .idle = state { await load() } }
    }

    // MARK: - Loading

    @MainActor
    private func load() async {
        state = .loading
        do {
            async let event = service.event(id: eventID)
            async let pairings = service.pairings(eventID: eventID)
            async let standings = service.standings(eventID: eventID)
            let (e, m, s) = try await (event, pairings, standings)

            var resolved: ResolvedMyMatch?
            if let round = e.currentRound, let token = session.token,
               let match = try? await service.myMatch(roundID: round.id, token: token) {
                resolved = ResolvedMyMatch(match, myUserID: session.userID)
            }

            let sortedMatches = m.sorted { ($0.tableNumber ?? .max) < ($1.tableNumber ?? .max) }
            state = .loaded(Loaded(event: e,
                                   matches: sortedMatches,
                                   standings: s,
                                   myMatch: resolved,
                                   myName: resolved?.me.displayName ?? myAlias))
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            state = .failed(message)
        }
    }

    // MARK: - Loaded content

    @ViewBuilder
    private func content(_ data: Loaded) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(data.event)

                if let mine = data.myMatch {
                    yourMatch(mine, round: data.event.currentRound?.roundNumber)
                }

                cutOutlook(data)

                if !data.matches.isEmpty {
                    let roundLabel = data.event.currentRound.map { " · Round \($0.roundNumber)" } ?? ""
                    sectionTitle("Pairings" + roundLabel)
                    VStack(spacing: 8) {
                        ForEach(data.matches) { matchRow($0, myName: data.myName) }
                    }
                }

                if !data.standings.isEmpty {
                    sectionTitle("Standings")
                    VStack(spacing: 0) {
                        ForEach(data.standings.prefix(16)) { standingRow($0, myName: data.myName) }
                    }
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .refreshable { await load() }
        .sheet(item: $reporting) { match in
            ReportResultSheet(match: match,
                              isBestOfThree: data.event.isBestOfThree,
                              token: session.token ?? "",
                              onReported: { Task { await load() } })
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func header(_ event: LocatorEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(event.name).font(.title3.weight(.semibold))
                Spacer(minLength: 8)
                statusPill(event)
            }
            if let address = event.fullAddress, !address.isEmpty {
                Label(address, systemImage: "mappin.and.ellipse")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                infoPill(icon: "person.3.fill", text: "\(event.startingPlayerCount ?? 0) players")
                if let round = event.currentRound, let total = roundsTotal(event) {
                    infoPill(icon: "flag.checkered", text: "Round \(round.roundNumber) / \(total)")
                }
                infoPill(icon: "die.face.5", text: event.isBestOfThree ? "Best of 3" : "Best of 1")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func roundsTotal(_ event: LocatorEvent) -> Int? {
        event.numberOfRounds
            ?? event.tournamentPhases.first?.numberOfRounds
            ?? (event.allRounds.isEmpty ? nil : event.allRounds.count)
    }

    @ViewBuilder
    private func statusPill(_ event: LocatorEvent) -> some View {
        let live = (event.displayStatus ?? "").lowercased().contains("progress")
        Text(live ? "LIVE" : (event.displayStatus ?? event.eventStatus ?? "").capitalized)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(live ? Color.green.opacity(0.25) : Color.secondary.opacity(0.2), in: Capsule())
            .foregroundStyle(live ? .green : .secondary)
    }

    @ViewBuilder
    private func infoPill(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.secondary.opacity(0.15), in: Capsule())
    }

    // MARK: - Your match card

    @ViewBuilder
    private func yourMatch(_ match: ResolvedMyMatch, round: Int?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Your match" + (round.map { " · Round \($0)" } ?? ""), systemImage: "person.fill.viewfinder")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Spacer()
                Text(match.isComplete ? "Reported" : "In progress")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if match.isBye {
                Text("Bye. You advance this round.")
                    .font(.subheadline.weight(.medium))
            } else {
                HStack {
                    Label("Table \(match.tableNumber.map(String.init) ?? "—")", systemImage: "tablecells")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                HStack(spacing: 10) {
                    playerColumn(name: match.me.displayName, record: match.me.record, mine: true)
                    Text("vs").font(.caption).foregroundStyle(.secondary)
                    playerColumn(name: match.opponent?.displayName ?? "TBD",
                                 record: match.opponent?.record ?? "",
                                 mine: false)
                }
                if match.isComplete {
                    Label("Result reported. Ask the scorekeeper to change it.",
                          systemImage: "checkmark.seal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                } else if match.opponent != nil, session.token != nil {
                    Button { reporting = match } label: {
                        Label("Report result", systemImage: "square.and.pencil")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(Color.orange, lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private func playerColumn(name: String, record: String, mine: Bool) -> some View {
        VStack(spacing: 4) {
            Text(name).font(.subheadline.weight(.semibold)).lineLimit(1)
            Text(record.isEmpty ? "—" : record).font(.caption2).foregroundStyle(.secondary)
            if mine {
                Text("you").font(.caption2).foregroundStyle(.blue)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Top cut outlook

    @ViewBuilder
    private func cutOutlook(_ data: Loaded) -> some View {
        if data.event.hasTopCut,
           let cut = data.event.resolvedCutSize,
           let roundsLeft = data.event.swissRoundsLeft, roundsLeft >= 1,
           let myName = data.myName,
           let mine = data.standings.first(where: { $0.tvDisplayName == myName }) {

            let myPoints = mine.totalMatchPoints ?? 0
            let others = data.standings
                .filter { $0.tvDisplayName != myName }
                .map { $0.totalMatchPoints ?? 0 }
            let outlook = DrawCalc.outlook(myPoints: myPoints, others: others, cut: cut, roundsLeft: roundsLeft)
            let suffix = roundsLeft == 1 ? "" : " out"

            VStack(alignment: .leading, spacing: 10) {
                Label("Can I draw? · top cut outlook", systemImage: "chart.bar.doc.horizontal")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text("Top \(cut) · \(roundsLeft) round\(roundsLeft == 1 ? "" : "s") left · you have \(myPoints) pts")
                    .font(.caption).foregroundStyle(.secondary)
                outlookRow("Win" + suffix, outlook.win)
                outlookRow("Draw" + suffix, outlook.draw)
                outlookRow("Lose" + suffix, outlook.lose)
                Text("“Locked in” is guaranteed regardless of other results. “Bubble” depends on other matches and tiebreakers.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    @ViewBuilder
    private func outlookRow(_ title: String, _ chance: CutChance) -> some View {
        HStack {
            Text(title).font(.subheadline.weight(.medium))
            Spacer()
            chanceBadge(chance)
        }
    }

    @ViewBuilder
    private func chanceBadge(_ chance: CutChance) -> some View {
        let color: Color = chance == .locked ? .green : (chance == .bubble ? .orange : .red)
        let icon: String = chance == .locked ? "checkmark.seal.fill"
            : (chance == .bubble ? "exclamationmark.triangle.fill" : "xmark.seal.fill")
        Label(chance.label, systemImage: icon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }

    // MARK: - Rows

    @ViewBuilder
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    private func isMe(_ name: String, _ myName: String?) -> Bool {
        guard let myName, !myName.isEmpty else { return false }
        return name == myName
    }

    @ViewBuilder
    private func matchRow(_ match: LocatorMatch, myName: String?) -> some View {
        let mine = match.players.contains { isMe($0.tvDisplayName, myName) }
        HStack(spacing: 12) {
            Text("T\(match.tableNumber.map(String.init) ?? "—")")
                .font(.caption.weight(.bold))
                .foregroundStyle(.orange)
                .frame(width: 34)

            if match.isBye, let solo = match.players.first {
                Text("\(solo.tvDisplayName) (Bye)").font(.subheadline)
                Spacer()
            } else {
                playerCell(match.players.first, myName: myName)
                Text("vs").font(.caption2).foregroundStyle(.secondary)
                playerCell(match.players.dropFirst().first, myName: myName, alignTrailing: true)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(mine ? 0.9 : 0), lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private func playerCell(_ player: LocatorMatchPlayer?, myName: String?, alignTrailing: Bool = false) -> some View {
        if let player {
            let mine = isMe(player.tvDisplayName, myName)
            VStack(alignment: alignTrailing ? .trailing : .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if player.isWinner ?? false {
                        Image(systemName: "crown.fill").font(.caption2).foregroundStyle(.yellow)
                    }
                    Text(player.tvDisplayName)
                        .font(.subheadline.weight(mine ? .bold : .medium))
                        .foregroundStyle(mine ? .orange : .primary)
                        .lineLimit(1)
                }
                Text(player.record).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: alignTrailing ? .trailing : .leading)
        } else {
            Text("—").frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func standingRow(_ standing: LocatorStanding, myName: String?) -> some View {
        let mine = isMe(standing.tvDisplayName, myName)
        HStack(spacing: 12) {
            Text("\(standing.rank)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(standing.rank <= 8 ? .orange : .secondary)
                .frame(width: 28, alignment: .leading)
            Text(standing.tvDisplayName)
                .font(.subheadline.weight(mine ? .bold : .regular))
                .foregroundStyle(mine ? .orange : .primary)
                .lineLimit(1)
            Spacer()
            Text(standing.record).font(.caption).foregroundStyle(.secondary)
            Text("\(standing.totalMatchPoints ?? 0)p")
                .font(.caption.weight(.semibold))
                .frame(width: 36, alignment: .trailing)
            Text(standing.omwText)
                .font(.caption2).foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(mine ? Color.orange.opacity(0.12) : Color.clear)
        .overlay(alignment: .bottom) {
            Divider().opacity(standing.rank == 16 ? 0 : 0.5)
        }
    }
}

#Preview {
    NavigationStack {
        EventDetailView(eventID: 604874)
    }
    .environmentObject(AuthSession())
}
