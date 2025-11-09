//
//  DiceView.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 02.11.25.
//

import SwiftUI

struct DiceView: View {
    // Settings
    @AppStorage("diceShakeToRoll") private var diceShakeToRoll: Bool = true
    @AppStorage("currentTab")      private var currentTab: String = "score"

    // State
    @State private var value: Int = 1
    @State private var isRolling: Bool = false
    @State private var rollScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 20) {
            Text("Dice")
                .font(.title2.bold())

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.thinMaterial)
                    .frame(width: 200, height: 200)

                Text("\(value)")
                    .font(.system(size: 80, weight: .black, design: .rounded))
                    .scaleEffect(rollScale)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: rollScale)
            }
            .padding(.bottom, 4)

            HStack(spacing: 12) {
                Button {
                    roll()
                } label: {
                    Label("Roll", systemImage: "die.face.5")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .navigationTitle("Dice")
        .onReceive(ShakeManager.shared.publisher) { _ in
            if diceShakeToRoll && currentTab == "dice" {
                roll()
            }
        }
    }

    private func roll() {
        guard !isRolling else { return }
        isRolling = true

        rollScale = 1.5
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            rollScale = 1.0
        }

        let step: TimeInterval = 0.05
        let hops  = Int.random(in: 11...14)

        for i in 0..<hops {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * step) {
                value = Int.random(in: 1...6)
            }
        }

        let finishDelay = Double(hops) * step + 0.02
        DispatchQueue.main.asyncAfter(deadline: .now() + finishDelay) {
            Haptics.success()
            isRolling = false
        }
    }
}

