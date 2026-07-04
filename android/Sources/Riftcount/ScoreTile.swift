import SwiftUI

/// Port of the iOS ScoreTile for the Skip spike.
/// Tests the load-bearing mechanics: sliding score↔XP faces, rotation-aware
/// swipe math, press ripple, edge flash, conquer/hold/minus buttons.
struct ScoreTile: View {
    let player: Player
    let onConquer: () -> Void
    let onHold: () -> Void
    let onDecrement: () -> Void
    var rotation: Double = 0
    var paletteColor: PaletteColor? = nil
    let onXPIncrement: () -> Void
    let onXPDecrement: () -> Void
    /// When true the score face shows the interactive XP stepper (± around the
    /// XP count). When false it shows a read-only "XP N" badge (only if xp > 0),
    /// and XP is edited by swiping to the XP face — the pre-stepper behavior.
    var xpStepperEnabled: Bool = false

    // Tile mode (score vs xp)
    enum TileMode { case score, xp }
    enum SwipeDir { case left, right }
    @State var mode: TileMode = .score
    @State var isDragging: Bool = false
    @State var isFlipping: Bool = false

    // Conveyor face positions as width multipliers (-1 offscreen left,
    // 0 centered, +1 offscreen right). Animated directly; never reset
    // post-animation (Compose would animate the reset).
    @State var scoreShift: CGFloat = 0
    @State var xpShift: CGFloat = 1

    // Constants
    private let gold = Color(red: 0.98, green: 0.86, blue: 0.35)
    private let corner: CGFloat = 22
    private let swipeMinDistance: CGFloat = 18
    private let swipeThreshold: CGFloat = 55
    private let flipDuration: TimeInterval = 0.50

    private var tileShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
    }

    @ViewBuilder
    private func bgFill(for tileMode: TileMode) -> some View {
        // Rectangle (not tileShape) keeps slide edges sharp; outer clipShape rounds corners.
        if tileMode == .score, let paletteColor {
            Rectangle().fill(paletteColor.color)
        } else {
            Rectangle().fill(Color.gray.opacity(0.25))
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
        (tileMode == .score ? scoreShift : xpShift) * width
    }

    @ViewBuilder
    private func bigDigits(_ text: String) -> some View {
        // monospacedDigit() is not bridged by SkipUI; iOS keeps it.
        #if os(Android)
        Text(text)
            .font(.system(size: 88, weight: .black, design: .rounded))
            .minimumScaleFactor(0.4)
            .foregroundStyle(.primary)
        #else
        Text(text)
            .font(.system(size: 88, weight: .black, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.4)
            .foregroundStyle(.primary)
        #endif
    }

    @ViewBuilder
    private func centerContentView(for tileMode: TileMode) -> some View {
        if tileMode == .score {
            ZStack {
                bigDigits("\(player.score)")
                // XP badge/stepper lives in the interactive layer now
                // (xpScoreFaceOverlay) so its ± buttons can receive taps.
            }
        } else {
            ZStack {
                bigDigits("\(player.xp)")

                VStack {
                    HStack {
                        Text("XP")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
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
            .onChanged { v in
                if abs(v.translation.width) > abs(v.translation.height) {
                    isDragging = true
                }
            }
            .onEnded { v in
                isDragging = false
                // Gesture reports translation in screen coords; offset applies in
                // pre-rotation tile-local coords. Invert sign for 180° rotated tiles.
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
        guard !isFlipping, mode != target else { return }
        isFlipping = true
        let exit: CGFloat = direction == .left ? -1 : 1
        // Phase 1: park the incoming face on the side opposite the exit,
        // un-animated (offscreen + clipped, so the jump is invisible).
        if target == .xp { xpShift = -exit } else { scoreShift = -exit }
        Haptics.selection()
        // Phase 2: animate both faces in the same direction (conveyor).
        // A single async hop is NOT enough on Compose — the park may land in
        // the same frame and never render, making the animation start from
        // the face's previous resting side. Buffer a few frames instead.
        let parkCommitDelay = 0.06
        DispatchQueue.main.asyncAfter(deadline: .now() + parkCommitDelay) {
            mode = target
            withAnimation(.easeInOut(duration: flipDuration)) {
                if target == .xp {
                    xpShift = 0
                    scoreShift = exit
                } else {
                    scoreShift = 0
                    xpShift = exit
                }
            }
        }
        // Bookkeeping only — no visual state changes after the animation.
        DispatchQueue.main.asyncAfter(deadline: .now() + parkCommitDelay + flipDuration) {
            isFlipping = false
        }
    }

    private func iconAccent(for tileMode: TileMode) -> Color {
        if tileMode == .xp { return gold.opacity(0.85) }
        let dark = paletteColor?.isDark ?? true
        return dark
            ? Color(white: 0.95).opacity(0.85)
            : Color(white: 0.10).opacity(0.75)
    }

    /// Tile action icons. SkipUI only maps ~50 SF Symbol names to Material
    /// icons (no flag/shield/minus), so these are custom cross-platform
    /// shapes; only plus rides the mapped plus.circle.fill.
    enum TileIcon { case flag, shield, minus, plus }

    @ViewBuilder
    private func actionIcon(_ icon: TileIcon, size: CGFloat = 26, for tileMode: TileMode) -> some View {
        let tint = iconAccent(for: tileMode)
        switch icon {
        case .plus:
            Image(systemName: "plus.circle.fill")
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
        case .minus:
            Capsule()
                .fill(tint)
                .frame(width: size * 0.9, height: size * 0.16)
                .frame(width: size, height: size)
        case .flag:
            FlagShape()
                .fill(tint)
                .frame(width: size, height: size)
        case .shield:
            ShieldShape()
                .fill(tint)
                .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private func actionLabel(_ title: String, icon: TileIcon, size: CGFloat = 30, for tileMode: TileMode) -> some View {
        actionIcon(icon, size: size, for: tileMode)
            .overlay {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
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
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func topHalf(for tileMode: TileMode) -> some View {
        if tileMode == .score {
            HStack(spacing: 0) {
                Button { conquerTapped() } label: {
                    actionLabel("Conquer", icon: .flag, size: 30, for: tileMode)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tileHitArea()
                        .background(regionTint(from: .topLeading))
                }
                .halfTilePress()

                Button { holdTapped() } label: {
                    actionLabel("Hold", icon: .shield, size: 30, for: tileMode)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tileHitArea()
                        .background(regionTint(from: .topTrailing))
                }
                .halfTilePress()
            }
        } else {
            Button { plusTapped() } label: {
                actionIcon(.plus, size: 30, for: tileMode)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tileHitArea()
            }
            .halfTilePress()
        }
    }

    @ViewBuilder
    private func halfButtons(for tileMode: TileMode) -> some View {
        VStack(spacing: 0) {
            topHalf(for: tileMode)

            Button { minusTapped() } label: {
                actionIcon(.minus, size: 30, for: tileMode)
                    .padding(.top, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tileHitArea()
                    .background(regionTint(from: .bottom))
            }
            .halfTilePress()
        }
        .clipShape(tileShape)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                // Sliding faces, clipped to tile bounds. Score face on top via zIndex.
                ZStack {
                    face(for: .xp)
                        .offset(x: positionFor(.xp, width: w))
                        .zIndex(0)
                    face(for: .score)
                        .offset(x: positionFor(.score, width: w))
                        .zIndex(1)
                }
                .clipShape(tileShape)

                tileShape
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                    .allowsHitTesting(false)

                // Interactive buttons slide with their face; only active mode taps.
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
            .shadow(color: Color.black.opacity(0.18), radius: 8, y: 3)
            // GeometryReader's first Compose frame measures width 0, which
            // puts every face/icon at the center before jumping into place —
            // visible as a flicker when returning to this tab. Hide until
            // there's a real width.
            .opacity(w > 0 ? 1 : 0)
            .tileHitArea()
            .rotationEffect(Angle(degrees: rotation))
            .tileSwipeGesture(makeSwipeGesture(width: w))
        }
    }

    // MARK: - XP score-face overlay

    // Stepper when XP mode is on, else the classic read-only badge (hidden
    // entirely at xp 0 — the original behavior).
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
    // swipe to the XP face for every point. ± are bold Text glyphs (Skip maps
    // plus.circle.fill but not minus.circle.fill, so glyphs keep both sides
    // matched); dims when XP is 0 to stay quiet.
    private var xpStepper: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                HStack(spacing: 2) {
                    // onTapGesture, not Button — any Skip Button keeps Compose's
                    // ripple indication; a tap gesture has none.
                    stepperGlyph("−")
                        .onTapGesture { xpStepperMinus() }

                    Text("XP \(player.xp)")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .fixedSize()

                    stepperGlyph("+")
                        .onTapGesture { xpStepperPlus() }
                }
                .foregroundStyle(gold.opacity(player.xp > 0 ? 0.9 : 0.55))
                .padding(.horizontal, 2)
                .background(Capsule().fill(Color.black.opacity(0.28)))
                .padding(.trailing, 10)
                .padding(.bottom, 8)
            }
        }
    }

    private func stepperGlyph(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 20, weight: .heavy, design: .rounded))
            .frame(width: 34, height: 34)
            .tileHitArea()
    }

    private func xpStepperPlus() {
        Haptics.light()
        onXPIncrement()
    }

    private func xpStepperMinus() {
        Haptics.rigid(0.7)
        onXPDecrement()
    }

    // MARK: - Actions

    private func plusTapped() {
        Haptics.light()
        onXPIncrement()
    }

    private func conquerTapped() {
        guard mode == .score else { return }
        Haptics.light()
        onConquer()
    }

    private func holdTapped() {
        guard mode == .score else { return }
        Haptics.light()
        onHold()
    }

    private func minusTapped() {
        Haptics.rigid(0.7)
        if mode == .score {
            onDecrement()
        } else {
            onXPDecrement()
        }
    }
}

// MARK: - Custom icon shapes (cross-platform, no SF Symbol dependency)

/// Pennant flag: vertical pole plus triangular banner.
struct FlagShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        // Pole
        p.addRoundedRect(
            in: CGRect(x: rect.minX + 0.06 * w, y: rect.minY, width: 0.10 * w, height: h),
            cornerSize: CGSize(width: 0.04 * w, height: 0.04 * w)
        )
        // Banner
        p.move(to: CGPoint(x: rect.minX + 0.20 * w, y: rect.minY + 0.04 * h))
        p.addLine(to: CGPoint(x: rect.minX + 0.98 * w, y: rect.minY + 0.24 * h))
        p.addLine(to: CGPoint(x: rect.minX + 0.20 * w, y: rect.minY + 0.46 * h))
        p.closeSubpath()
        return p
    }
}

/// Classic badge shield: flat top, sides tapering to a bottom point.
struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let top = rect.minY + 0.08 * h
        p.move(to: CGPoint(x: rect.minX + 0.12 * w, y: top))
        p.addLine(to: CGPoint(x: rect.minX + 0.88 * w, y: top))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + 0.50 * w, y: rect.minY + 0.98 * h),
            control: CGPoint(x: rect.minX + 0.92 * w, y: rect.minY + 0.72 * h)
        )
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + 0.12 * w, y: top),
            control: CGPoint(x: rect.minX + 0.08 * w, y: rect.minY + 0.72 * h)
        )
        p.closeSubpath()
        return p
    }
}

extension View {
    /// contentShape(Rectangle()) is not bridged by SkipUI; Compose hit areas
    /// already cover the padded frame, so Android is a no-op.
    @ViewBuilder func tileHitArea() -> some View {
        #if os(Android)
        self
        #else
        self.contentShape(Rectangle())
        #endif
    }

    /// highPriorityGesture is not bridged; Android uses plain gesture.
    /// Risk to verify on device: drag may lose to button taps on Android.
    @ViewBuilder func tileSwipeGesture(_ gesture: some Gesture) -> some View {
        #if os(Android)
        self.gesture(gesture)
        #else
        self.highPriorityGesture(gesture)
        #endif
    }

    /// Custom isPressed-driven ButtonStyles are not bridged (PrimitiveButtonStyle
    /// only). Android relies on Compose's native ripple via borderless style.
    @ViewBuilder func halfTilePress() -> some View {
        #if os(Android)
        self.buttonStyle(.borderless)
        #else
        self.buttonStyle(HalfTilePressStyle())
        #endif
    }
}

#if !os(Android)
struct HalfTilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                PressRipple(isPressed: configuration.isPressed)
                    .allowsHitTesting(false)
            )
    }
}

struct PressRipple: View {
    let isPressed: Bool
    @State var scale: CGFloat = 0
    @State var opacity: Double = 0

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
#endif
