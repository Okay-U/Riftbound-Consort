//
//  RedesignScoreView.swift
//  Riftbound Companiokay
//
//  The redesign's Score tab (Android `ScoreScreen.kt`, mock `ScoreFinal`): two halves face to face on
//  tinted territory fields whose glowing line leans toward the trailing player, or a 2×2 table for four.
//  The fields run under the status bar and the tab bar; the halves stay inside the safe area.
//

import SwiftUI

struct RedesignScoreView: View {
    @EnvironmentObject private var games: GameRecordStore
    @EnvironmentObject private var decks: DecklistStore
    @EnvironmentObject private var riftMatch: PlayRiftboundMatchStore
    @EnvironmentObject private var riftBrowser: PlayRiftboundBrowser
    @AppStorage("playerCount") private var playerCount = 2
    @AppStorage("matchModeEnabled") private var matchModeEnabled = true
    /// The seats' colours from Settings: read here so the board redraws after a pick.
    @AppStorage("colorIdx_0") private var color0 = -1
    @AppStorage("colorIdx_1") private var color1 = -1
    @AppStorage("colorIdx_2") private var color2 = -1
    @AppStorage("colorIdx_3") private var color3 = -1
    @Environment(\.riftPage) private var page
    @AppStorage("currentTab") private var currentTab = TabKey.score
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var c = ScoreController()
    @State private var askingEvent = false
    @State private var reporting: ReportTarget?

    /// Match mode's PlayRiftbound for the board; none with match mode off or four players.
    private var match: MatchInfo? {
        matchModeEnabled && c.state.isDuel ? MatchInfo(strip: riftMatch.current) : nil
    }

    var body: some View {
        GeometryReader { geo in
            let area = geo.size.height
            ZStack(alignment: .top) {
                if c.state.isDuel {
                    DuelBoard(
                        c: c, area: area, topInset: geo.safeAreaInsets.top, match: match,
                        checking: riftMatch.isRefreshing, onCheck: check,
                        onOpenEvent: match?.webURL == nil ? nil : { askingEvent = true },
                        onReport: { reporting = ReportTarget(tournamentID: $0.tournamentID, pairing: $0.pairing) }
                    )
                } else {
                    FourBoard(c: c, area: area)
                }
                // Centred on the seam like the mock, so it never covers a player's own controls.
                if let toast = c.toast {
                    HalfToast(text: toast.text)
                        .offset(y: area / 2 - 20)
                        .id(toast.id)
                        .task(id: toast.id) {
                            try? await Task.sleep(for: .seconds(2.2))
                            c.clearToast(toast.id)
                        }
                }
            }
            .frame(width: geo.size.width, height: area, alignment: .top)
        }
        .background(page.ignoresSafeArea())
        .statusBarHidden()
        .confirmationDialog(c.state.isDuel ? "End or restart this game?" : "Restart this game?", isPresented: $c.gameMenu, titleVisibility: .visible) {
            if c.state.isDuel {
                Button("I won") { c.end(winner: Seat.you) }
                Button("I lost") { c.end(winner: Seat.opponent) }
            }
            Button("Restart this game", role: .destructive) { c.restart() }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text(c.state.isDuel
                 ? "Won or lost ends the game as it stands, for a concession or points the board missed. Restart sets both scores and XP back to 0, and Undo brings them back."
                 : "All scores and XP go back to 0, and Undo brings them back.")
        }
        .alert("Open the event?", isPresented: $askingEvent) {
            Button("Stay here", role: .cancel) {}
            Button("Open event") {
                if let id = match?.tournamentID { riftBrowser.openEvent(id) } else if let url = match?.webURL { riftBrowser.open(url) }
            }
        } message: {
            Text("\(match?.event ?? "The event") opens in Events. Your scoreboard stays as it is.")
        }
        .sheet(item: $c.setup) { sheet in
            switch sheet {
            case .deck: DeckPickSheet(c: c)
            case .opponent: OpponentPickSheet(c: c)
            }
        }
        // The Events report sheet: the same picks, checks and confirmation as from the event.
        .sheet(item: $reporting) { target in
            RiftReportSheet(target: target, onToast: c.show) { refresh(force: true) }
        }
        .onAppear { c.attach(games: games, decks: decks) }
        .onChange(of: playerCount, initial: true) { _, count in c.setPlayers(count) }
        // The pairing is asked for when the board shows (pairings go up between rounds), not on a timer.
        .task { refresh(force: false) }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh(force: false) } }
        .onChange(of: currentTab) { _, tab in if tab == TabKey.score { refresh(force: false) } }
    }

    private func refresh(force: Bool) {
        guard matchModeEnabled, c.state.isDuel else { return }
        Task { await riftMatch.refresh(browser: riftBrowser, force: force) }
    }

    /// The trophy: asks PlayRiftbound now and says what came back.
    private func check() {
        Task {
            await riftMatch.refresh(browser: riftBrowser, force: true)
            c.show(MatchInfo.checked(riftMatch))
        }
    }
}

/// "You have", "Lee Sin has": the score labels VoiceOver reads.
private func haves(_ name: String) -> String { name == "You" ? "You have" : "\(name) has" }

// MARK: - Two players

private struct DuelBoard: View {
    @ObservedObject var c: ScoreController
    let area: CGFloat
    let topInset: CGFloat
    let match: MatchInfo?
    let checking: Bool
    let onCheck: () -> Void
    let onOpenEvent: (() -> Void)?
    let onReport: (TableLink) -> Void

    var body: some View {
        let s = c.state
        let roll = c.firstRoll
        let colors = PlayerSwatches.colors(players: 2)
        let center = area / 2
        let leader: Int = {
            if let roll { return roll.winner }
            if s.players[Seat.you].score > s.players[Seat.opponent].score { return Seat.you }
            if s.players[Seat.opponent].score > s.players[Seat.you].score { return Seat.opponent }
            return -1
        }()
        ZStack(alignment: .top) {
            TerritoryFields(
                line: lineTarget(s, roll, center: center) + topInset,
                colors: colors,
                lineColor: leader < 0 ? .white.opacity(0.7) : colors[leader]
            )
            .ignoresSafeArea()
            VStack(spacing: 0) {
                Half(c: c, slot: Seat.opponent, colors: colors).rotationEffect(.degrees(180))
                Half(c: c, slot: Seat.you, colors: colors)
            }
            .frame(height: area)
            Seam(c: c, match: match, checking: checking, onCheck: onCheck, onOpenEvent: onOpenEvent, onReport: onReport)
                .padding(.horizontal, 10)
                .offset(y: center - 27)
        }
    }

    /// Where the line sits: toward the trailing player by 26pt per point, swept to the loser on a win.
    private func lineTarget(_ s: ScoreState, _ roll: FirstRoll?, center: CGFloat) -> CGFloat {
        if let roll {
            if roll.winner == Seat.you { return 210 }
            if roll.winner == Seat.opponent { return area - 210 }
            return center
        }
        if s.gameOver { return s.winner == Seat.you ? 64 : area - 64 }
        let leaning = center + 26 * CGFloat(s.players[Seat.opponent].score - s.players[Seat.you].score)
        return min(max(leaning, 130), max(130, area - 130))
    }
}

/// The two tinted fields and the glowing boundary; each field is one screen tall and only moves.
private struct TerritoryFields: View {
    /// From the top of the screen.
    let line: CGFloat
    let colors: [Color]
    let lineColor: Color

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            ZStack(alignment: .top) {
                Rectangle().fill(colors[Seat.opponent].opacity(0.13)).frame(height: height).offset(y: line - height)
                Rectangle().fill(colors[Seat.you].opacity(0.13)).frame(height: height).offset(y: line)
                Rectangle().fill(lineColor).frame(height: 10).blur(radius: 12).offset(y: line - 5)
                Rectangle().fill(lineColor).frame(height: 2).offset(y: line - 1)
            }
            .frame(width: geo.size.width, height: height, alignment: .top)
        }
        .allowsHitTesting(false)
        .animation(.rift(1.1), value: line)
        .animation(.easeInOut(duration: 0.6), value: lineColor)
    }
}

private struct Half: View {
    @ObservedObject var c: ScoreController
    let slot: Int
    let colors: [Color]

    var body: some View {
        let s = c.state
        let roll = c.firstRoll
        let accent = colors[slot]
        let dim = roll.map { $0.winner >= 0 && $0.winner != slot } ?? (s.gameOver && s.winner != slot)
        ZStack(alignment: .top) {
            // Stacked, not in a column: while they swap, the score and the roll share the half.
            ZStack {
                if let roll {
                    DuelSide(c: c, roll: roll, slot: slot, accent: accent)
                        .transition(.halfSwap)
                } else {
                    VStack(spacing: 0) {
                        TopLine(
                            legend: c.legend(slot), accent: accent, starter: s.starter == slot, xp: s.players[slot].xp,
                            onXp: { c.xp(slot, $0) }, shown: !s.gameOver, onName: { c.openSetup(slot) }
                        )
                        GeometryReader { box in
                            ScoreNumber(
                                value: s.players[slot].score, accent: accent, won: s.winner == slot,
                                label: "\(haves(c.shortName(slot))) \(s.players[slot].score) of \(ScoreState.target) points",
                                size: max(40, min(188, box.size.height / 1.1, box.size.width / 1.38))
                            )
                            .frame(width: box.size.width, height: box.size.height)
                        }
                        bottomRow(s, accent: accent)
                    }
                    .transition(.halfSwap)
                }
            }
            .animation(.rift(0.7), value: roll != nil)
            .padding(.horizontal, 20)
            .padding(.top, 34)
            .padding(.bottom, 18)
            .opacity(dim ? 0.32 : 1)
            .animation(.rift(0.9), value: dim)

            if roll == nil && s.winner == slot {
                ResultText(title: "WIN", sub: "\(s.players[slot].score)–\(s.players[1 - slot].score)", accent: accent).padding(.top, 80)
            }
            if c.drew == slot {
                HalfToast(text: "No point · draw a card instead").padding(.top, 70)
            }
            Group {
                if roll == nil && s.asking == slot {
                    HalfQuestion.finalPoint(accent: accent, onYes: { c.finalPoint(true) }, onNo: { c.finalPoint(false) })
                } else if roll == nil && c.startChooser == slot && !s.gameOver {
                    HalfQuestion.startChoice(accent: accent, onFirst: { c.pickStart(first: true) }, onSecond: { c.pickStart(first: false) })
                }
            }
            .padding(12)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private func bottomRow(_ s: ScoreState, accent: Color) -> some View {
        if !s.gameOver {
            ActionRow(
                accent: accent,
                onConquer: { c.score(slot, .conquer) }, onHold: { c.score(slot, .hold) },
                onEffect: { c.score(slot, .effect) }, onFix: { c.fix(slot) }
            )
        } else if s.winner == slot {
            NextGameButton(text: "Next game", accent: accent) { c.nextGame() }
        } else {
            Color.clear.frame(height: 54)
        }
    }
}

private struct DuelSide: View {
    @ObservedObject var c: ScoreController
    let roll: FirstRoll
    let slot: Int
    let accent: Color
    var dieSize: CGFloat = 190

    var body: some View {
        let die = roll.dice[slot]
        let won = roll.winner == slot
        let lost = roll.winner >= 0 && !won
        let pair = roll.dice.count == 2
        let others = pair ? c.shortName(1 - slot) : "the others"
        let hint: String? = {
            if won || roll.tie || (lost && !pair) { return nil }
            if die.rolling { return "Rolling" }
            if die.value == nil { return pair ? "Tap your half to roll" : "Tap your side to roll" }
            if roll.winner < 0 { return "Waiting for \(others)" }
            return lost ? "\(others) rolled higher" : nil
        }()
        let head: String? = roll.tie ? "Tie · roll again" : won ? "Higher roll" : nil
        let short = c.shortName(slot)
        DuelHalf(
            name: slot == Seat.you && pair && short != "You" ? "\(short) · you" : short,
            kind: roll.kind, die: die, accent: accent, hint: hint, head: head,
            headInk: roll.tie ? .white : accent, choosing: won && pair, highlight: won, dieSize: dieSize,
            onRoll: { c.roll(slot) }, onFirst: { c.choose(.first) }, onSecond: { c.choose(.second) }
        )
    }
}

// MARK: - Four players

/// Four players (no mock): a 2×2 table, the far side turned around, every corner in its own colour.
private struct FourBoard: View {
    @ObservedObject var c: ScoreController
    let area: CGFloat

    var body: some View {
        let s = c.state
        let roll = c.firstRoll
        let colors = PlayerSwatches.colors(players: 4)
        let top = s.players.map(\.score).max() ?? 0
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                ForEach(0..<2, id: \.self) { row in
                    // The far row is turned as a whole, so its seats keep their places for the players across.
                    HStack(spacing: 0) {
                        ForEach(row == 0 ? [1, 0] : [2, 3], id: \.self) { slot in
                            seat(slot, s: s, roll: roll, accent: colors[slot], leading: top > 0 && s.players[slot].score == top)
                        }
                    }
                    .rotationEffect(.degrees(row == 0 ? 180 : 0))
                }
            }
            .frame(height: area)
            Rectangle().fill(.white.opacity(0.08)).frame(width: 1, height: area)
            Seam(c: c).offset(y: area / 2 - 27)
            if let roll, roll.winner >= 0 {
                let starter = roll.starter()
                DuelBanner(
                    title: "\(c.shortName(starter)) starts",
                    text: "\(c.shortName(starter)) rolled \(roll.dice[starter].value ?? 0) on the \(roll.kind.label), the highest roll at the table.",
                    accent: colors[starter], onAgain: { c.rollAgain() }, onStart: { c.startGame() }
                )
                .padding(.horizontal, 16)
                .offset(y: area / 2 - 80)
            }
        }
    }

    private func seat(_ slot: Int, s: ScoreState, roll: FirstRoll?, accent: Color, leading: Bool) -> some View {
        let lost = roll.map { $0.winner >= 0 && $0.winner != slot } ?? false
        return ZStack {
            if let roll {
                DuelSide(c: c, roll: roll, slot: slot, accent: accent, dieSize: 110)
                    .transition(.halfSwap)
            } else {
                VStack(spacing: 0) {
                    TopLine(legend: c.legend(slot), accent: accent, starter: s.starter == slot, xp: s.players[slot].xp, onXp: { c.xp(slot, $0) })
                    GeometryReader { box in
                        let n = s.players[slot].score
                        ScoreNumber(
                            value: n, accent: accent, won: false,
                            label: "\(haves(c.legend(slot))) \(n) \(n == 1 ? "point" : "points")",
                            showTarget: false, size: max(32, min(112, box.size.height / 1.1, box.size.width / 1.38))
                        )
                        .frame(width: box.size.width, height: box.size.height)
                    }
                    ActionGrid(
                        accent: accent,
                        onConquer: { c.score(slot, .conquer) }, onHold: { c.score(slot, .hold) },
                        onEffect: { c.score(slot, .effect) }, onFix: { c.fix(slot) }
                    )
                }
                .transition(.halfSwap)
            }
        }
        .animation(.rift(0.7), value: roll != nil)
        .padding(.horizontal, 12)
        .padding(.top, 22)
        .padding(.bottom, 14)
        .opacity(lost ? 0.32 : 1)
        .animation(.rift(0.9), value: lost)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(accent.opacity(leading ? 0.2 : 0.09))
        .animation(.easeInOut(duration: 0.6), value: leading)
    }
}
