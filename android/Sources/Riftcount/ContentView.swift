import SwiftUI

/// Root tab host. Tab icons: custom symbolset SVGs bundled in
/// Module.xcassets (tab.*.fill — Image(systemName:) resolves bundled
/// symbol assets before the built-in map), plus mapped trophy/gear.
struct ContentView: View {
    @AppStorage("currentTab") var currentTab: String = "score"
    @AppStorage("didOnboard") var didOnboard: Bool = false
    @State var decklistStore = DecklistStore()
    @State var cardStore = CardStore()
    @State var gameRecordStore = GameRecordStore()
    @State var gameTimer = GameTimer()
    @State var authSession = AuthSession()
    @State var matchMode = MatchModeStore()

    var body: some View {
        TabView(selection: $currentTab) {
            ScoreboardScreen()
                .tabItem { Label("Score", systemImage: "tab.score.fill") }
                .tag("score")

            EventsTabView()
                .tabItem { Label("Events", systemImage: "tab.events.fill") }
                .tag("events")

            DiceScreen()
                .tabItem { Label("Dice", systemImage: "tab.dice.fill") }
                .tag("dice")

            CardsScreen()
                .tabItem { Label("Cards", systemImage: "tab.cards.fill") }
                .tag("cards")

            DecksScreen()
                .tabItem { Label("Decks", systemImage: "tab.decks.fill") }
                .tag("decks")

            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag("settings")
        }
        // App accent (icon teal). On the tab bar this softens the Material
        // selection pill from gray to a subtle brand tint.
        .tint(Color(red: 0.36, green: 0.78, blue: 0.76))
        .environment(decklistStore)
        .environment(cardStore)
        .environment(gameRecordStore)
        .environment(gameTimer)
        .environment(authSession)
        .environment(matchMode)
        .task { await authSession.restore() }
        .fullScreenCover(isPresented: Binding(
            get: { !didOnboard },
            set: { newValue in if !newValue { didOnboard = true } }
        )) {
            OnboardingView()
        }
        .preferredColorScheme(.dark)
        #if os(Android)
        // Imperative Haptics calls bump HapticsEngine counters; these
        // modifiers translate counter changes into Vibrator feedback.
        .sensoryFeedback(.impact, trigger: HapticsEngine.shared.impactCount)
        .sensoryFeedback(.selection, trigger: HapticsEngine.shared.selectionCount)
        .sensoryFeedback(.warning, trigger: HapticsEngine.shared.warningCount)
        .sensoryFeedback(.success, trigger: HapticsEngine.shared.successCount)
        #endif
    }
}

/// Scoreboard host, ported from the iOS ScoreboardView: 2p/4p layouts,
/// header (title/timer/deck pill/XP/reset), tournament match strip,
/// footer (undo, colors, quick settings, Won/Lost game records).
struct ScoreboardScreen: View {
    @Environment(GameTimer.self) var gameTimer
    @Environment(GameRecordStore.self) var gameRecordStore
    @Environment(DecklistStore.self) var decklistStore
    @Environment(MatchModeStore.self) var matchMode
    @Environment(AuthSession.self) var session
    @State var viewModel = ScoreboardViewModel()
    @State var reportingMatch: ResolvedMyMatch?
    @State var showReport = false
    @AppStorage("currentTab") var currentTab: String = "score"
    @State var xpModeAll = false
    @State var perSlotXP: [Bool] = [false, false, false, false]
    @State var showColorSheet = false
    @State var showQuickSettingsSheet = false
    @State var showGameSetupSheet = false
    @State var lastGameEnd: TimeInterval = 0
    @AppStorage("activeDeckId") var activeDeckId: String = ""
    @AppStorage("activeOpponent") var activeOpponent: String = ""
    @AppStorage("activeStartedFirst") var activeStartedFirst: String = ""

    private let outerVSpacing: CGFloat = 12
    private let gridSpacing: CGFloat = 12
    private let horizPad: CGFloat = 12

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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

                    if viewModel.playerCount == 2 {
                        let tileH = (availableH - gridSpacing) / 2
                        VStack(spacing: gridSpacing) {
                            tileFor(slot: 0, rotation: 180)
                                .frame(maxWidth: .infinity, minHeight: tileH)
                            tileFor(slot: 1, rotation: 0)
                                .frame(maxWidth: .infinity, minHeight: tileH)
                        }
                        .padding(.horizontal, horizPad)
                    } else {
                        // Plain stacks instead of LazyVGrid: only 4 tiles, and
                        // LazyVGrid renders blank inside a fixed-height
                        // GeometryReader on Compose.
                        let tileH = (availableH - gridSpacing) / 2
                        VStack(spacing: gridSpacing) {
                            HStack(spacing: gridSpacing) {
                                tileFor(slot: 0, rotation: 180)
                                tileFor(slot: 1, rotation: 180)
                            }
                            .frame(height: tileH)
                            HStack(spacing: gridSpacing) {
                                tileFor(slot: 2, rotation: 0)
                                tileFor(slot: 3, rotation: 0)
                            }
                            .frame(height: tileH)
                        }
                        .padding(.horizontal, horizPad)
                    }
                }

                footerBar
            }
            .padding(.vertical, outerVSpacing)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showColorSheet) {
            ColorSettingsSheet(vm: viewModel,
                               visibleSlots: visibleSlots(),
                               showSheet: $showColorSheet)
        }
        .sheet(isPresented: $showQuickSettingsSheet) {
            QuickSettingsSheet(vm: viewModel)
        }
        .sheet(isPresented: $showGameSetupSheet) {
            GameSetupSheet()
        }
        .sheet(isPresented: $showReport) {
            if let reportingMatch {
                ReportResultSheet(match: reportingMatch,
                                  isBestOfThree: matchMode.active?.isBestOfThree ?? true,
                                  token: session.token ?? "",
                                  onReported: { Task { await matchMode.refresh(session: session) } })
            }
        }
        .task { await matchMode.refresh(session: session) }
        .onChange(of: currentTab) { (_: String, tab: String) in
            // Returning to the Scoreboard mid-tournament: re-pull the live
            // match so the strip isn't stale (the tab keeps this view alive,
            // so .task won't refire).
            if tab == "score" {
                Task { await matchMode.refresh(session: session) }
            }
        }
        .onChange(of: viewModel.playerCount) { (_: Int, _: Int) in
            // Reset XP mode tracking when player count changes — stale per-slot
            // entries from removed slots would otherwise drive future tile state.
            perSlotXP = [false, false, false, false]
            xpModeAll = false
        }
    }

    private func visibleSlots() -> [Int] {
        viewModel.playerCount == 2 ? [0, 1] : [0, 1, 2, 3]
    }

    // MARK: - Match mode strip

    private var showMatchStrip: Bool {
        matchMode.enabled && matchMode.active != nil && viewModel.playerCount == 2
    }

    /// Slim tournament strip under the header, ported from iOS: table/round,
    /// you vs opponent, Report (or Reported), dismiss. Icons swapped for
    /// SkipUI-mapped symbols (trophy.fill/square.and.pencil/checkmark.seal.fill
    /// aren't in the map).
    private func matchStrip(_ active: ActiveTournamentMatch) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
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
                    Image(systemName: "checkmark.circle.fill")
                    Text("Reported")
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(EventsTheme.greenSoft))
                .foregroundStyle(EventsTheme.green)
            } else if active.isReportable {
                Button {
                    reportingMatch = active.match
                    showReport = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "pencil")
                        Text("Report")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(EventsTheme.matchFillBottom)
                    .padding(.horizontal, 14).frame(height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(EventsTheme.green)
                    )
                }
                .buttonStyle(.plain)
            }

            Button { matchMode.dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(EventsTheme.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(EventsTheme.cardInset))
            }
            .buttonStyle(.plain)
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
        let p = viewModel.players[slot]
        let elapsed = Int(gameTimer.elapsed)

        return ScoreTile(
            player: p,
            onConquer: {
                viewModel.recordEvent(p, type: .conquer, delta: 1, elapsedSeconds: elapsed)
            },
            onHold: {
                viewModel.recordEvent(p, type: .hold, delta: 1, elapsedSeconds: elapsed)
            },
            onDecrement: {
                viewModel.recordEvent(p, type: .manual, delta: -1, elapsedSeconds: elapsed)
            },
            rotation: rotation,
            paletteColor: viewModel.paletteColor(for: slot),
            onXPIncrement: { viewModel.incrementXP(p) },
            onXPDecrement: { viewModel.decrementXP(p) },
            desiredXPMode: xpModeAll,
            onModeChange: { isXP in
                perSlotXP[slot] = isXP
                syncToggleFromTiles()
            }
        )
        .contextMenu {
            Button("Default") { viewModel.setColorIndex(-1, for: slot) }
            ForEach(Array(Palette.colors.enumerated()), id: \.0) { pair in
                Button(pair.1.name) {
                    viewModel.setColorIndex(pair.0, for: slot)
                }
            }
        }
    }

    /// Round control button. SkipUI's .bordered pills looked off on Android;
    /// plain circles are consistent on both platforms.
    private func circleButton(tint: Color = .primary,
                              disabled: Bool = false,
                              action: @escaping () -> Void,
                              @ViewBuilder label: () -> some View) -> some View {
        Button(action: action) {
            label()
                .foregroundStyle(disabled ? Color.secondary : tint)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.10)))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    /// Palette glyph drawn as color dots (paintpalette is not in SkipUI's
    /// symbol map).
    private var paletteGlyph: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Circle().fill(Color.red).frame(width: 8, height: 8)
                Circle().fill(Color.yellow).frame(width: 8, height: 8)
            }
            HStack(spacing: 3) {
                Circle().fill(Color.green).frame(width: 8, height: 8)
                Circle().fill(Color.blue).frame(width: 8, height: 8)
            }
        }
    }

    private var activeDeckName: String {
        guard
            let uuid = UUID(uuidString: activeDeckId),
            let deck = decklistStore.lists.first(where: { $0.id == uuid })
        else { return "No deck" }
        return deck.name
    }

    private func endGame(_ result: GameResult) {
        let deckUUID = UUID(uuidString: activeDeckId)
        let deck = decklistStore.lists.first(where: { $0.id == deckUUID })
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
            events: viewModel.events,
            startedFirst: startedFirst
        )
        gameRecordStore.record(record)
        lastGameEnd = now
        viewModel.resetScores()
    }

    private var deckPill: some View {
        Button {
            showGameSetupSheet = true
        } label: {
            HStack(spacing: 6) {
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

    private var headerBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Scoreboard")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                TimerBadgeView()
                deckPill
            }

            Spacer()

            circleButton(tint: xpModeAll ? Color(red: 0.98, green: 0.86, blue: 0.35) : .primary,
                         action: { xpModeAll.toggle() }) {
                Text("XP")
                    .font(.subheadline.weight(.bold))
            }

            circleButton(tint: .red, action: { viewModel.resetScores() }) {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.title3.weight(.semibold))
            }
        }
        .padding(.horizontal, 16)
    }

    private var footerBar: some View {
        HStack(spacing: 12) {
            circleButton(disabled: !viewModel.canUndo,
                         action: { viewModel.undo() }) {
                // Mirrored clockwise arrow = counterclockwise undo
                // (arrow.counterclockwise is not in SkipUI's symbol map).
                Image(systemName: "arrow.clockwise.circle")
                    .font(.title3.weight(.semibold))
                    .scaleEffect(x: -1, y: 1)
            }

            circleButton(action: { showColorSheet = true }) {
                paletteGlyph
            }

            circleButton(action: { showQuickSettingsSheet = true }) {
                Image(systemName: "person")
                    .font(.title3.weight(.semibold))
            }

            Spacer()

            Button { endGame(.lost) } label: {
                Text("Lost")
                    .font(.headline)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)

            Button { endGame(.won) } label: {
                Text("Won")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }
}
