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
    let onConquer: () -> Void
    let onHold: () -> Void
    let onDecrement: () -> Void
    var rotation: Double = 0
    var color: Color? = nil
    let onXPIncrement: () -> Void
    let onXPDecrement: () -> Void
    var desiredXPMode: Bool = false
    var onModeChange: (Bool) -> Void = { _ in }

    // Settings
    @AppStorage("batterySaver")   private var batterySaver: Bool = false
    @AppStorage("soundsEnabled")  private var soundsEnabled: Bool = false

    // Visual feedback
    @State private var flashColor: Color? = nil
    @State private var flashOpacity: CGFloat = 0

    // Tile mode (score vs xp)
    private enum TileMode { case score, xp }
    private enum SwipeDir { case left, right }
    @State private var mode: TileMode = .score
    @State private var swipeDirection: SwipeDir = .left
    @GestureState private var isDragging: Bool = false
    @State private var dragOffset: CGFloat = 0
    @State private var isFlipping: Bool = false

    // Constants
    private let gold = Color(red: 0.98, green: 0.86, blue: 0.35)
    private let flashDuration: TimeInterval = 0.16
    private let flashFade: TimeInterval = 0.22
    private let corner: CGFloat = 22
    private let outsideThicknessFlash: CGFloat = 14
    private let swipeMinDistance: CGFloat = 18
    private let swipeThreshold: CGFloat = 55
    private let flipDuration: TimeInterval = 0.50
    
    private var tileShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
    }

    @ViewBuilder
    private func bgFill(for tileMode: TileMode) -> some View {
        // Score mode honors per-slot color; XP mode always uses default thinMaterial.
        // Use Rectangle so leading/trailing edges stay sharp during slide; outer
        // clipShape(tileShape) handles rounded tile corners.
        if tileMode == .score, let color {
            Rectangle().fill(color)
        } else {
            Rectangle().fill(.thinMaterial)
        }
    }

    @ViewBuilder
    private func face(for tileMode: TileMode) -> some View {
        ZStack {
            bgFill(for: tileMode)
            centerContentView(for: tileMode)
        }
    }

    private func positionFor(_ tileMode: TileMode, width: CGFloat) -> CGFloat {
        if mode == tileMode { return dragOffset }
        // Non-current face sits offscreen on the side based on last swipe direction.
        // During animation, dragOffset interpolates and so does this offset.
        return swipeDirection == .right ? dragOffset - width : dragOffset + width
    }

    @ViewBuilder
    private func centerContentView(for tileMode: TileMode) -> some View {
        if tileMode == .score {
            ZStack {
                Text("\(player.score)")
                    .font(.system(size: 88, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(.primary)
                    .shadow(radius: 0.5)

                if player.xp > 0 {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("XP \(player.xp)")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .tracking(1)
                                .foregroundStyle(gold.opacity(0.9))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.black.opacity(0.28)))
                                .padding(.trailing, 14)
                                .padding(.bottom, 12)
                        }
                    }
                }
            }
        } else {
            ZStack {
                Text("\(player.xp)")
                    .font(.system(size: 88, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(.primary)
                    .shadow(radius: 0.5)

                VStack {
                    HStack {
                        Text("XP")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(gold.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.black.opacity(0.25)))
                            .padding(.leading, 14)
                            .padding(.top, 14)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
    }

    private func makeSwipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: swipeMinDistance)
            .updating($isDragging) { v, state, _ in
                if abs(v.translation.width) > abs(v.translation.height) {
                    state = true
                }
            }
            .onEnded { v in
                // Gesture reports translation in screen coords; offset applies in
                // pre-rotation tile-local coords. Invert sign for 180° rotated tiles
                // so animation matches user's perceived swipe direction.
                let rawDx = v.translation.width
                let dy = v.translation.height
                let dx: CGFloat = (rotation == 180) ? -rawDx : rawDx
                let shouldFlip = abs(dx) > swipeThreshold && abs(dx) > abs(dy)
                guard shouldFlip else { return }
                let target: TileMode = (mode == .score) ? .xp : .score
                let direction: SwipeDir = dx > 0 ? .right : .left
                performFlip(to: target, direction: direction, width: width)
            }
    }

    private func performFlip(to target: TileMode, direction: SwipeDir, width: CGFloat) {
        // Guard against re-entry: a second flip during an in-flight animation
        // would corrupt swipeDirection / dragOffset and the completion would
        // fire against stale state.
        guard !isFlipping, mode != target else { return }
        isFlipping = true
        // Set incoming side BEFORE withAnimation so positionFor's switch happens
        // synchronously. Then dragOffset animates smoothly 0 → exitTarget.
        swipeDirection = direction
        let exitTarget: CGFloat = direction == .right ? width : -width
        Haptics.selection()
        withAnimation(.easeInOut(duration: flipDuration)) {
            dragOffset = exitTarget
        } completion: {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                mode = target
                dragOffset = 0
            }
            isFlipping = false
            // Defer parent state mutation out of animation commit phase to avoid
            // "Publishing changes from within view updates" warnings.
            DispatchQueue.main.async {
                onModeChange(target == .xp)
            }
        }
    }

    @ViewBuilder
    private var pressFlashOverlay: some View {
        if let flashColor {
            EdgeFlashOutside(color: flashColor,
                             opacity: flashOpacity,
                             corner: corner,
                             thickness: outsideThicknessFlash)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func iconAccent(for tileMode: TileMode) -> Color {
        if tileMode == .xp { return gold.opacity(0.85) }
        return isDarkTileColor
            ? Color(white: 0.95).opacity(0.85)
            : Color(white: 0.10).opacity(0.75)
    }

    private var isDarkTileColor: Bool {
        guard let color else { return true }
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance < 0.55
    }

    @ViewBuilder
    private func actionIcon(_ name: String, size: CGFloat = 26, for tileMode: TileMode) -> some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(iconAccent(for: tileMode))
    }

    @ViewBuilder
    private func actionLabel(_ title: String, symbol: String, size: CGFloat = 30, for tileMode: TileMode) -> some View {
        actionIcon(symbol, size: size, for: tileMode)
            .overlay(alignment: .center) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(iconAccent(for: tileMode))
                    .fixedSize()
                    .offset(y: -38)
            }
    }

    @ViewBuilder
    private func regionTint(from corner: UnitPoint) -> some View {
        LinearGradient(
            colors: [Color.white.opacity(0.12), Color.black.opacity(0.08)],
            startPoint: corner,
            endPoint: UnitPoint(x: 1 - corner.x, y: 1 - corner.y)
        )
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func topHalf(for tileMode: TileMode) -> some View {
        if tileMode == .score {
            HStack(spacing: 0) {
                Button { conquerTapped() } label: {
                    actionLabel("Conquer", symbol: "flag.fill", size: 30, for: tileMode)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .background(regionTint(from: .topLeading))
                }
                .buttonStyle(HalfTilePressStyle())

                Button { holdTapped() } label: {
                    actionLabel("Hold", symbol: "shield.lefthalf.filled", size: 30, for: tileMode)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .background(regionTint(from: .topTrailing))
                }
                .buttonStyle(HalfTilePressStyle())
            }
        } else {
            Button { plusTapped() } label: {
                actionIcon("plus.circle.fill", size: 30, for: tileMode)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(HalfTilePressStyle())
        }
    }

    @ViewBuilder
    private func halfButtons(for tileMode: TileMode) -> some View {
        VStack(spacing: 0) {
            topHalf(for: tileMode)

            Button { minusTapped() } label: {
                actionIcon("minus.circle.fill", size: 30, for: tileMode)
                    .padding(.top, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .background(regionTint(from: .bottom))
            }
            .buttonStyle(HalfTilePressStyle())
        }
        .clipShape(tileShape)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                // Sliding faces (color + center content), clipped to tile bounds.
                // Score face always on top via zIndex (it's the opaque one when colored).
                // Translucent xp face stays behind → no blend fade either direction.
                ZStack {
                    face(for: .xp)
                        .offset(x: positionFor(.xp, width: w))
                        .zIndex(0)
                    face(for: .score)
                        .offset(x: positionFor(.score, width: w))
                        .zIndex(1)
                }
                .clipShape(tileShape)

                // Stroke on top, never clipped.
                tileShape
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                    .allowsHitTesting(false)

                // Outside-tile effects (extend beyond bounds).
                pressFlashOverlay

                // Interactive +/- buttons — slide with their face so icons
                // don't pop on mode change. Only active mode receives taps.
                ZStack {
                    halfButtons(for: .xp)
                        .offset(x: positionFor(.xp, width: w))
                        .allowsHitTesting(mode == .xp && !isDragging)
                        .zIndex(0)
                    halfButtons(for: .score)
                        .offset(x: positionFor(.score, width: w))
                        .allowsHitTesting(mode == .score && !isDragging)
                        .zIndex(1)
                }
                .clipShape(tileShape)
            }
            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
            .contentShape(Rectangle())
            .rotationEffect(.degrees(rotation))
            .highPriorityGesture(makeSwipeGesture(width: w))
            .onChange(of: desiredXPMode) { _, newValue in
                let target: TileMode = newValue ? .xp : .score
                guard mode != target, !isFlipping else { return }
                // Toggle on (→ xp) slides incoming from left; toggle off (→ score) from right.
                let direction: SwipeDir = newValue ? .left : .right
                performFlip(to: target, direction: direction, width: w)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(mode == .score ? "Score \(player.score)" : "XP \(player.xp)")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Tap top for plus, bottom for minus. Swipe to switch XP mode.")
        }
    }

    // MARK: - Score stuff

    private func plusTapped() {
        // Reached only in XP mode (score mode uses conquer/hold buttons).
        triggerEdgeFlash(.green, reduced: batterySaver)
        Haptics.light()
        onXPIncrement()
    }

    private func conquerTapped() {
        guard mode == .score else { return }
        triggerEdgeFlash(.green, reduced: batterySaver)
        Haptics.light()
        onConquer()
    }

    private func holdTapped() {
        guard mode == .score else { return }
        triggerEdgeFlash(.green, reduced: batterySaver)
        Haptics.light()
        onHold()
    }

    private func minusTapped() {
        triggerEdgeFlash(.red, reduced: batterySaver)
        Haptics.rigid(0.7)
        if mode == .score {
            onDecrement()
        } else {
            onXPDecrement()
        }
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

}

struct PressDimButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.35 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct HalfTilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                PressRipple(isPressed: configuration.isPressed)
                    .allowsHitTesting(false)
            )
    }
}

private struct PressRipple: View {
    let isPressed: Bool
    @State private var scale: CGFloat = 0
    @State private var opacity: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let dim = sqrt(geo.size.width * geo.size.width + geo.size.height * geo.size.height)
            Circle()
                .fill(Color.black)
                .frame(width: dim, height: dim)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                .scaleEffect(scale, anchor: .center)
                .opacity(opacity)
        }
        .clipped()
        .onChange(of: isPressed) { _, pressed in
            if pressed {
                scale = 0
                withAnimation(.easeOut(duration: 0.22)) {
                    scale = 1
                    opacity = 0.22
                }
            } else {
                withAnimation(.easeOut(duration: 0.40)) {
                    opacity = 0
                }
            }
        }
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
