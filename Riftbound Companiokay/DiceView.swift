//
//  DiceView.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 02.11.25.
//

import SwiftUI

enum DieType: Int, CaseIterable, Identifiable {
    case d6  = 6
    case d8  = 8
    case d12 = 12
    case d20 = 20

    var id: Int { rawValue }
    var label: String { "D\(rawValue)" }

    /// Number of edges of the polygon used to represent this die.
    var faceSides: Int {
        switch self {
        case .d6:  return 4   // flat rounded square
        case .d8:  return 4   // rotated square (diamond)
        case .d12: return 5   // pentagon
        case .d20: return 8   // octagon (stop-sign style)
        }
    }

    /// Rotation in degrees applied to the face polygon for visual orientation.
    var faceRotation: Double {
        switch self {
        case .d6:  return 45    // square sides horizontal/vertical
        case .d8:  return 0     // diamond (vertex up)
        case .d12: return 0     // pentagon point up
        case .d20: return 22.5  // octagon flat top
        }
    }
}

struct DiceView: View {
    // Settings
    @AppStorage("diceShakeToRoll") private var diceShakeToRoll: Bool = true
    @AppStorage("currentTab")      private var currentTab: String = "score"
    @AppStorage("diceType")        private var diceTypeRaw: Int = 6

    // State
    @State private var value: Int = 1
    @State private var isRolling: Bool = false
    @State private var rollScale: CGFloat = 1.0

    private var selectedDie: DieType {
        DieType(rawValue: diceTypeRaw) ?? .d6
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Dice")
                .font(.title2.bold())

            Picker("Die Type", selection: $diceTypeRaw) {
                ForEach(DieType.allCases) { die in
                    Text(die.label).tag(die.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: diceTypeRaw) { _, _ in
                value = 1
            }

            Button { roll() } label: {
                DieShape(die: selectedDie, value: value, rollScale: rollScale)
                    .frame(width: 220, height: 220)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
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
        // Invisible first-responder that turns motionShake into the
        // notification ShakeManager republishes — without it in the tree,
        // shake-to-roll never fires (regressed in the dice redesign).
        .background(ShakeDetector().frame(width: 1, height: 1))
        .onReceive(ShakeManager.shared.publisher) { _ in
            if diceShakeToRoll && currentTab == "dice" {
                roll()
            }
        }
        .onAppear {
            // Migrate legacy D4/D10 selections to D6.
            if DieType(rawValue: diceTypeRaw) == nil {
                diceTypeRaw = DieType.d6.rawValue
            }
        }
    }

    // MARK: - Die visual

    private struct DieShape: View {
        let die: DieType
        let value: Int
        let rollScale: CGFloat

        private var gradient: LinearGradient {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.22),
                    Color.white.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint:   .bottomTrailing
            )
        }

        var body: some View {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let polygon = RegularPolygon(sides: die.faceSides, cornerRadius: 16)

                ZStack {
                    polygon
                        .fill(gradient)
                        .overlay(
                            polygon.stroke(
                                Color.white.opacity(0.35),
                                lineWidth: 1.5
                            )
                        )
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                        .rotationEffect(.degrees(die.faceRotation))

                    Text("\(value)")
                        .font(.system(size: side * 0.36, weight: .black, design: .rounded))
                        .scaleEffect(rollScale)
                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: rollScale)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    /// Regular n-gon centered in its rect, point up at 0° rotation.
    private struct RegularPolygon: Shape {
        let sides: Int
        let cornerRadius: CGFloat

        func path(in rect: CGRect) -> Path {
            guard sides >= 3 else { return Path(rect) }
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2
            var points: [CGPoint] = []
            for i in 0..<sides {
                // -90° offset puts first vertex at top.
                let angle = (Double(i) / Double(sides)) * 2 * .pi - .pi / 2
                points.append(CGPoint(
                    x: center.x + radius * CGFloat(cos(angle)),
                    y: center.y + radius * CGFloat(sin(angle))
                ))
            }

            var path = Path()
            // Squared shape (cornerRadius == 0): direct line draws.
            if cornerRadius <= 0 {
                path.move(to: points[0])
                for p in points.dropFirst() { path.addLine(to: p) }
                path.closeSubpath()
                return path
            }

            // Rounded corners via arcs between adjacent edges.
            for i in 0..<sides {
                let prev = points[(i + sides - 1) % sides]
                let curr = points[i]
                let next = points[(i + 1) % sides]
                let v1 = unitVector(from: curr, to: prev)
                let v2 = unitVector(from: curr, to: next)
                let p1 = CGPoint(x: curr.x + v1.dx * cornerRadius,
                                 y: curr.y + v1.dy * cornerRadius)
                if i == 0 { path.move(to: p1) } else { path.addLine(to: p1) }
                path.addQuadCurve(
                    to: CGPoint(x: curr.x + v2.dx * cornerRadius,
                                y: curr.y + v2.dy * cornerRadius),
                    control: curr
                )
            }
            path.closeSubpath()
            return path
        }

        private func unitVector(from a: CGPoint, to b: CGPoint) -> CGVector {
            let dx = b.x - a.x
            let dy = b.y - a.y
            let len = max(sqrt(dx * dx + dy * dy), 0.0001)
            return CGVector(dx: dx / len, dy: dy / len)
        }
    }

    private func roll() {
        guard !isRolling else { return }
        isRolling = true

        let sides = selectedDie.rawValue

        rollScale = 1.5
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            rollScale = 1.0
        }

        let step: TimeInterval = 0.05
        let hops  = Int.random(in: 11...14)

        for i in 0..<hops {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * step) {
                value = Int.random(in: 1...sides)
            }
        }

        let finishDelay = Double(hops) * step + 0.02
        DispatchQueue.main.asyncAfter(deadline: .now() + finishDelay) {
            Haptics.success()
            isRolling = false
        }
    }
}
