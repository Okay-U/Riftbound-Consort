//
//  PlayRiftboundEventStandingsView.swift
//  Riftbound Companiokay
//
//  The "Standings" and "Roster" tabs of the native event screen: the table
//  after any round with the full tiebreakers, the "can I draw?" outlook for
//  the signed-in player, and the player list with active / dropped state.
//

import SwiftUI

// MARK: - Standings

struct PlayRiftboundStandingsTab: View {
    let tournament: CompeteTournament
    let myTeamID: String?
    @State private var selectedRound: Int?
    @State private var expanded: Set<String> = []
    @State private var cutSize = 8

    private var roundsWithStandings: [CompeteTournament.Round] {
        tournament.rounds.filter { !($0.endOfRoundStandings ?? []).isEmpty }
    }
    private var round: CompeteTournament.Round? {
        roundsWithStandings.first { $0.roundNumber == selectedRound } ?? roundsWithStandings.last
    }
    private var standings: [CompeteTournament.Standing] {
        (round?.endOfRoundStandings ?? []).sorted { ($0.rank ?? Int.max) < ($1.rank ?? Int.max) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if roundsWithStandings.isEmpty {
                Text("Standings appear after the first round is reported.")
                    .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
            } else {
                if roundsWithStandings.count > 1 { roundPicker }
                if let mine = standings.first(where: { $0.esportsTeamId == myTeamID }) {
                    myCard(mine)
                    drawCard(mine)
                }
                table
                Text("OMW% opponents' match win rate · GW% your game win rate · OGW% opponents' game win rate")
                    .font(.system(size: 11)).foregroundStyle(EventsTheme.textTertiary)
            }
        }
    }

    private var roundPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(roundsWithStandings, id: \.roundNumber) { r in
                    let on = r.roundNumber == round?.roundNumber
                    Button { selectedRound = r.roundNumber } label: {
                        Text("After R\(r.roundNumber)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(on ? EventsTheme.matchFillBottom : EventsTheme.textSecondary)
                            .padding(.horizontal, 12).frame(height: 30)
                            .background(on ? EventsTheme.green : EventsTheme.card, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func myCard(_ s: CompeteTournament.Standing) -> some View {
        HStack(spacing: 14) {
            Text(s.rank.map(PlayRiftboundMatchesTab.ordinal) ?? "–")
                .font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 3) {
                Text("Your standing").font(.system(size: 11, weight: .bold)).tracking(0.5).foregroundStyle(EventsTheme.green)
                Text("\(s.record) · \(s.matchPoints ?? 0) pts").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Text(tiebreakers(s)).font(.system(size: 11)).foregroundStyle(EventsTheme.textSecondary)
            }
            Spacer()
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .greenGradientBorder(radius: 15)
    }

    /// Swiss top-cut outlook. Riot's data has no cut size, so the player picks one.
    @ViewBuilder
    private func drawCard(_ mine: CompeteTournament.Standing) -> some View {
        let total = tournament.config?.roundCount ?? 0
        let played = tournament.rounds.filter { !$0.matches.isEmpty && $0.matches.allSatisfy(\.isComplete) }.count
        let roundsLeft = total - played
        if roundsLeft >= 1, let myTeamID {
            let last = tournament.rounds.last(where: { !($0.endOfRoundStandings ?? []).isEmpty })?.endOfRoundStandings ?? []
            let myPoints = last.first { $0.esportsTeamId == myTeamID }?.matchPoints ?? mine.matchPoints ?? 0
            let others = last.filter { $0.esportsTeamId != myTeamID }.map { $0.matchPoints ?? 0 }
            let outlook = DrawCalc.outlook(myPoints: myPoints, others: others, cut: cutSize, roundsLeft: roundsLeft)
            let suffix = roundsLeft == 1 ? "" : " out"
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionHeader("chart.bar.doc.horizontal", "Can I draw?")
                    Picker("Top cut", selection: $cutSize) {
                        Text("Top 4").tag(4); Text("Top 8").tag(8); Text("Top 16").tag(16)
                    }
                    .pickerStyle(.menu).tint(EventsTheme.textSecondary)
                }
                Text("Top \(cutSize) · \(roundsLeft) round\(roundsLeft == 1 ? "" : "s") left · you have \(myPoints) pts")
                    .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
                outlookRow("Win" + suffix, outlook.win)
                outlookRow("Draw" + suffix, outlook.draw)
                outlookRow("Lose" + suffix, outlook.lose)
                Text("“Locked in” is guaranteed regardless of other results. “Bubble” depends on other matches and tiebreakers.")
                    .font(.system(size: 11)).foregroundStyle(EventsTheme.textTertiary)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .eventsCard(radius: 15)
        }
    }

    private func outlookRow(_ title: String, _ chance: CutChance) -> some View {
        HStack {
            Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
            Spacer()
            chanceBadge(chance)
        }
    }

    private func chanceBadge(_ chance: CutChance) -> some View {
        let (color, bg, icon): (Color, Color, String) = switch chance {
        case .locked: (EventsTheme.green, EventsTheme.greenSoft, "checkmark.seal.fill")
        case .bubble: (EventsTheme.textSecondary, Color.white.opacity(0.08), "exclamationmark.triangle.fill")
        case .out:    (.red, Color.red.opacity(0.16), "xmark.seal.fill")
        }
        return HStack(spacing: 5) { Image(systemName: icon); Text(chance.label) }
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(bg, in: Capsule()).foregroundStyle(color)
    }

    private var table: some View {
        VStack(spacing: 0) {
            ForEach(Array(standings.enumerated()), id: \.element.esportsTeamId) { index, s in
                let mine = s.esportsTeamId == myTeamID
                let dropped = tournament.participant(teamID: s.esportsTeamId)?.status?.uppercased().contains("DROP") == true
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text("\(s.rank ?? index + 1)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(mine ? EventsTheme.green : EventsTheme.textSecondary).frame(width: 26)
                        Text(tournament.teamName(s.esportsTeamId))
                            .font(.system(size: 14, weight: mine ? .bold : .regular))
                            .foregroundStyle(dropped ? EventsTheme.textTertiary : (mine ? EventsTheme.green : .white)).lineLimit(1)
                        if dropped { statusPill("Dropped", tint: EventsTheme.textTertiary) }
                        Spacer()
                        Text(s.record).font(.system(size: 12, design: .rounded)).foregroundStyle(EventsTheme.textSecondary)
                        Text("\(s.matchPoints ?? 0) pts").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white).frame(width: 46, alignment: .trailing)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(EventsTheme.textTertiary)
                            .rotationEffect(.degrees(expanded.contains(s.esportsTeamId) ? 180 : 0))
                    }
                    if expanded.contains(s.esportsTeamId) {
                        Text(tiebreakers(s)).font(.system(size: 11)).foregroundStyle(EventsTheme.textSecondary).padding(.leading, 36)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(mine ? EventsTheme.greenSoft : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if !expanded.insert(s.esportsTeamId).inserted { expanded.remove(s.esportsTeamId) }
                    }
                }
                if index < standings.count - 1 { Divider().overlay(EventsTheme.hairline) }
            }
        }
        .eventsCard(radius: 15)
    }

    private func tiebreakers(_ s: CompeteTournament.Standing) -> String {
        func pct(_ v: Double?) -> String { v.map { String(format: "%.1f%%", $0 <= 1 ? $0 * 100 : $0) } ?? "–" }
        return "OMW \(pct(s.opponentMatchWinPercentage)) · GW \(pct(s.gameWinPercentage)) · OGW \(pct(s.opponentGameWinPercentage))"
    }

    private func statusPill(_ text: String, tint: Color) -> some View {
        Text(text).font(.system(size: 10, weight: .bold)).foregroundStyle(tint)
            .padding(.horizontal, 6).padding(.vertical, 2).background(tint.opacity(0.14), in: Capsule())
    }
}

// MARK: - Roster

struct PlayRiftboundRosterTab: View {
    let tournament: CompeteTournament
    let myTeamID: String?

    private var participants: [CompeteTournament.Participant] {
        (tournament.tournamentParticipants ?? []).sorted {
            ($0.player?.displayName ?? "").localizedCaseInsensitiveCompare($1.player?.displayName ?? "") == .orderedAscending
        }
    }

    var body: some View {
        let active = participants.filter { !isDropped($0) }
        let dropped = participants.filter(isDropped)
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("person.3", "Players") { Text("\(active.count) active").foregroundStyle(EventsTheme.textTertiary) }
            list(active)
            if !dropped.isEmpty {
                SectionHeader("person.slash", "Dropped") { Text("\(dropped.count)").foregroundStyle(EventsTheme.textTertiary) }
                list(dropped)
            }
        }
    }

    private func list(_ players: [CompeteTournament.Participant]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(players.enumerated()), id: \.element.id) { index, p in
                let mine = p.esportsTeamId == myTeamID
                HStack {
                    Text(p.player?.displayName ?? "Player")
                        .font(.system(size: 14, weight: mine ? .bold : .regular))
                        .foregroundStyle(isDropped(p) ? EventsTheme.textTertiary : (mine ? EventsTheme.green : .white))
                    if mine { Text("You").font(.system(size: 10, weight: .bold)).foregroundStyle(EventsTheme.green)
                        .padding(.horizontal, 6).padding(.vertical, 2).background(EventsTheme.greenSoft, in: Capsule()) }
                    Spacer()
                    if let seed = p.position { Text("#\(seed)").font(.system(size: 12, design: .rounded)).foregroundStyle(EventsTheme.textTertiary) }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                if index < players.count - 1 { Divider().overlay(EventsTheme.hairline) }
            }
        }
        .eventsCard(radius: 15)
    }

    private func isDropped(_ p: CompeteTournament.Participant) -> Bool {
        p.status?.uppercased().contains("DROP") == true
    }
}
