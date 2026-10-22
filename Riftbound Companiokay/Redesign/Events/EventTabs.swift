//
//  EventTabs.swift
//  Riftbound Companiokay
//
//  The event page's Matches, Rounds and Standings tabs (Android `EventTabs.kt`, classic
//  `PlayRiftboundEventRoundsView`, `PlayRiftboundEventStandingsView`): the final standing once over, the open
//  pairing with Report, the round clock, every round's tables, Riot's standings or a live preview of the running
//  round with the player's line and "Can I draw?".
//

import SwiftUI

/// Record a team had before the round ("2-0-0"), from the standings through the round before; none in a top cut.
private func recordBefore(_ t: CompeteTournament, _ round: CompeteTournament.Round, _ team: String?) -> String? {
    guard let team, !t.isElimination(round) else { return nil }
    if round.roundNumber <= 1 { return "0-0-0" }
    return CompeteStandings.compute(t, throughRound: round.roundNumber - 1).rows.first { $0.esportsTeamId == team }?.record
}

// MARK: - Matches

struct MatchesTab: View {
    let tournament: CompeteTournament
    let playerID: String?
    let isPast: Bool
    let onReport: (CompetePairing) -> Void

    var body: some View {
        let t = tournament
        let myTeam = playerID.flatMap { t.teamID(playerID: $0) }
        let rounds = t.rounds
        let pairings = playerID.map { me in rounds.compactMap { CompetePairing.resolve(in: t, playerID: me, round: $0) } } ?? []
        let dropped = playerID.map { t.state(of: $0) == .dropped } == true
        // Over for this player: the event ended, they are out of the top cut, or they dropped (mock).
        let isOver = isPast || t.isFinished || dropped || playerID.map { t.state(of: $0) == .eliminated } == true
        // The latest round stays up top until the next one, reported or not (mock); the list below has every round.
        let current = pairings.last.flatMap { !isOver && $0.roundID == rounds.last?.id ? $0 : nil }
        VStack(alignment: .leading, spacing: 0) {
            if playerID == nil {
                Text("You are not in this event's player list.").font(RiftFont.text(12.5)).foregroundStyle(.white.opacity(0.6)).padding(.top, 12)
            }
            if isOver, let myTeam, let placement = t.placement(teamID: myTeam) {
                FinalCard(tournament: t, placement: placement, team: myTeam).padding(.top, 12)
            }
            if dropped {
                EvCard {
                    CardLabel(text: "You dropped")
                    Text("Your earlier results stay in the standings. No more pairings for you in this event.")
                        .font(RiftFont.text(12.5)).foregroundStyle(.white.opacity(0.6)).padding(.top, 6)
                }
                .padding(.top, 12)
            }
            if let current, let last = rounds.last {
                CurrentCard(tournament: t, pairing: current, round: last, myTeam: myTeam, onReport: onReport).padding(.top, 12)
            }
            if let last = rounds.last, !isOver, last.matches.isEmpty || !last.matches.allSatisfy(\.isComplete) {
                ClockCard(title: t.title(of: last), round: last).padding(.top, 12)
            }
            let history = Array(pairings.reversed())
            if !history.isEmpty {
                EvCaption(left: "Your matches")
                EvCard {
                    ForEach(Array(history.enumerated()), id: \.element.roundID) { i, pairing in
                        HistoryRow(pairing: pairing, divider: i < history.count - 1)
                    }
                }
            }
        }
    }
}

private struct HistoryRow: View {
    let pairing: CompetePairing
    let divider: Bool

    var body: some View {
        let (label, bg, ink): (String, Color, Color) = switch pairing.result {
        case .win?: ("W", RiftColor.you, .black)
        case .loss?: ("L", RiftColor.opponent, .black)
        case .draw?: ("D", .white.opacity(0.85), .black)
        case nil: pairing.isComplete ? ("·", .white.opacity(0.1), .white) : ("live", RiftColor.you.opacity(0.16), RiftColor.you)
        }
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pairing.roundTitle + (pairing.isBye ? " · Bye" : pairing.tableNumber.map { " · Table \($0)" } ?? ""))
                    .font(RiftFont.text(15, .semibold)).foregroundStyle(.white)
                Text(pairing.isBye ? "Counts as a win" : "vs \(pairing.opponentName ?? "?")")
                    .font(RiftFont.text(12)).foregroundStyle(.white.opacity(0.58))
            }
            Spacer(minLength: 8)
            if let score = pairing.scoreText {
                Text(score).font(RiftFont.display(20)).foregroundStyle(.white).frame(width: 40, alignment: .trailing)
            }
            Text(label)
                .font(RiftFont.text(12, .heavy))
                .foregroundStyle(ink)
                .padding(.horizontal, 8)
                .frame(minWidth: 26, minHeight: 26)
                .background(bg, in: Capsule())
        }
        .frame(height: 56)
        .overlay(alignment: .bottom) { if divider { Hairline() } }
        .accessibilityElement(children: .combine)
    }
}

/// The round clock in its own view: only this card redraws every second.
private struct ClockCard: View {
    let title: String
    let round: CompeteTournament.Round

    var body: some View {
        EvCard {
            CardLabel(text: "\(title) clock")
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let clock = RoundClock(round, now: context.date) {
                    let ink = clock.over ? RiftColor.danger : .white
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .lastTextBaseline) {
                            Text(clock.text).font(RiftFont.display(64)).foregroundStyle(ink).frame(maxWidth: .infinity, alignment: .leading)
                            Text(clock.over ? "Time over" : "left · ends \(EvFmt.time(clock.endsAt))")
                                .font(RiftFont.text(12, .semibold)).foregroundStyle(.white.opacity(0.6))
                        }
                        ClockRail(fraction: clock.fraction, color: ink)
                    }
                    .padding(.top, 6)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(clock.over ? "Time over by \(clock.text)" : "\(clock.text) left")
                } else {
                    Text("Not started yet").font(RiftFont.text(12.5)).foregroundStyle(.white.opacity(0.6)).padding(.top, 6)
                }
            }
        }
    }
}

private struct FinalCard: View {
    let tournament: CompeteTournament
    let placement: CompeteTournament.Placement
    let team: String

    var body: some View {
        let (title, crown, medal): (String, Bool, Bool) = switch placement {
        case .rank(let n): (EvFmt.ordinal(n), n == 1, n <= 3)
        case .top(let n): ("Top \(n)", false, n <= 4)
        }
        let standing = tournament.finalSwissStanding(teamID: team)
        let cut = tournament.rounds.contains { tournament.isElimination($0) }
        EvCard {
            CardLabel(text: "Final standing")
            HStack(spacing: 16) {
                Image(systemName: crown ? "crown.fill" : "medal.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 56, height: 56)
                    .background(crown ? RiftColor.gold : medal ? Color(hex: "C9CDD2") : .white.opacity(0.2), in: Circle())
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(RiftFont.display(64)).foregroundStyle(.white)
                    if let standing {
                        Text("\(standing.record) · \(standing.matchPoints ?? 0) pts" + (cut ? " after Swiss" : ""))
                            .font(RiftFont.text(12.5)).foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .padding(.top, 8)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The open pairing: both sides with their record before this round, Report or what was reported.
private struct CurrentCard: View {
    let tournament: CompeteTournament
    let pairing: CompetePairing
    let round: CompeteTournament.Round
    let myTeam: String?
    let onReport: (CompetePairing) -> Void

    var body: some View {
        EvCard(glow: true) {
            CardLabel(text: pairing.roundTitle + (pairing.tableNumber.map { " · Table \($0)" } ?? ""), color: RiftColor.you)
            if pairing.isBye {
                Text("Bye this round").font(RiftFont.display(24)).foregroundStyle(.white).padding(.top, 8)
                Text("Counts as a win. Your next pairing comes with the next round.")
                    .font(RiftFont.text(12.5)).foregroundStyle(.white.opacity(0.6)).padding(.top, 4)
            } else {
                HStack(alignment: .center, spacing: 8) {
                    Side(name: pairing.mySide, record: recordBefore(tournament, round, myTeam), alignment: .leading)
                    Text("VS").font(RiftFont.display(13, weight: 800)).tracking(1.3).foregroundStyle(.white.opacity(0.4))
                    Side(name: pairing.opponentName ?? "?", record: recordBefore(tournament, round, pairing.opponentTeamID), alignment: .trailing)
                }
                .padding(.top, 8)
                if pairing.isReportable {
                    EvButton(text: "Report result", kind: .green) { onReport(pairing) }.padding(.top, 14)
                } else if pairing.isComplete {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                        Text("Reported" + (pairing.scoreText.map { " · You \($0) \(pairing.opponentName ?? "")" } ?? ""))
                            .font(RiftFont.text(13.5, .semibold))
                    }
                    .foregroundStyle(RiftColor.you)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .background(RiftColor.you.opacity(0.1), in: Capsule())
                    .overlay(Capsule().stroke(RiftColor.you.opacity(0.4), lineWidth: 1))
                    .padding(.top, 12)
                }
            }
        }
    }
}

private struct Side: View {
    let name: String
    let record: String?
    let alignment: HorizontalAlignment

    var body: some View {
        let text: TextAlignment = alignment == .leading ? .leading : .trailing
        VStack(alignment: alignment, spacing: 3) {
            Text(name).font(RiftFont.display(24)).foregroundStyle(.white).lineLimit(2).multilineTextAlignment(text)
            if let record { Text(record).font(RiftFont.text(12)).foregroundStyle(.white.opacity(0.6)) }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}

// MARK: - Rounds

/// Every round's pairings (classic `PlayRiftboundRoundsTab`); rounds still to come show as dimmed chips.
struct RoundsTab: View {
    let tournament: CompeteTournament
    let myTeamID: String?
    @State private var chosen: String?

    var body: some View {
        let t = tournament
        let rounds = t.rounds
        if let round = rounds.first(where: { $0.id == chosen }) ?? rounds.last {
            let upcoming = rounds.contains { t.isElimination($0) } ? [] : Array(Swift.max(t.swissRounds.count + 1, 1)...Swift.max(t.plannedSwissRounds, t.swissRounds.count)).filter { $0 > t.swissRounds.count }
            VStack(alignment: .leading, spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(rounds) { r in EvChip(text: t.shortTitle(of: r), on: r.id == round.id, display: true) { chosen = r.id } }
                        ForEach(upcoming, id: \.self) { n in EvChip(text: "R\(n)", on: false, enabled: false, display: true) {} }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, -16)
                .padding(.top, 12)
                let live = round.id == rounds.last?.id && !t.isFinished
                VStack(spacing: 4) {
                    ForEach(CompeteTournament.tableOrder(round.matches), id: \.match.esportsMatchId) { slot in
                        matchRow(slot.match, table: slot.table, live: live)
                    }
                    ForEach(round.byeTeamIds ?? [], id: \.self) { team in
                        TableRow(table: "–", names: [(t.teamName(team), true), ("Bye", false)], result: "bye", mine: team == myTeamID, byeRow: true)
                    }
                }
                .padding(.top, 8)
                .softIn(duration: 0.7)
                .id(round.id)
            }
        }
    }

    private func matchRow(_ match: CompeteTournament.Match, table: Int, live: Bool) -> some View {
        let teams = match.teams
        let games = match.games ?? []
        func wins(_ id: String) -> Int { games.filter { g in (g.teamOutcomes ?? []).contains { $0.esportsTeamId == id && $0.isWin } }.count }
        let scored = teams.count == 2 && games.contains { !($0.teamOutcomes ?? []).isEmpty }
        let result: String? = scored ? "\(wins(teams[0].esportsTeamId))–\(wins(teams[1].esportsTeamId))" : match.isComplete ? "done" : live ? nil : "no result"
        let names = teams.map { team in
            (tournament.teamName(team.esportsTeamId), (match.teamOutcomes ?? []).contains { $0.esportsTeamId == team.esportsTeamId && $0.isWin })
        }
        return TableRow(table: "\(table)", names: names, result: result, mine: teams.contains { $0.esportsTeamId == myTeamID })
    }
}

private struct TableRow: View {
    let table: String
    let names: [(String, Bool)]
    let result: String?
    let mine: Bool
    var byeRow = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14)
        HStack(spacing: 10) {
            Text(table).font(RiftFont.display(18)).foregroundStyle(.white.opacity(0.5)).frame(width: 26, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(names.enumerated()), id: \.offset) { i, name in
                    Text(name.0)
                        .font(RiftFont.text(14, .semibold))
                        .foregroundStyle(byeRow && i == 1 ? .white.opacity(0.5) : name.1 ? RiftColor.you : .white)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let result {
                Text(result).font(RiftFont.display(14, weight: 800)).tracking(0.5).foregroundStyle(.white)
            } else {
                EvPill(text: "live", bg: RiftColor.you.opacity(0.14), ink: RiftColor.you)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minHeight: 50)
        .background(mine ? RiftColor.you.opacity(0.08) : .clear, in: shape)
        .overlay(shape.stroke(mine ? RiftColor.you.opacity(0.35) : .clear, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Standings

/// Riot's table after a finished round, or a live preview of the running round from the results reported so
/// far, the player's line and "Can I draw?" (classic `PlayRiftboundStandingsTab`).
struct StandingsTab: View {
    let tournament: CompeteTournament
    let myTeamID: String?
    let canDraw: Bool
    let onDraw: () -> Void
    @State private var selection: Selection?
    @State private var open: Set<String> = []

    enum Selection: Hashable { case live, after(String) }

    var body: some View {
        let t = tournament
        let official = t.rounds.filter { !($0.endOfRoundStandings ?? []).isEmpty }
        let running = t.rounds.last.flatMap { t.isElimination($0) ? nil : $0 }
        let live: CompeteStandings.Table? = running.flatMap { r in
            guard (r.endOfRoundStandings ?? []).isEmpty else { return nil }
            let table = CompeteStandings.compute(t, throughRound: r.roundNumber)
            return table.reportedMatches > 0 ? table : nil
        }
        let current = resolved(official: official, live: live)
        let rows: [CompeteTournament.Standing] = {
            switch current {
            case .live?: return live?.rows ?? []
            case .after(let id)?: return (official.first { $0.id == id }?.endOfRoundStandings ?? []).sorted { ($0.rank ?? .max) < ($1.rank ?? .max) }
            case nil: return []
            }
        }()
        VStack(alignment: .leading, spacing: 0) {
            if rows.isEmpty {
                Text("Standings appear once the first result is reported.").font(RiftFont.text(12.5)).foregroundStyle(.white.opacity(0.6)).padding(.top, 14)
            } else {
                if official.count + (live == nil ? 0 : 1) > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(official) { r in EvChip(text: "After \(t.shortTitle(of: r))", on: current == .after(r.id)) { selection = .after(r.id) } }
                            if let live { EvChip(text: "Live R\(live.roundNumber) •", on: current == .live) { selection = .live } }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.horizontal, -16)
                    .padding(.top, 12)
                }
                if current == .live, let live { PreviewBanner(table: live).padding(.top, 12) }
                if let mine = rows.first(where: { $0.esportsTeamId == myTeamID }) {
                    MyStanding(standing: mine, preview: current == .live).padding(.top, 12)
                    if current == .live, canDraw, t.plannedSwissRounds > 0 {
                        Button(action: onDraw) {
                            Text("Can I draw?")
                                .font(RiftFont.text(15, .bold))
                                .foregroundStyle(RiftColor.you)
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(RiftColor.you.opacity(0.08), in: Capsule())
                                .overlay(Capsule().stroke(RiftColor.you.opacity(0.5), lineWidth: 1))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(PressScale(scale: 0.98))
                        .padding(.top, 12)
                    }
                }
                table(rows, pending: current == .live ? live?.pending ?? [] : [])
                Text("OMW: opponents' match-win rate. GW: your game-win rate. OGW: opponents' game-win rate. Each has a 33% floor.")
                    .font(RiftFont.text(12)).lineSpacing(4).foregroundStyle(.white.opacity(0.5)).padding(.top, 12)
            }
        }
    }

    /// During a round the live preview is what players want; otherwise Riot's latest table.
    private func resolved(official: [CompeteTournament.Round], live: CompeteStandings.Table?) -> Selection? {
        switch selection {
        case .live?: if live != nil { return .live }
        case .after(let id)?: if official.contains(where: { $0.id == id }) { return .after(id) }
        case nil: break
        }
        if live != nil { return .live }
        return official.last.map { .after($0.id) }
    }

    private func table(_ rows: [CompeteTournament.Standing], pending: Set<String>) -> some View {
        EvCard {
            ForEach(Array(rows.enumerated()), id: \.element.esportsTeamId) { i, s in
                let mine = myTeamID != nil && s.esportsTeamId == myTeamID
                let dropped = tournament.participant(teamID: s.esportsTeamId)?.status?.uppercased().contains("DROP") == true
                let ink: Color = mine ? RiftColor.you : dropped ? .white.opacity(0.4) : .white
                let expanded = open.contains(s.esportsTeamId)
                Button {
                    withAnimation(.rift(0.4)) { open = expanded ? open.subtracting([s.esportsTeamId]) : open.union([s.esportsTeamId]) }
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 10) {
                            Text("\(s.rank ?? i + 1)").font(RiftFont.display(18)).foregroundStyle(ink).frame(width: 30, alignment: .leading)
                            Text(tournament.teamName(s.esportsTeamId)).font(RiftFont.text(14, .semibold)).foregroundStyle(ink).lineLimit(1)
                            if dropped {
                                MiniPill(text: "DROPPED", bg: .white.opacity(0.1), ink: .white.opacity(0.6))
                            } else if pending.contains(s.esportsTeamId) {
                                MiniPill(text: "PLAYING", bg: RiftColor.you.opacity(0.14), ink: RiftColor.you)
                            }
                            Spacer(minLength: 6)
                            Text(s.record).font(RiftFont.text(14, .semibold)).monospacedDigit().foregroundStyle(.white.opacity(0.7)).frame(width: 52, alignment: .trailing)
                            Text("\(s.matchPoints ?? 0)").font(RiftFont.display(18)).foregroundStyle(ink).frame(width: 34, alignment: .trailing)
                        }
                        .padding(.horizontal, 4)
                        .frame(height: 46)
                        if expanded {
                            Text(Self.tiebreakers(s))
                                .font(RiftFont.text(12))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.leading, 44)
                                .padding(.trailing, 6)
                                .padding(.bottom, 10)
                                .softIn(duration: 0.5)
                        }
                    }
                    .overlay(alignment: .bottom) { if i < rows.count - 1 { Hairline() } }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressScale(scale: 0.99))
                .accessibilityHint(expanded ? "Hides the tiebreakers" : "Shows the tiebreakers")
            }
        }
        .padding(.top, 12)
    }

    static func tiebreakers(_ s: CompeteTournament.Standing) -> String {
        "OMW \(EvFmt.pct(s.opponentMatchWinPercentage)) · GW \(EvFmt.pct(s.gameWinPercentage)) · OGW \(EvFmt.pct(s.opponentGameWinPercentage))"
    }
}

private struct PreviewBanner: View {
    let table: CompeteStandings.Table

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16)
        VStack(alignment: .leading, spacing: 4) {
            Text("PREVIEW · NOT FINAL").caps(11, tracking: 0.14, weight: .bold).foregroundStyle(RiftColor.gold)
            Text("Calculated in the app from \(table.reportedMatches) of \(table.totalMatches) results reported in round \(table.roundNumber). PlayRiftbound publishes the official standings when the round ends; places can still change.")
                .font(RiftFont.text(12.5)).lineSpacing(4).foregroundStyle(.white.opacity(0.82))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RiftColor.gold.opacity(0.08), in: shape)
        .overlay(shape.stroke(RiftColor.gold.opacity(0.32), lineWidth: 1))
    }
}

private struct MyStanding: View {
    let standing: CompeteTournament.Standing
    let preview: Bool

    var body: some View {
        EvCard {
            CardLabel(text: "Your standing")
            HStack(spacing: 16) {
                Text(standing.rank.map(EvFmt.ordinal) ?? "–").font(RiftFont.display(60)).foregroundStyle(RiftColor.you)
                VStack(alignment: .leading, spacing: 3) {
                    if preview { MiniPill(text: "PREVIEW", bg: RiftColor.gold, ink: .black) }
                    Text("\(standing.record) · \(standing.matchPoints ?? 0) pts").font(RiftFont.text(14, .semibold)).foregroundStyle(.white)
                    Text(StandingsTab.tiebreakers(standing)).font(RiftFont.text(12)).foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.top, 6)
        }
        .accessibilityElement(children: .combine)
    }
}
