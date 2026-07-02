import SwiftUI

/// Root tab host. Tab icons are temp placeholders from SkipUI's mapped
/// symbol set; proper custom icons later.
struct ContentView: View {
    @AppStorage("currentTab") var currentTab: String = "score"
    @State var decklistStore = DecklistStore()

    var body: some View {
        TabView(selection: $currentTab) {
            ScoreboardScreen()
                .tabItem { Label("Score", systemImage: "house.fill") }
                .tag("score")

            DiceScreen()
                .tabItem { Label("Dice", systemImage: "star.fill") }
                .tag("dice")

            CardsScreen()
                .tabItem { Label("Cards", systemImage: "magnifyingglass") }
                .tag("cards")

            DecksScreen()
                .tabItem { Label("Decks", systemImage: "list.bullet") }
                .tag("decks")

            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag("settings")
        }
        .environment(decklistStore)
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

/// Scoreboard host, ported from the iOS ScoreboardView.
/// Wave 1 scope: 2p/4p layouts, header (title/XP/reset), footer (undo,
/// color sheet, quick settings). Timer badge, deck pill, match strip,
/// and Won/Lost game records come with later waves.
struct ScoreboardScreen: View {
    @State var viewModel = ScoreboardViewModel()
    @State var xpModeAll = false
    @State var perSlotXP: [Bool] = [false, false, false, false]
    @State var showColorSheet = false
    @State var showQuickSettingsSheet = false

    private let outerVSpacing: CGFloat = 12
    private let gridSpacing: CGFloat = 12
    private let horizPad: CGFloat = 12

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: outerVSpacing) {
                headerBar

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

        return ScoreTile(
            player: p,
            onConquer: {
                viewModel.recordEvent(p, type: .conquer, delta: 1, elapsedSeconds: 0)
            },
            onHold: {
                viewModel.recordEvent(p, type: .hold, delta: 1, elapsedSeconds: 0)
            },
            onDecrement: {
                viewModel.recordEvent(p, type: .manual, delta: -1, elapsedSeconds: 0)
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

    private var headerBar: some View {
        HStack(alignment: .center) {
            Text("Scoreboard")
                .font(.system(size: 26, weight: .bold, design: .rounded))

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
        }
        .padding(.horizontal, 16)
    }
}
