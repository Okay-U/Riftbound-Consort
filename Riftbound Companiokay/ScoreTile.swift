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
    /// When true the score face shows the interactive XP stepper (± around the
    /// XP count). When false it shows a read-only "XP N" badge (only if xp > 0),
    /// and XP is edited by swiping to the XP face — the pre-stepper behavior.
    var xpStepperEnabled: Bool = false

    // Settings
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

                // XP badge lives in the interactive layer now (xpStepper) so
                // its +/- buttons can receive taps above the half-tile buttons.
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

    // Score-face XP overlay: stepper when XP mode is on, else the classic
    // read-only badge (hidden entirely at xp 0 — the original behavior).
    @ViewBuilder
    private var xpScoreFaceOverlay: some View {
        if xpStepperEnabled {
            xpStepper
        } else if player.xp > 0 {
            xpReadOnlyBadge
        }
    }

    private var xpReadOnlyBadge: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("XP \(player.xp)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1)
                    .monospacedDigit()
                    .foregroundStyle(gold.opacity(0.9))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.28)))
                    .padding(.trailing, 14)
                    .padding(.bottom, 12)
            }
        }
    }

    // Quick XP stepper on the score face — heavy-XP decks shouldn't need a
    // swipe to the XP face for every point. Same spot/typography as the
    // read-only badge, now with ± buttons; dims when XP is 0 to stay quiet.
    // No edge flash: green/red flashes stay reserved for score changes.
    private var xpStepper: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                HStack(spacing: 2) {
                    Button { xpStepperMinus() } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressDimButtonStyle())

                    Text("XP \(player.xp)")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .tracking(1)
                        .monospacedDigit()
                        .fixedSize()

                    Button { xpStepperPlus() } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressDimButtonStyle())
                }
                .foregroundStyle(gold.opacity(player.xp > 0 ? 0.9 : 0.55))
                .padding(.horizontal, 2)
                .background(Capsule().fill(Color.black.opacity(0.28)))
                .padding(.trailing, 10)
                .padding(.bottom, 8)
            }
        }
    }

    private func xpStepperPlus() {
        Haptics.light()
        onXPIncrement()
    }

    private func xpStepperMinus() {
        Haptics.rigid(0.7)
        onXPDecrement()
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
                    xpScoreFaceOverlay
                        .offset(x: positionFor(.score, width: w))
                        .allowsHitTesting(xpStepperEnabled && mode == .score && !isDragging)
                        .zIndex(2)
                }
                .clipShape(tileShape)
            }
            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
            .contentShape(Rectangle())
            .rotationEffect(.degrees(rotation))
            .highPriorityGesture(makeSwipeGesture(width: w))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(mode == .score ? "Score \(player.score)" : "XP \(player.xp)")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Tap top for plus, bottom for minus. Swipe to switch XP mode.")
        }
    }

    // MARK: - Score stuff

    private func plusTapped() {
        // Reached only in XP mode (score mode uses conquer/hold buttons).
        triggerEdgeFlash(.green)
        Haptics.light()
        onXPIncrement()
    }

    private func conquerTapped() {
        guard mode == .score else { return }
        triggerEdgeFlash(.green)
        Haptics.light()
        onConquer()
    }

    private func holdTapped() {
        guard mode == .score else { return }
        triggerEdgeFlash(.green)
        Haptics.light()
        onHold()
    }

    private func minusTapped() {
        triggerEdgeFlash(.red)
        Haptics.rigid(0.7)
        if mode == .score {
            onDecrement()
        } else {
            onXPDecrement()
        }
    }

    private func triggerEdgeFlash(_ color: Color) {
        flashColor = color
        flashOpacity = 0.0
        let up = 0.16
        let down = 0.22
        let maxAlpha: CGFloat = 0.65

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

