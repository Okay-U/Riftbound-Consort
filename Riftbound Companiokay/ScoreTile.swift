//
//  ScoreTile.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 02.11.25.
//

import SwiftUI
internal import Combine

struct ScoreTile: View {
    let player: Player
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    var rotation: Double = 0
    var color: Color? = nil

    // Settings
    @AppStorage("batterySaver")   private var batterySaver: Bool = false
    @AppStorage("soundsEnabled")  private var soundsEnabled: Bool = false
    @AppStorage("ninePointGame")  private var ninePointGame: Bool = false

    // Visual feedback
    @State private var flashColor: Color? = nil
    @State private var flashOpacity: CGFloat = 0

    // Win cons
    @State private var didCelebrate: Bool = false
    @State private var showWinBurst: Bool = false
    @State private var winBurstOpacity: CGFloat = 0
    @State private var winConfettiToken: UUID = UUID()

    // Constants
    private let gold = Color(red: 0.98, green: 0.86, blue: 0.35)
    private let flashDuration: TimeInterval = 0.16
    private let flashFade: TimeInterval = 0.22
    private let corner: CGFloat = 22
    private let outsideThicknessFlash: CGFloat = 14
    private let outsideThicknessWin: CGFloat = 16
    
    private var maxScore: Int { ninePointGame ? 9 : 8 }
    private var sparkScore: Int { maxScore - 1 }

    var body: some View {
        ZStack {
            let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

            shape
                .stroke(Color.black.opacity(0.08), lineWidth: color == nil ? 1 : 0)
                .background {
                    if let color {
                        shape.fill(color)
                    } else {
                        shape.fill(.thinMaterial)
                    }
                }
                // Particles when 1P before win
                .overlay(alignment: .center) {
                    if player.score == sparkScore && !batterySaver {
                        ParticleOverlay(
                            isActive: true,
                            corner: corner,
                            particleColor: gold
                        )
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
                }
                // Win confetti
                .overlay(alignment: .center) {
                    ZStack {
                        if showWinBurst {
                            WinBurstOutside(
                                color: gold,
                                opacity: winBurstOpacity,
                                corner: corner,
                                thickness: outsideThicknessWin
                            )
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                        }
                        if didCelebrate {
                            WinConfettiOverlay(token: winConfettiToken, corner: corner)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                }

            // Light when press
            if let flashColor {
                EdgeFlashOutside(
                    color: flashColor,
                    opacity: flashOpacity,
                    corner: corner,
                    thickness: outsideThicknessFlash
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }

            Text("\(player.score)")
                .font(.system(size: 88, weight: .black, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.4)
                .foregroundStyle(.primary)
                .shadow(radius: 0.5)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Button { plusTapped() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .opacity(0.28)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressDimButtonStyle())

                Divider().opacity(0.14)

                Button { minusTapped() } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .opacity(0.28)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressDimButtonStyle())
            }
            .clipShape(shape)
        }
        .rotationEffect(.degrees(rotation))
        .onChange(of: player.score) { _, newScore in
            if newScore == maxScore && !didCelebrate {
                celebrateWin()
            }
            if newScore < maxScore {
                didCelebrate = false
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(player.score)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Oben tippen für Plus, unten für Minus.")
    }

    // MARK: - Score stuff

    private func plusTapped() {
        if player.score >= maxScore {
            Haptics.light(0.5)
            return
        }
        triggerEdgeFlash(.green, reduced: batterySaver)
        Haptics.light()
        onIncrement()
    }

    private func minusTapped() {
        triggerEdgeFlash(.red, reduced: batterySaver)
        Haptics.rigid(0.7)
        onDecrement()
    }

    private func triggerEdgeFlash(_ color: Color, reduced: Bool) {
        flashColor = color
        flashOpacity = 0.0
        let up = reduced ? 0.0 : 0.16
        let down = reduced ? 0.0 : 0.22
        let maxAlpha: CGFloat = reduced ? 0.0 : 0.65

        withAnimation(.easeOut(duration: up)) {
            flashOpacity = maxAlpha
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + up) {
            withAnimation(.easeIn(duration: down)) {
                flashOpacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + down) {
                if flashOpacity == 0 { flashColor = nil }
            }
        }
    }

    // MARK: - Win

    private func celebrateWin() {
        didCelebrate = true
        winConfettiToken = UUID()

        Haptics.success()

        showWinBurst = true
        winBurstOpacity = 0.0
        withAnimation(.easeOut(duration: 0.15)) {
            winBurstOpacity = 0.95
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeIn(duration: 0.45)) {
                winBurstOpacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) {
                showWinBurst = false
            }
        }
    }
}

struct PressDimButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.35 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Outside Glow

private struct OutsideRingMask: View {
    let corner: CGFloat
    let thickness: CGFloat
    var body: some View {
        let base = RoundedRectangle(cornerRadius: corner, style: .continuous)
        ZStack {
            base.inset(by: -thickness).fill(Color.white)
            base.fill(Color.black)
        }
        .compositingGroup()
        .luminanceToAlpha()
    }
}

private struct EdgeFlashOutside: View {
    let color: Color
    let opacity: CGFloat
    let corner: CGFloat
    let thickness: CGFloat

    var body: some View {
        Rectangle()
            .fill(color)
            .opacity(opacity)
            .blur(radius: 8)
            .mask(OutsideRingMask(corner: corner, thickness: thickness))
            .blendMode(.screen)
            .compositingGroup()
    }
}

// MARK: - Win ring

private struct WinBurstOutside: View {
    let color: Color
    let opacity: CGFloat
    let corner: CGFloat
    let thickness: CGFloat

    var body: some View {
        Rectangle()
            .fill(color)
            .opacity(opacity)
            .blur(radius: 10)
            .mask(OutsideRingMask(corner: corner, thickness: thickness))
            .blendMode(.screen)
            .compositingGroup()
    }
}

// MARK: - Particles

private struct Spark: Identifiable {
    let id = UUID()
    var start: CGPoint
    var dir: CGVector
    var size: CGFloat
    var birth: Date
    var life: TimeInterval
    var rotation: Angle
}

private struct ParticleOverlay: View {
    var isActive: Bool
    let corner: CGFloat
    let particleColor: Color

    @State private var sparks: [Spark] = []
    @State private var lastSize: CGSize = .zero
    @State private var timer: Timer? = nil

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { ctx in
                ZStack {
                    ForEach(sparks) { s in
                        let t = progress(now: ctx.date, birth: s.birth, life: s.life)
                        if t < 1 {
                            SparkView(
                                color: particleColor,
                                size: s.size,
                                progress: t
                            )
                            .rotationEffect(s.rotation)
                            .position(pointAlong(s: s, progress: t, travel: 42))
                            .blendMode(.screen)
                        }
                    }
                }
                .onChange(of: ctx.date) { _, _ in
                    sparks.removeAll { ctx.date.timeIntervalSince($0.birth) > $0.life }
                }
            }
            .onAppear {
                lastSize = geo.size
                if isActive { scheduleNextBurst() }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    lastSize = geo.size
                    scheduleNextBurst()
                } else {
                    timer?.invalidate(); timer = nil
                    sparks.removeAll()
                }
            }
            .onChange(of: geo.size) { _, newSize in
                lastSize = newSize
            }
        }
        .allowsHitTesting(false)
    }

    private func progress(now: Date, birth: Date, life: TimeInterval) -> CGFloat {
        let p = now.timeIntervalSince(birth) / life
        return CGFloat(max(0, min(1, p)))
    }

    private func scheduleNextBurst() {
        timer?.invalidate()
        let interval = Double.random(in: 1.2...2.0)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            emitBurst()
            scheduleNextBurst()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    private func emitBurst() {
        guard isActive, lastSize != .zero else { return }
        var new: [Spark] = []
        let count = Int.random(in: 4...7)

        for _ in 0..<count {
            let edge = Int.random(in: 0...3)
            let inset = corner
            switch edge {
            case 0: // Top
                let x = CGFloat.random(in: inset...(lastSize.width - inset))
                new.append(Spark(
                    start: CGPoint(x: x, y: 0),
                    dir: CGVector(dx: 0, dy: -1),
                    size: CGFloat.random(in: 4...7),
                    birth: Date(),
                    life: Double.random(in: 0.9...1.4),
                    rotation: .degrees(Double.random(in: -10...10))
                ))
            case 1: // Right
                let y = CGFloat.random(in: inset...(lastSize.height - inset))
                new.append(Spark(
                    start: CGPoint(x: lastSize.width, y: y),
                    dir: CGVector(dx: 1, dy: 0),
                    size: CGFloat.random(in: 4...7),
                    birth: Date(),
                    life: Double.random(in: 0.9...1.4),
                    rotation: .degrees(Double.random(in: -10...10))
                ))
            case 2: // Bottom
                let x = CGFloat.random(in: inset...(lastSize.width - inset))
                new.append(Spark(
                    start: CGPoint(x: x, y: lastSize.height),
                    dir: CGVector(dx: 0, dy: 1),
                    size: CGFloat.random(in: 4...7),
                    birth: Date(),
                    life: Double.random(in: 0.9...1.4),
                    rotation: .degrees(Double.random(in: -10...10))
                ))
            default: // Left
                let y = CGFloat.random(in: inset...(lastSize.height - inset))
                new.append(Spark(
                    start: CGPoint(x: 0, y: y),
                    dir: CGVector(dx: -1, dy: 0),
                    size: CGFloat.random(in: 4...7),
                    birth: Date(),
                    life: Double.random(in: 0.9...1.4),
                    rotation: .degrees(Double.random(in: -10...10))
                ))
            }
        }
        sparks.append(contentsOf: new)
    }

    private func pointAlong(s: Spark, progress t: CGFloat, travel: CGFloat) -> CGPoint {
        CGPoint(
            x: s.start.x + s.dir.dx * t * travel,
            y: s.start.y + s.dir.dy * t * travel
        )
    }
}

private struct SparkView: View {
    let color: Color
    let size: CGFloat
    let progress: CGFloat

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .scaleEffect(1.0 - 0.25 * progress)
            .opacity(Double(1.0 - progress))
            .blur(radius: (1.0 - progress) * 1.5)
    }
}

// MARK: - Win-Konfetti

private struct WinConfettiOverlay: View {
    let token: UUID
    let corner: CGFloat

    @State private var sparks: [Spark] = []

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { ctx in
                ZStack {
                    ForEach(sparks) { s in
                        let t = progress(now: ctx.date, birth: s.birth, life: s.life)
                        if t < 1 {
                            let travel: CGFloat = 60
                            SparkView(
                                color: s.id.hashValue % 2 == 0 ? .white : Color(red: 1.0, green: 0.92, blue: 0.55),
                                size: s.size,
                                progress: t
                            )
                            .rotationEffect(s.rotation)
                            .position(pointAlong(s: s, progress: t, travel: travel))
                            .blendMode(.screen)
                        }
                    }
                }
                .onChange(of: ctx.date) { _, _ in
                    sparks.removeAll { ctx.date.timeIntervalSince($0.birth) > $0.life }
                }
            }
            .onAppear {
                emitOneShot(in: geo.size)
            }
            .id(token)
        }
        .allowsHitTesting(false)
    }

    private func emitOneShot(in size: CGSize) {
        var new: [Spark] = []
        let N = 18
        for i in 0..<N {
            let angle = Double(i) / Double(N) * (.pi * 2)
            let dir = CGVector(dx: cos(angle), dy: sin(angle))
            let start = CGPoint(x: size.width/2 + CGFloat(dir.dx) * (min(size.width, size.height)/2),
                                y: size.height/2 + CGFloat(dir.dy) * (min(size.width, size.height)/2))
            new.append(Spark(
                start: start,
                dir: dir,
                size: CGFloat.random(in: 4...8),
                birth: Date(),
                life: Double.random(in: 0.7...1.1),
                rotation: .degrees(Double.random(in: -15...15))
            ))
        }
        sparks = new
    }

    private func progress(now: Date, birth: Date, life: TimeInterval) -> CGFloat {
        let p = now.timeIntervalSince(birth) / life
        return CGFloat(max(0, min(1, p)))
    }

    private func pointAlong(s: Spark, progress t: CGFloat, travel: CGFloat) -> CGPoint {
        CGPoint(
            x: s.start.x + s.dir.dx * t * travel,
            y: s.start.y + s.dir.dy * t * travel
        )
    }
}
