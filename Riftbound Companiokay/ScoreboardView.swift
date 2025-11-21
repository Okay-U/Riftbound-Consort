//
//  ScoreboardView.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 02.11.25.
//

import SwiftUI

struct ScoreboardView: View {
    @EnvironmentObject var vm: ScoreboardViewModel
    @AppStorage("trueBlack") private var trueBlack: Bool = true
    @AppStorage("ninePointGame") private var ninePointGame: Bool = false
    @State private var showColorSheet = false
    @State private var showQuickSettingsSheet = false

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
            QuickSettingsSheet(ninePointGame: $ninePointGame)
        }
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
        HStack {
            Text("Scoreboard")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Spacer()
            Button(role: .destructive) { vm.resetScores() } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
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

            Picker("Players", selection: Binding(
                get: { vm.playerCount },
                set: { vm.playerCount = $0 }
            )) {
                Text("2").tag(2)
                Text("4").tag(4)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 160)
        }
        .padding(.horizontal, 16)
    }
}
