//
//  PlayRiftboundEventRoundsView.swift
//  Riftbound Companiokay
//
//  The "Matches" and "Rounds" tabs of the native event screen: the player's
//  current pairing (with Report), the round clock, their match history, the
//  final placement once the event is over, and every round's pairings.
//

import SwiftUI

// MARK: - Matches

struct PlayRiftboundMatchesTab: View {
    let tournament: CompeteTournament
    let playerID: String?
    /// The entry came from the "past" list: show the final placement up front.
    let isPast: Bool
    var onReport: (CompetePairing) -> Void

    private var myTeamID: String? { playerID.flatMap(tournament.teamID(playerID:)) }
    private var pairings: [CompetePairing] {
        guard let playerID else { return [] }
        return tournament.rounds.compactMap { CompetePairing.resolve(in: tournament, playerID: playerID, round: $0) }
    }
    /// The running round for the player: an open match, or a bye.
    private var current: CompetePairing? {
        guard !isOver, let last = pairings.last, last.roundID == tournament.rounds.last?.id,
              last.isBye || !last.isComplete else { return nil }
        return last
    }
    /// Over for this player: the event ended, or they are out of the top cut.
    private var isOver: Bool {
        isPast || tournament.isFinished || playerID.map { tournament.state(of: $0) == .eliminated } == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if playerID == nil {
                Text("You are not in this event's player list.")
                    .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
            }
            if isOver, let teamID = myTeamID, let placement = tournament.placement(teamID: teamID) {
                finalCard(placement, teamID: teamID)
            }
            if let current {
                currentCard(current)
            }
            // Between rounds the last round is fully reported: no clock until the next one starts.
            if let round = tournament.rounds.last, !isOver,
               round.matches.isEmpty || !round.matches.allSatisfy(\.isComplete) {
                roundClock(round)
            }
            let history = pairings.filter { $0.roundID != current?.roundID }.reversed()
            if !history.isEmpty {
                SectionHeader("clock.arrow.circlepath", "Your matches")
                VStack(spacing: 8) {
                    ForEach(Array(history), id: \.roundID) { pairing in historyRow(pairing) }
                }
            }
        }
    }

    private func finalCard(_ placement: CompeteTournament.Placement, teamID: String) -> some View {
        let standing = tournament.lastStanding(teamID: teamID)
        let hasTopCut = tournament.rounds.contains(where: tournament.isElimination)
        let (title, medal): (String, String?) = switch placement {
        case .rank(1):          (Self.ordinal(1), "crown.fill")
        case .rank(let n):      (Self.ordinal(n), n <= 3 ? "medal.fill" : nil)
        case .top(let n):       ("Top \(n)", n <= 4 ? "medal.fill" : nil)
        }
        return VStack(spacing: 8) {
            Text("FINAL STANDING").font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(EventsTheme.green)
            Text(title)
                .font(.system(size: 44, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            if let standing {
                Text("\(standing.record) · \(standing.matchPoints ?? 0) pts" + (hasTopCut ? " after Swiss" : ""))
                    .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
            }
            if let medal {
                Image(systemName: medal)
                    .font(.system(size: 22)).foregroundStyle(placement == .rank(1) ? EventsTheme.gold : EventsTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 22)
        .greenGradientBorder()
    }

    private func currentCard(_ pairing: CompetePairing) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(pairing.roundTitle).font(.system(size: 12, weight: .bold)).foregroundStyle(EventsTheme.green)
                if let table = pairing.tableNumber { Text("· Table \(table)").font(.system(size: 12, weight: .semibold)).foregroundStyle(EventsTheme.textSecondary) }
                Spacer()
            }
            if pairing.isBye {
                Text("Bye this round").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                Text("Counts as a win. Your next pairing comes with the next round.")
                    .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
            } else {
                Text("\(pairing.mySide) vs \(pairing.opponentName ?? "?")").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                if pairing.isReportable {
                    Button { onReport(pairing) } label: {
                        Text("Report result")
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(EventsTheme.matchFillBottom)
                            .frame(maxWidth: .infinity).frame(height: 40)
                            .background(EventsTheme.green, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .greenGradientBorder()
    }

    /// Same clock as the site: `startedAt` plus `roundDuration` minutes (60 when
    /// Riot sends none), counting past zero once time is up.
    private func roundClock(_ round: CompeteTournament.Round) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 8) {
                Image(systemName: "timer")
                if let started = round.startedAt {
                    let end = started.addingTimeInterval(TimeInterval(round.roundDuration ?? Self.defaultRoundMinutes) * 60)
                    let remaining = Int(end.timeIntervalSince(context.date).rounded(.down))
                    let over = remaining < 0
                    Text(tournament.title(of: round))
                    Spacer()
                    Text(over ? "Time over · +\(Self.clock(-remaining))" : Self.clock(remaining))
                        .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(over ? Color.red : .white)
                } else {
                    Text("\(tournament.title(of: round)) · not started")
                    Spacer()
                }
            }
            .font(.system(size: 12, weight: .semibold)).foregroundStyle(EventsTheme.textSecondary)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .eventsCard(radius: 12)
        }
    }

    private static let defaultRoundMinutes = 60

    private static func clock(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func historyRow(_ pairing: CompetePairing) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(pairing.roundTitle + (pairing.tableNumber.map { " · Table \($0)" } ?? ""))
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(EventsTheme.textSecondary)
                Text(pairing.isBye ? "Bye" : "vs \(pairing.opponentName ?? "?")")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            }
            Spacer()
            if let score = pairing.scoreText {
                Text(score).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
            }
            resultPill(pairing)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .eventsCard(radius: 13)
    }

    @ViewBuilder
    private func resultPill(_ pairing: CompetePairing) -> some View {
        let (text, tint): (String, Color) = switch pairing.result {
        case .win:  ("W", EventsTheme.green)
        case .loss: ("L", Color.red)
        case .draw: ("D", EventsTheme.textSecondary)
        // The running round is the current card; anything open down here was never reported.
        case nil:   (pairing.isComplete ? "·" : "no result", EventsTheme.textTertiary)
        }
        Text(text)
            .font(.system(size: 11, weight: .bold)).foregroundStyle(tint)
            .frame(minWidth: 26).padding(.horizontal, 6).padding(.vertical, 4)
            .background(tint.opacity(0.14), in: Capsule())
    }

    nonisolated static func ordinal(_ n: Int) -> String {
        let suffix: String
        switch n % 100 {
        case 11, 12, 13: suffix = "th"
        default:
            switch n % 10 { case 1: suffix = "st"; case 2: suffix = "nd"; case 3: suffix = "rd"; default: suffix = "th" }
        }
        return "\(n)\(suffix)"
    }
}

// MARK: - Rounds

struct PlayRiftboundRoundsTab: View {
    let tournament: CompeteTournament
    let myTeamID: String?
    @State private var selected: String?

    private var round: CompeteTournament.Round? {
        tournament.rounds.first { $0.id == selected } ?? tournament.rounds.last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if tournament.rounds.count > 1 { roundPicker }
            if let round {
                let ordered = CompeteTournament.tableOrder(round.matches)
                let live = round.id == tournament.rounds.last?.id && !tournament.isFinished
                VStack(spacing: 8) {
                    ForEach(ordered, id: \.match.esportsMatchId) { slot in
                        matchRow(slot.match, table: slot.table, live: live)
                    }
                    ForEach(round.byeTeamIds ?? [], id: \.self) { teamID in
                        byeRow(teamID)
                    }
                }
            }
        }
    }

    private var roundPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tournament.rounds) { r in
                    let on = r.id == round?.id
                    Button { selected = r.id } label: {
                        Text(tournament.shortTitle(of: r))
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

    private func matchRow(_ match: CompeteTournament.Match, table: Int, live: Bool) -> some View {
        let teams = match.teams
        let names = teams.map { tournament.teamName($0.esportsTeamId) }
        let mine = teams.contains { $0.esportsTeamId == myTeamID }
        func gameWins(_ teamID: String) -> Int {
            (match.games ?? []).filter { g in (g.teamOutcomes ?? []).contains { $0.esportsTeamId == teamID && $0.isWin } }.count
        }
        let score = teams.count == 2 && (match.games ?? []).contains { !($0.teamOutcomes ?? []).isEmpty }
            ? "\(gameWins(teams[0].esportsTeamId))–\(gameWins(teams[1].esportsTeamId))" : nil
        return HStack(spacing: 10) {
            Text("\(table)")
                .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(EventsTheme.textSecondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(names.enumerated()), id: \.offset) { i, name in
                    let winner = (match.teamOutcomes ?? []).contains { $0.esportsTeamId == teams[i].esportsTeamId && $0.isWin }
                    Text(name)
                        .font(.system(size: 14, weight: winner ? .semibold : .regular))
                        .foregroundStyle(winner ? EventsTheme.green : .white)
                }
            }
            Spacer()
            Text(score ?? (match.isComplete ? "done" : live ? "live" : "no result"))
                .font(.system(size: 13, weight: score == nil ? .regular : .bold, design: .rounded))
                .foregroundStyle(score == nil ? EventsTheme.textTertiary : .white)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(mine ? EventsTheme.greenSoft : EventsTheme.card,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(mine ? EventsTheme.green.opacity(0.5) : EventsTheme.hairline, lineWidth: 1))
    }

    private func byeRow(_ teamID: String) -> some View {
        HStack(spacing: 10) {
            Text("Bye").font(.system(size: 11, weight: .bold)).foregroundStyle(EventsTheme.textSecondary).frame(width: 28)
            Text(tournament.teamName(teamID)).font(.system(size: 14)).foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(teamID == myTeamID ? EventsTheme.greenSoft : EventsTheme.card,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
