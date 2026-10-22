//
//  EventSheets.swift
//  Riftbound Companiokay
//
//  Report result and "Can I draw?" (Android `EventSheets.kt`, classic `PlayRiftboundReportSheet` and the
//  standings outlook). The report has one row per game in play order, nothing after the deciding game, only
//  marked games are sent; the pairing is fetched again on open and right before sending.
//

import SwiftUI

struct RiftReportSheet: View {
    let target: ReportTarget
    let onToast: (String) -> Void
    let onReported: () -> Void
    @EnvironmentObject private var browser: PlayRiftboundBrowser
    @EnvironmentObject private var tournaments: RiftTournaments
    @Environment(\.dismiss) private var dismiss
    @State private var pairing: CompetePairing
    @State private var games: [Outcome?]
    @State private var stage: Stage = .pick
    @State private var error: String?

    enum Outcome { case me, draw, opponent }
    private enum Stage { case pick, confirm, sending }

    init(target: ReportTarget, onToast: @escaping (String) -> Void, onReported: @escaping () -> Void) {
        self.target = target
        self.onToast = onToast
        self.onReported = onReported
        _pairing = State(initialValue: target.pairing)
        _games = State(initialValue: Self.blank(target.pairing))
    }

    private static func blank(_ pairing: CompetePairing) -> [Outcome?] {
        Array(repeating: nil, count: max(1, min(pairing.bestOf, pairing.gameIDs.count)))
    }

    private var opponent: String { pairing.opponentName ?? "Opponent" }
    private var series: Bool { games.count > 1 }
    private var winsNeeded: Int { games.count / 2 + 1 }
    private var mine: Int { games.filter { $0 == .me }.count }
    private var theirs: Int { games.filter { $0 == .opponent }.count }
    private var draws: Int { games.filter { $0 == .draw }.count }

    /// The game that decided the series, nil while it is open.
    private var decided: Int? {
        guard series else { return nil }
        var me = 0
        var them = 0
        for (i, game) in games.enumerated() {
            switch game {
            case .me?: me += 1
            case .opponent?: them += 1
            case .draw?: break
            case nil: return nil
            }
            if me >= winsNeeded || them >= winsNeeded { return i }
        }
        return nil
    }

    private var summary: String {
        "You \(mine) – \(theirs) \(opponent)" + (draws > 0 ? " (\(draws) \(draws == 1 ? "draw" : "draws"))" : "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch stage {
            case .pick: pick
            case .confirm: confirm
            case .sending: sending
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(stage == .sending ? .hidden : .visible)
        // A result on its way is sent either way; the sheet stays until the answer is in.
        .interactiveDismissDisabled(stage == .sending)
        .task { _ = await refresh() }
    }

    private var pick: some View {
        let any = games.contains { $0 != nil }
        return VStack(alignment: .leading, spacing: 0) {
            Text("Report result").font(RiftFont.text(17, .bold)).foregroundStyle(.white)
            Text((series ? "Games (best of \(games.count))" : "Result (best of 1)") + " · \(pairing.roundTitle)" + (pairing.tableNumber.map { " · Table \($0)" } ?? ""))
                .font(RiftFont.text(13, .regular)).foregroundStyle(.white.opacity(0.72)).padding(.top, 6).padding(.bottom, 14)
            ForEach(games.indices, id: \.self) { i in gameRow(i) }
            SummaryBox(text: any ? "You report · \(summary)" : "Pick the result of each game")
            Text(error ?? (decided.map { $0 < games.count - 1 } == true
                           ? "Match is decided at \(winsNeeded) game wins. The remaining game is disabled."
                           : "Enter the games in the order you played them. Only the games you mark are sent."))
                .font(RiftFont.text(12, .regular))
                .lineSpacing(4)
                .foregroundStyle(error == nil ? .white.opacity(0.55) : RiftColor.danger)
                .padding(.bottom, 14)
            HStack(spacing: 8) {
                EvButton(text: "Cancel", kind: .ghost) { dismiss() }
                EvButton(text: "Submit", kind: .green, enabled: any && !pairing.isComplete) { stage = .confirm }
            }
        }
    }

    private func gameRow(_ i: Int) -> some View {
        let locked = (i > 0 && games[i - 1] == nil) || decided.map { i > $0 } == true
        return VStack(alignment: .leading, spacing: 8) {
            if series { Text("GAME \(i + 1)").caps(12, tracking: 0.06).foregroundStyle(.white.opacity(0.72)) }
            HStack(spacing: 6) {
                option("You", .me, i, color: RiftColor.you, locked: locked)
                option("Draw", .draw, i, color: .white, locked: locked)
                option(opponent, .opponent, i, color: RiftColor.opponent, locked: locked)
            }
        }
        .padding(.bottom, 12)
        .opacity(locked ? 0.35 : 1)
        .animation(.easeInOut(duration: 0.3), value: locked)
    }

    private func option(_ label: String, _ value: Outcome, _ i: Int, color: Color, locked: Bool) -> some View {
        let on = games[i] == value
        return Button {
            // Changing a game clears the ones after it: they belonged to another course of the series.
            games = games.enumerated().map { j, old in j < i ? old : j == i ? (on ? nil : value) : nil }
            Haptics.selection()
        } label: {
            Text(label)
                .font(RiftFont.text(14, .semibold))
                .foregroundStyle(on ? Color.black : .white)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(on ? color : .white.opacity(0.06), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(PressScale(scale: 0.96))
        .disabled(locked)
        .animation(.easeInOut(duration: 0.25), value: on)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var confirm: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Submit this result?").font(RiftFont.text(17, .bold)).foregroundStyle(.white)
            Text("This reports your \(pairing.roundTitle) result to PlayRiftbound. The organizer can still adjust it.")
                .font(RiftFont.text(13, .regular)).lineSpacing(4).foregroundStyle(.white.opacity(0.72)).padding(.top, 6).padding(.bottom, 14)
            SummaryBox(text: summary)
            HStack(spacing: 8) {
                EvButton(text: "Cancel", kind: .ghost) { stage = .pick }
                EvButton(text: "Submit", kind: .green, action: send)
            }
            .padding(.top, 8)
        }
    }

    private var sending: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Report result").font(RiftFont.text(17, .bold)).foregroundStyle(.white)
            SummaryBox(text: summary).padding(.top, 12)
            HStack(spacing: 10) {
                EvSpinner(size: 18)
                Text("Sending to PlayRiftbound").font(RiftFont.text(14, .semibold)).foregroundStyle(RiftColor.you)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
        }
    }

    /// False when the player's match changed under the open sheet: the marks are cleared.
    private func refresh() async -> Bool {
        guard let t = try? await tournaments.tournament(target.tournamentID, browser: browser, force: true),
              let me = tournaments.playerID(in: t),
              let fresh = CompetePairing.resolve(in: t, playerID: me) else { return true }
        let same = fresh.matchID == pairing.matchID && fresh.gameIDs == pairing.gameIDs
        if !same { games = Self.blank(fresh) }
        pairing = fresh
        return same
    }

    private func send() {
        stage = .sending
        error = nil
        Task {
            do {
                guard await refresh() else {
                    fail("Your pairing changed. Check the games and submit again.")
                    return
                }
                if pairing.isComplete {
                    onToast("Already reported on PlayRiftbound" + (pairing.scoreText.map { ": You \($0) \(opponent)" } ?? ""))
                    onReported()
                    dismiss()
                    return
                }
                guard let me = pairing.myParticipantID, let them = pairing.opponentParticipantID else {
                    fail("Couldn't find your match in the current round.")
                    return
                }
                let played = decided.map { Array(games.prefix($0 + 1)) } ?? games
                let results: [PlayRiftboundAPI.GameResult] = zip(pairing.gameIDs, played).compactMap { id, game in
                    switch game {
                    case .me?: return .init(gameId: id, draw: false, winnerParticipantId: me)
                    case .opponent?: return .init(gameId: id, draw: false, winnerParticipantId: them)
                    case .draw?: return .init(gameId: id, draw: true, winnerParticipantId: nil)
                    case nil: return nil
                    }
                }
                guard !results.isEmpty else {
                    fail("Mark at least one game.")
                    return
                }
                guard let credentials = try await PlayRiftboundSession.validCredentials(refreshingVia: browser) else {
                    throw PlayRiftboundError.notSignedIn
                }
                let api = PlayRiftboundAPI()
                do {
                    try await api.submitGameResults(tournamentID: target.tournamentID, games: results, credentials: credentials)
                } catch PlayRiftboundError.sessionExpired {
                    // The site renews its token on a page load; once, then again.
                    let renewed = try await PlayRiftboundSession.renewed(via: browser)
                    try await api.submitGameResults(tournamentID: target.tournamentID, games: results, credentials: renewed)
                }
                Haptics.success()
                onToast("Reported to PlayRiftbound · \(mine)–\(theirs)")
                _ = try? await tournaments.tournament(target.tournamentID, browser: browser, force: true)
                onReported()
                dismiss()
            } catch {
                fail((error as? LocalizedError)?.errorDescription ?? "Couldn't submit the result. Please try again.")
            }
        }
    }

    private func fail(_ message: String) {
        error = message
        stage = .pick
        Haptics.warning()
    }
}

private struct SummaryBox: View {
    let text: String

    var body: some View {
        Text(text)
            .font(RiftFont.text(14, .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
            .padding(.top, 4)
            .padding(.bottom, 6)
    }
}

/// "Can I draw?": the player picks the cut size (Riot's data has none); each line is the same result in every
/// match left. Open matches of the running round count as still to play.
struct DrawSheet: View {
    let tournament: CompeteTournament
    let myTeamID: String
    @State private var cut: Int?

    private struct Outlook {
        let cuts: [Int]
        let points: Int
        let left: Int
        let reported: Int
        let total: Int
        let roundNumber: Int
        let lines: (Int) -> (win: CutChance, draw: CutChance, lose: CutChance)
    }

    var body: some View {
        RiftSheet(title: "Can I draw?") {
            Text("Top cut math on the live round. Open matches count as still to play.")
                .font(RiftFont.text(13, .regular)).lineSpacing(4).foregroundStyle(.white.opacity(0.72)).padding(.bottom, 12)
            if let outlook = outlook(), let chosen = chosenCut(outlook.cuts) {
                Segmented(labels: outlook.cuts.map { "Top \($0)" }, selected: outlook.cuts.firstIndex(of: chosen) ?? 0, height: 42) { cut = outlook.cuts[$0] }
                Text("Top \(chosen) · \(outlook.left) \(outlook.left == 1 ? "match" : "matches") left · you have \(outlook.points) pts")
                    .font(RiftFont.text(13, .semibold)).foregroundStyle(.white.opacity(0.75)).padding(.top, 14).padding(.bottom, 6).padding(.leading, 2)
                let lines = outlook.lines(chosen)
                let suffix = outlook.left == 1 ? "" : " out"
                Verdict(label: "Win" + suffix, chance: lines.win)
                Verdict(label: "Draw" + suffix, chance: lines.draw)
                Verdict(label: "Lose" + suffix, chance: lines.lose)
                Text((outlook.reported < outlook.total
                      ? "Uses the \(outlook.reported) of \(outlook.total) results already reported in round \(outlook.roundNumber); open matches count as still to play. "
                      : "") + "“Locked in” is guaranteed regardless of other results. “Bubble” depends on other matches and tiebreakers.")
                    .font(RiftFont.text(12)).lineSpacing(4).foregroundStyle(.white.opacity(0.5)).padding(.top, 12)
            } else {
                Text("Nothing left to work out for you in this event.").font(RiftFont.text(13)).foregroundStyle(.white.opacity(0.72))
            }
        }
    }

    private func chosenCut(_ cuts: [Int]) -> Int? {
        if let cut, cuts.contains(cut) { return cut }
        return cuts.contains(8) ? 8 : cuts.last
    }

    private func outlook() -> Outlook? {
        let t = tournament
        guard let running = t.rounds.last, !t.isElimination(running) else { return nil }
        let table = CompeteStandings.compute(t, throughRound: running.roundNumber)
        let roundsAfter = max(0, t.plannedSwissRounds - running.roundNumber)
        func remaining(_ team: String) -> Int {
            let status = t.participant(teamID: team)?.status?.uppercased() ?? ""
            if status.contains("DROP") || status.contains("ELIM") { return 0 }
            return roundsAfter + (table.pending.contains(team) ? 1 : 0)
        }
        let cuts = [4, 8, 16].filter { $0 < table.rows.count }
        guard let mine = table.rows.first(where: { $0.esportsTeamId == myTeamID }), !cuts.isEmpty, remaining(myTeamID) >= 1 else { return nil }
        let points = mine.matchPoints ?? 0
        let left = remaining(myTeamID)
        let others = table.rows.filter { $0.esportsTeamId != myTeamID }.map { DrawContender(points: $0.matchPoints ?? 0, remaining: remaining($0.esportsTeamId)) }
        return Outlook(cuts: cuts, points: points, left: left, reported: table.reportedMatches, total: table.totalMatches, roundNumber: table.roundNumber) { cut in
            let o = DrawCalc.outlook(myPoints: points, myRemaining: left, others: others, cut: cut)
            return (o.win, o.draw, o.lose)
        }
    }
}

private struct Verdict: View {
    let label: String
    let chance: CutChance

    var body: some View {
        let (bg, ink, glow): (Color, Color, Color) = switch chance {
        case .locked: (RiftColor.you, .black, RiftColor.you.opacity(0.55))
        case .bubble: (RiftColor.gold, .black, RiftColor.gold.opacity(0.4))
        case .out: (.white.opacity(0.06), .white.opacity(0.7), .clear)
        }
        HStack {
            Text(label).font(RiftFont.text(16, .semibold)).foregroundStyle(.white)
            Spacer()
            Text(chance.label)
                .font(RiftFont.text(12.5, .bold))
                .foregroundStyle(ink)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(bg, in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(chance == .out ? .white.opacity(0.18) : bg, lineWidth: 1))
                .shadow(color: glow, radius: 8)
        }
        .frame(height: 56)
        .overlay(alignment: .bottom) { Hairline(opacity: 0.07) }
        .accessibilityElement(children: .combine)
    }
}
