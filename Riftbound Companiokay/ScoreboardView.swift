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
    @AppStorage("trueBlack") private var trueBlack: Bool = true
    @AppStorage("targetScore") private var targetScore: Int = 8
    @AppStorage("activeDeckId")   private var activeDeckId: String = ""
    @AppStorage("activeOpponent") private var activeOpponent: String = ""
    @State private var showColorSheet = false
    @State private var showQuickSettingsSheet = false
    @State private var showGameSetupSheet = false
    @State private var lastGameEnd: TimeInterval = 0

    private let outerVSpacing: CGFloat = 12
    private let gridSpacing: CGFloat = 12
    private let horizPad: CGFloat = 12

    var body: some View {
        ZStack {
            (trueBlack ? Color.black : Color(.systemBackground)).ignoresSafeArea()

            VStack(spacing: outerVSpacing) {
                headerBar

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
            QuickSettingsSheet(targetScore: $targetScore)
                .environmentObject(vm)
        }
        .sheet(isPresented: $showGameSetupSheet) {
            GameSetupSheet()
                .environmentObject(decklistStore)
                .environmentObject(cardStore)
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
        let record = GameRecord(
            deckId: deck?.id,
            deckName: deck?.name,
            opponent: opponent,
            result: result,
            durationSeconds: Int(delta)
        )
        gameRecordStore.record(record)
        lastGameEnd = now
        vm.resetScores()
    }

    private func visibleSlots() -> [Int] {
        vm.playerCount == 2 ? [0, 1] : [0, 1, 2, 3]
    }

    private func tileFor(slot: Int, rotation: Double) -> some View {
        let p = vm.players[slot]
        let idx = vm.colorIndex(for: slot)
        let fill: Color? = (idx >= 0) ? Palette.colors[idx % Palette.colors.count] : nil

        return ScoreTile(
            player: p,
            onIncrement: { vm.increment(p) },
            onDecrement: { vm.decrement(p) },
            rotation: rotation,
            color: fill
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
        VStack(alignment: .leading, spacing: 6) {
            Text("Scoreboard")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            TimerBadgeView()
            deckPill
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
                Image(systemName: "gearshape")
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
