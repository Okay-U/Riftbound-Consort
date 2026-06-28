//
//  ScoreboardView.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 02.11.25.
//

import SwiftUI

struct ScoreboardView: View {
    @EnvironmentObject var vm: ScoreboardViewModel
    @EnvironmentObject var gameTimer: GameTimer
    @EnvironmentObject var decklistStore: DecklistStore
    @EnvironmentObject var cardStore: CardStore
    @EnvironmentObject var gameRecordStore: GameRecordStore
    @EnvironmentObject var matchMode: MatchModeStore
    @EnvironmentObject var session: AuthSession
    @AppStorage("trueBlack") private var trueBlack: Bool = true
    @AppStorage("activeDeckId")   private var activeDeckId: String = ""
    @AppStorage("activeOpponent") private var activeOpponent: String = ""
    @AppStorage("activeStartedFirst") private var activeStartedFirst: String = ""
    @State private var showColorSheet = false
    @State private var showQuickSettingsSheet = false
    @State private var showGameSetupSheet = false
    @State private var lastGameEnd: TimeInterval = 0
    @State private var xpModeAll: Bool = false
    @State private var perSlotXP: [Bool] = [false, false, false, false]
    @AppStorage("liveActivityEnabled") private var liveActivityEnabled: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var liveActivityDebounce: Task<Void, Never>?
    @State private var reportingMatch: ResolvedMyMatch?

    private let outerVSpacing: CGFloat = 12
    private let gridSpacing: CGFloat = 12
    private let horizPad: CGFloat = 12

    var body: some View {
        ZStack {
            (trueBlack ? Color.black : Color(.systemBackground)).ignoresSafeArea()

            VStack(spacing: outerVSpacing) {
                VStack(spacing: 8) {
                    headerBar

                    if showMatchStrip, let active = matchMode.active {
                        matchStrip(active)
                            .padding(.horizontal, 16)
                    }
                }

                GeometryReader { geo in
                    let availableH = geo.size.height

                    if vm.playerCount == 2 {
                        let tileH = (availableH - gridSpacing) / 2
                        VStack(spacing: gridSpacing) {
                            tileFor(slot: 0, rotation: 180)
                                .frame(maxWidth: .infinity, minHeight: tileH)
                            tileFor(slot: 1, rotation: 0)
                                .frame(maxWidth: .infinity, minHeight: tileH)
                        }
                        .padding(.horizontal, horizPad)
                    } else {
                        let columns = [GridItem(.flexible(), spacing: gridSpacing),
                                       GridItem(.flexible(), spacing: gridSpacing)]
                        let tileH = (availableH - gridSpacing) / 2

                        LazyVGrid(columns: columns, spacing: gridSpacing) {
                            tileFor(slot: 0, rotation: 180)
                                .frame(minHeight: tileH)
                            tileFor(slot: 1, rotation: 180)
                                .frame(minHeight: tileH)
                            tileFor(slot: 2, rotation: 0)
                                .frame(minHeight: tileH)
                            tileFor(slot: 3, rotation: 0)
                                .frame(minHeight: tileH)
                        }
                        .padding(.horizontal, horizPad)
                    }
                }

                footerBar
            }
            .padding(.vertical, outerVSpacing)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showColorSheet) {
            ColorSettingsSheet(visibleSlots: visibleSlots(), showSheet: $showColorSheet)
                .environmentObject(vm)
        }
        .sheet(isPresented: $showQuickSettingsSheet) {
            QuickSettingsSheet()
                .environmentObject(vm)
        }
        .sheet(isPresented: $showGameSetupSheet) {
            GameSetupSheet()
                .environmentObject(decklistStore)
                .environmentObject(cardStore)
        }
        .sheet(item: $reportingMatch) { match in
            ReportResultSheet(match: match,
                              isBestOfThree: matchMode.active?.isBestOfThree ?? true,
                              token: session.token ?? "",
                              onReported: { Task { await matchMode.refresh(session: session) } })
        }
        .task { await matchMode.refresh(session: session) }
        .onChange(of: gameTimer.isRunning, initial: false) { _, _ in
            syncLiveActivity()
        }
        .onChange(of: vm.players.map(\.score), initial: false) { _, _ in
            syncLiveActivity()
        }
        .onChange(of: activeDeckId, initial: true) { _, _ in
            SharedScoreboard.writeDeckNames(my: currentDeckName(), opp: currentOpponent())
            syncLiveActivity()
        }
        .onChange(of: activeOpponent, initial: true) { _, _ in
            SharedScoreboard.writeDeckNames(my: currentDeckName(), opp: currentOpponent())
            syncLiveActivity()
        }
        .onChange(of: scenePhase, initial: false) { _, phase in
            if phase == .active {
                vm.adoptSharedScoresIfAvailable()
                syncLiveActivity()
                Task { await matchMode.refresh(session: session) }
            }
        }
        .onChange(of: liveActivityEnabled, initial: false) { _, _ in
            syncLiveActivity()
        }
        .onChange(of: vm.playerCount, initial: false) { _, _ in
            // Reset XP mode tracking when player count changes — stale per-slot
            // entries from removed slots would otherwise drive future tile state.
            perSlotXP = [false, false, false, false]
            xpModeAll = false
            syncLiveActivity()
        }
    }

    private var activeDeckName: String {
        guard
            let uuid = UUID(uuidString: activeDeckId),
            let deck = decklistStore.lists.first(where: { $0.id == uuid })
        else { return "No deck" }
        return deck.name
    }

    private func activeDeck() -> Decklist? {
        guard let uuid = UUID(uuidString: activeDeckId) else { return nil }
        return decklistStore.lists.first(where: { $0.id == uuid })
    }

    private func endGame(_ result: GameResult) {
        let deck = activeDeck()
        let opponent = activeOpponent.trimmingCharacters(in: .whitespaces)
        let now = gameTimer.elapsed
        // If timer was manually reset since last record, fall back to full elapsed.
        let delta = now >= lastGameEnd ? now - lastGameEnd : now
        let startedFirst: Bool? = activeStartedFirst == "first" ? true
            : activeStartedFirst == "second" ? false
            : nil
        let record = GameRecord(
            deckId: deck?.id,
            deckName: deck?.name,
            opponent: opponent,
            result: result,
            durationSeconds: Int(delta),
            events: vm.events,
            startedFirst: startedFirst
        )
        gameRecordStore.record(record)
        lastGameEnd = now
        vm.resetScores()
        GameActivityController.shared.end()
    }

    private func currentDeckName() -> String? {
        activeDeck()?.name
    }

    private func currentOpponent() -> String? {
        let s = activeOpponent.trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? nil : s
    }

    private func syncLiveActivity() {
        liveActivityDebounce?.cancel()
        liveActivityDebounce = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            if Task.isCancelled { return }
            performLiveActivitySync()
        }
    }

    private func performLiveActivitySync() {
        guard liveActivityEnabled, vm.playerCount == 2 else {
            if GameActivityController.shared.isActive {
                GameActivityController.shared.end()
            }
            return
        }
        let scores = vm.players.map(\.score)
        let running = gameTimer.isRunning
        let elapsed = gameTimer.elapsed
        let effective: Date? = running ? Date().addingTimeInterval(-elapsed) : nil

        if GameActivityController.shared.isActive {
            GameActivityController.shared.update(
                scores: scores,
                effectiveStart: .some(effective),
                pausedElapsed: elapsed,
                myDeck: .some(currentDeckName()),
                oppDeck: .some(currentOpponent())
            )
        } else if running {
            GameActivityController.shared.start(
                playerCount: vm.playerCount,
                targetScore: 8,
                scores: scores,
                effectiveStart: effective,
                pausedElapsed: elapsed,
                myDeck: currentDeckName(),
                oppDeck: currentOpponent()
            )
        }
    }

    private func visibleSlots() -> [Int] {
        vm.playerCount == 2 ? [0, 1] : [0, 1, 2, 3]
    }

    // MARK: - Match mode strip

    private var showMatchStrip: Bool {
        matchMode.enabled && matchMode.active != nil && vm.playerCount == 2
    }

    @ViewBuilder
    private func matchStrip(_ active: ActiveTournamentMatch) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                    Text("Table \(active.tableNumber.map(String.init) ?? "—")"
                         + (active.roundLabel.map { " · \($0)" } ?? ""))
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(EventsTheme.green)

                Text("\(active.myName)  vs  \(active.opponentName ?? "TBD")")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(EventsTheme.textPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if active.isComplete {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Reported")
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(EventsTheme.greenSoft, in: Capsule())
                .foregroundStyle(EventsTheme.green)
            } else if active.isReportable {
                Button { reportingMatch = active.match } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.pencil")
                        Text("Report")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(EventsTheme.matchFillBottom)
                    .padding(.horizontal, 14).frame(height: 38)
                    .background(EventsTheme.green, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .greenGradientBorder(radius: EventsTheme.pillRadius)
    }

    private func syncToggleFromTiles() {
        let states = visibleSlots().map { perSlotXP[$0] }
        if states.allSatisfy({ $0 }) {
            xpModeAll = true
        } else if states.allSatisfy({ !$0 }) {
            xpModeAll = false
        }
        // mixed states: leave xpModeAll unchanged
    }

    private func tileFor(slot: Int, rotation: Double) -> some View {
        let p = vm.players[slot]
        let idx = vm.colorIndex(for: slot)
        let fill: Color? = (idx >= 0) ? Palette.colors[idx % Palette.colors.count] : nil

        return ScoreTile(
            player: p,
            onConquer: {
                vm.recordEvent(p, type: .conquer, delta: 1, elapsedSeconds: Int(gameTimer.elapsed))
            },
            onHold: {
                vm.recordEvent(p, type: .hold, delta: 1, elapsedSeconds: Int(gameTimer.elapsed))
            },
            onDecrement: {
                vm.recordEvent(p, type: .manual, delta: -1, elapsedSeconds: Int(gameTimer.elapsed))
            },
            rotation: rotation,
            color: fill,
            onXPIncrement: { vm.incrementXP(p) },
            onXPDecrement: { vm.decrementXP(p) },
            desiredXPMode: xpModeAll,
            onModeChange: { isXP in
                perSlotXP[slot] = isXP
                syncToggleFromTiles()
            }
        )
        .contextMenu {
            Button("Default") { vm.setColorIndex(-1, for: slot) }
            Divider()
            ForEach(Array(Palette.colors.enumerated()), id: \.0) { pair in
                let index = pair.0
                let color = pair.1
                Button {
                    vm.setColorIndex(index, for: slot)
                } label: {
                    HStack {
                        Circle()
                            .fill(color)
                            .frame(width: 18, height: 18)
                        Text(Palette.name(for: index))
                    }
                }
            }
        }
    }

    private var headerBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Scoreboard")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                TimerBadgeView()
                deckPill
            }
            Spacer()
            Button { xpModeAll.toggle() } label: {
                Text("XP")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.bordered)
            .tint(xpModeAll ? .yellow : nil)
            .accessibilityLabel(xpModeAll ? "Switch all tiles to score" : "Switch all tiles to XP")

            Button { vm.resetScores() } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Reset scores")
        }
        .padding(.horizontal, 16)
    }

    private var deckPill: some View {
        Button {
            showGameSetupSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.stack")
                    .font(.caption)
                Text(activeDeckName)
                    .font(.caption.weight(.medium))
                if !activeOpponent.isEmpty {
                    Text("vs \(activeOpponent)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(Color.secondary.opacity(0.18))
            )
        }
        .buttonStyle(.plain)
    }

    private var footerBar: some View {
        HStack(spacing: 12) {
            Button { vm.undo() } label: {
                Label("", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.bordered)

            Button { showColorSheet = true } label: {
                Label("", systemImage: "paintpalette")
            }
            .buttonStyle(.bordered)

            Button { showQuickSettingsSheet = true } label: {
                Image(systemName: "person.2.fill")
            }
            .buttonStyle(.bordered)

            Spacer()

            Button { endGame(.lost) } label: {
                Text("Lost")
                    .font(.headline)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.bordered)

            Button { endGame(.won) } label: {
                Text("Won")
                    .font(.headline)
                    .foregroundStyle(.green)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
    }
}
