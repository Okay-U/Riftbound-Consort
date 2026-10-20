//
//  PlayRiftboundEventStandingsView.swift
//  Riftbound Companiokay
//
//  The "Standings" and "Roster" tabs of the native event screen: Riot's table
//  after any finished round, a live preview of the running round computed from
//  the results reported so far (CompeteStandings), the "can I draw?" outlook
//  for the signed-in player, and the player list with active / dropped state.
//

import SwiftUI

// MARK: - Standings

struct PlayRiftboundStandingsTab: View {
    let tournament: CompeteTournament
    let myTeamID: String?
    @State private var selection: Selection?
    @State private var expanded: Set<String> = []
    @State private var cutSize = 8

    /// Riot's table after a finished round (by `Round.id`), or our live preview of the running one.
    enum Selection: Hashable { case live, after(String) }

    private var roundsWithStandings: [CompeteTournament.Round] {
        tournament.rounds.filter { !($0.endOfRoundStandings ?? []).isEmpty }
    }

    /// The running Swiss round, nil once a top cut has started.
    private var runningSwissRound: CompeteTournament.Round? {
        guard let last = tournament.rounds.last, !tournament.isElimination(last) else { return nil }
        return last
    }

    /// The running round's table computed from the results reported so far. Nil once Riot
    /// published the round's standings, or while nothing in it is reported yet.
    private var liveTable: CompeteStandings.Table? {
        guard let last = runningSwissRound, (last.endOfRoundStandings ?? []).isEmpty else { return nil }
        let table = CompeteStandings.compute(tournament, throughRound: last.roundNumber)
        return table.reportedMatches > 0 ? table : nil
    }

    var body: some View {
        let live = liveTable
        let current = resolvedSelection(live: live)
        let rows = rows(for: current, live: live)
        VStack(alignment: .leading, spacing: 12) {
            if rows.isEmpty {
                Text("Standings appear once the first result is reported.")
                    .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
            } else {
                if roundsWithStandings.count + (live == nil ? 0 : 1) > 1 { roundPicker(current: current, live: live) }
                if current == .live, let live { previewBanner(live) }
                if let mine = rows.first(where: { $0.esportsTeamId == myTeamID }) {
                    myCard(mine, live: current == .live)
                }
                drawCard
                table(rows, pending: current == .live ? live?.pending ?? [] : [])
                Text("OMW% opponents' match win rate · GW% your game win rate · OGW% opponents' game win rate")
                    .font(.system(size: 11)).foregroundStyle(EventsTheme.textTertiary)
            }
        }
    }

    private func resolvedSelection(live: CompeteStandings.Table?) -> Selection {
        switch selection {
        case .live?: if live != nil { return .live }
        case .after(let id)?: if roundsWithStandings.contains(where: { $0.id == id }) { return .after(id) }
        case nil: break
        }
        // During a round the live preview is what players want; otherwise Riot's latest table.
        if live != nil { return .live }
        return .after(roundsWithStandings.last?.id ?? "")
    }

    private func rows(for selection: Selection, live: CompeteStandings.Table?) -> [CompeteTournament.Standing] {
        switch selection {
        case .live: return live?.rows ?? []
        case .after(let id):
            let round = roundsWithStandings.first { $0.id == id }
            return (round?.endOfRoundStandings ?? []).sorted { ($0.rank ?? Int.max) < ($1.rank ?? Int.max) }
        }
    }

    private func roundPicker(current: Selection, live: CompeteStandings.Table?) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(roundsWithStandings) { r in
                    chip("After \(tournament.shortTitle(of: r))", on: current == .after(r.id)) { selection = .after(r.id) }
                }
                if let live {
                    chip("Live R\(live.roundNumber)", on: current == .live, dot: true) { selection = .live }
                }
            }
        }
    }

    private func chip(_ title: String, on: Bool, dot: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if dot { Circle().fill(on ? EventsTheme.matchFillBottom : EventsTheme.gold).frame(width: 6, height: 6) }
                Text(title)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(on ? EventsTheme.matchFillBottom : EventsTheme.textSecondary)
            .padding(.horizontal, 12).frame(height: 30)
            .background(on ? EventsTheme.green : EventsTheme.card, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func previewBanner(_ live: CompeteStandings.Table) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("PREVIEW · NOT FINAL", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .heavy)).tracking(0.4)
                .foregroundStyle(EventsTheme.gold)
            Text("Calculated in the app from \(live.reportedMatches) of \(live.totalMatches) results reported in round \(live.roundNumber). PlayRiftbound publishes the official standings when the round ends; places can still change.")
                .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(EventsTheme.gold.opacity(0.09)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(EventsTheme.gold.opacity(0.35), lineWidth: 1))
    }

    private func myCard(_ s: CompeteTournament.Standing, live: Bool) -> some View {
        HStack(spacing: 14) {
            Text(s.rank.map(PlayRiftboundMatchesTab.ordinal) ?? "–")
                .font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Your standing").font(.system(size: 11, weight: .bold)).tracking(0.5).foregroundStyle(EventsTheme.green)
                    if live {
                        Text("PREVIEW").font(.system(size: 9, weight: .heavy)).tracking(0.5).foregroundStyle(EventsTheme.gold)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(EventsTheme.gold.opacity(0.14), in: Capsule())
                    }
                }
                Text("\(s.record) · \(s.matchPoints ?? 0) pts").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Text(tiebreakers(s)).font(.system(size: 11)).foregroundStyle(EventsTheme.textSecondary)
            }
            Spacer()
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .greenGradientBorder(radius: 15)
    }

    /// Swiss top-cut outlook from every result reported so far. Each player keeps their own
    /// number of matches left (one more while their match in the running round is open,
    /// none once dropped). Riot's data has no cut size, so the player picks one.
    @ViewBuilder
    private var drawCard: some View {
        let total = tournament.plannedSwissRounds
        if total > 0, let myTeamID, let lastRound = runningSwissRound {
            let table = CompeteStandings.compute(tournament, throughRound: lastRound.roundNumber)
            let roundsAfter = max(0, total - lastRound.roundNumber)
            let remaining: (String) -> Int = { team in
                if isOut(team) { return 0 }
                return roundsAfter + (table.pending.contains(team) ? 1 : 0)
            }
            // A cut only means something below the field size: with 8 players a Top 8 is everyone.
            let cuts = Self.cutOptions.filter { $0 < table.rows.count }
            if let cut = cuts.contains(cutSize) ? cutSize : cuts.last,
               let mine = table.rows.first(where: { $0.esportsTeamId == myTeamID }), remaining(myTeamID) >= 1 {
                let myRemaining = remaining(myTeamID)
                let myPoints = mine.matchPoints ?? 0
                let others = table.rows.filter { $0.esportsTeamId != myTeamID }
                    .map { DrawContender(points: $0.matchPoints ?? 0, remaining: remaining($0.esportsTeamId)) }
                let outlook = DrawCalc.outlook(myPoints: myPoints, myRemaining: myRemaining, others: others, cut: cut)
                let suffix = myRemaining == 1 ? "" : " out"
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SectionHeader("chart.bar.doc.horizontal", "Can I draw?")
                        Picker("Top cut", selection: Binding(get: { cut }, set: { cutSize = $0 })) {
                            ForEach(cuts, id: \.self) { Text("Top \($0)").tag($0) }
                        }
                        .pickerStyle(.menu).tint(EventsTheme.textSecondary)
                    }
                    Text("Top \(cut) · \(myRemaining) match\(myRemaining == 1 ? "" : "es") left · you have \(myPoints) pts")
                        .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
                    outlookRow("Win" + suffix, outlook.win)
                    outlookRow("Draw" + suffix, outlook.draw)
                    outlookRow("Lose" + suffix, outlook.lose)
                    Text(table.reportedMatches < table.totalMatches
                         ? "Uses the \(table.reportedMatches) of \(table.totalMatches) results already reported in round \(table.roundNumber); open matches count as still to play. “Locked in” holds whatever the other results are."
                         : "“Locked in” is guaranteed regardless of other results. “Bubble” depends on other matches and tiebreakers.")
                        .font(.system(size: 11)).foregroundStyle(EventsTheme.textTertiary)
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .eventsCard(radius: 15)
            }
        }
    }

    private static let cutOptions = [4, 8, 16]

    /// Dropped or eliminated: no more matches to play.
    private func isOut(_ team: String) -> Bool {
        let status = tournament.participant(teamID: team)?.status?.uppercased() ?? ""
        return status.contains("DROP") || status.contains("ELIM")
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

    private func table(_ standings: [CompeteTournament.Standing], pending: Set<String>) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(standings.enumerated()), id: \.element.esportsTeamId) { index, s in
                let mine = myTeamID != nil && s.esportsTeamId == myTeamID
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
                        else if pending.contains(s.esportsTeamId) { statusPill("Playing", tint: EventsTheme.textSecondary) }
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
    let myPlayerID: String?

    private var myTeamID: String? { myPlayerID.flatMap(tournament.teamID(playerID:)) }

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
                let mine = myPlayerID != nil && p.player?.id == myPlayerID
                let teammate = !mine && myTeamID != nil && p.esportsTeamId == myTeamID
                HStack {
                    Text(p.player?.displayName ?? "Player")
                        .font(.system(size: 14, weight: mine ? .bold : .regular))
                        .foregroundStyle(isDropped(p) ? EventsTheme.textTertiary : (mine ? EventsTheme.green : .white))
                    if mine || teammate { Text(mine ? "You" : "Team").font(.system(size: 10, weight: .bold)).foregroundStyle(EventsTheme.green)
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
