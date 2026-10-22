//
//  DuelParts.swift
//  Riftbound Companiokay
//
//  "Who goes first" (Android `DuelParts.kt`): the die of each half, the half itself (tap to roll), the
//  verdict banner of four players and the D20 / D6 switch of the seam.
//

import SwiftUI

/// Die outlines of the mock on a 200 viewport: D20 hexagon with its facets, D6 rounded square.
private enum DieShapes {
    private static func polygon(_ n: Int, _ r: CGFloat, _ cx: CGFloat, _ cy: CGFloat) -> [CGPoint] {
        (0..<n).map { i in
            let a = (-90 + Double(i) * 360 / Double(n)) * .pi / 180
            return CGPoint(x: cx + r * cos(a), y: cy + r * sin(a))
        }
    }

    private static func closed(_ points: [CGPoint]) -> Path {
        Path { p in
            p.addLines(points)
            p.closeSubpath()
        }
    }

    static func paths(_ kind: FirstRoll.DieKind) -> (body: Path, facets: Path) {
        switch kind {
        case .d20:
            let hex = polygon(6, 92, 100, 100)
            let tri = polygon(3, 56, 100, 106)
            var facets = closed(tri)
            for (i, point) in tri.enumerated() {
                facets.move(to: point)
                facets.addLine(to: hex[i * 2])
            }
            return (closed(hex), facets)
        case .d6:
            let body = Path { p in
                p.move(to: CGPoint(x: 58, y: 22))
                p.addLine(to: CGPoint(x: 142, y: 22))
                p.addQuadCurve(to: CGPoint(x: 178, y: 58), control: CGPoint(x: 178, y: 22))
                p.addLine(to: CGPoint(x: 178, y: 142))
                p.addQuadCurve(to: CGPoint(x: 142, y: 178), control: CGPoint(x: 178, y: 178))
                p.addLine(to: CGPoint(x: 58, y: 178))
                p.addQuadCurve(to: CGPoint(x: 22, y: 142), control: CGPoint(x: 22, y: 178))
                p.addLine(to: CGPoint(x: 22, y: 58))
                p.addQuadCurve(to: CGPoint(x: 58, y: 22), control: CGPoint(x: 22, y: 22))
                p.closeSubpath()
            }
            return (body, Path(CGRect(x: 46, y: 46, width: 108, height: 108)))
        }
    }
}

struct DieGraphic: View {
    let kind: FirstRoll.DieKind
    let die: FirstRoll.Die
    let accent: Color
    let highlight: Bool
    var size: CGFloat = 190
    /// Bumped when the die lands: the ring spreads once.
    @State private var landings = 0

    private var rolled: Bool { die.value != nil }
    private var landed: Bool { rolled && !die.rolling }

    var body: some View {
        let shapes = DieShapes.paths(kind)
        let spin = die.rolling || !rolled ? Double(die.rolls) * 48 : (Double(die.rolls) * 48 / 360).rounded(.up) * 360 + 360
        let fast = die.rolling && die.rolls < 9
        ZStack {
            Circle()
                .stroke(accent, lineWidth: 2)
                .frame(width: size * 0.9, height: size * 0.9)
                .keyframeAnimator(initialValue: CGFloat(1), trigger: landings) { ring, p in
                    ring.scaleEffect(0.4 + 1.8 * p).opacity(0.5 * (1 - p))
                } keyframes: { _ in
                    KeyframeTrack {
                        MoveKeyframe(0)
                        LinearKeyframe(1, duration: 1.1, timingCurve: .rift)
                    }
                }
            Canvas { context, canvas in
                context.scaleBy(x: canvas.width / 200, y: canvas.height / 200)
                context.fill(shapes.body, with: .color(rolled ? accent.opacity(0.12) : .white.opacity(0.03)))
                context.stroke(shapes.body, with: .color(accent), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
                context.stroke(shapes.facets, with: .color(accent.opacity(0.35)), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }
            .frame(width: size, height: size)
            .rotationEffect(.degrees(spin))
            .animation(die.rolling ? .linear(duration: 0.16) : .rift(0.9), value: spin)
            Text(die.value.map(String.init) ?? "?")
                .font(RiftFont.display(size * 0.43))
                .foregroundStyle(die.value == nil ? .white.opacity(0.35) : highlight ? accent : .white)
                .fixedSize()
                .id(die.value)
                .transition(.scoreMorph(height: size * 0.43, inDuration: fast ? 0.16 : 0.64, outDuration: fast ? 0.13 : 0.38))
        }
        .frame(width: size, height: size)
        .animation(.rift(fast ? 0.16 : 0.64), value: die.value)
        .onChange(of: landed) { _, now in if now { landings += 1 } }
    }
}

/// One player's side during "who goes first": tap the half to roll.
struct DuelHalf: View {
    let name: String
    let kind: FirstRoll.DieKind
    let die: FirstRoll.Die
    let accent: Color
    let hint: String?
    let head: String?
    let headInk: Color
    let choosing: Bool
    let highlight: Bool
    var dieSize: CGFloat = 190
    let onRoll: () -> Void
    let onFirst: () -> Void
    let onSecond: () -> Void

    var body: some View {
        GeometryReader { geo in
            // On a short half the die gives way, so the first / second pills keep their height: 150pt is the
            // name, the verdict, the pills and the gaps between them.
            let fitted = max(96, min(dieSize, geo.size.height - 150))
            VStack(spacing: 0) {
                Text(name.uppercased()).caps(11, tracking: 0.16).foregroundStyle(.white.opacity(0.78))
                DieGraphic(kind: kind, die: die, accent: accent, highlight: highlight, size: fitted)
                    .padding(.top, 14)
                if let hint {
                    Text(hint).font(RiftFont.text(14, .semibold)).foregroundStyle(.white.opacity(0.72)).padding(.top, 16)
                }
                if let head {
                    Text(head)
                        .font(RiftFont.display(32))
                        .tracking(32 * 0.06)
                        .foregroundStyle(headInk)
                        .padding(.top, 12)
                        .softIn(duration: 0.9)
                }
                if choosing {
                    HStack(spacing: 8) {
                        Pill(text: "I go first", height: 54, fullWidth: true, fill: accent, ink: accent.ink, font: RiftFont.text(15, .bold), action: onFirst)
                        Pill(text: "I go second", height: 54, fullWidth: true, fill: .black.opacity(0.4), stroke: .white.opacity(0.2), font: RiftFont.text(15, .bold), action: onSecond)
                    }
                    .padding(.top, 14)
                    .softIn(delay: 0.2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onRoll)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Roll") { onRoll() }
        .accessibilityLabel("\(name), tap to roll")
    }
}

/// "Darius starts": the roll's verdict across the seam, with Roll again / Start the game.
struct DuelBanner: View {
    let title: String
    let text: String
    let accent: Color
    let onAgain: () -> Void
    let onStart: () -> Void
    @State private var shown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(RiftFont.display(28)).tracking(28 * 0.04).foregroundStyle(accent)
            Text(text).font(RiftFont.text(13)).lineSpacing(4).foregroundStyle(.white.opacity(0.72))
            HStack(spacing: 8) {
                Pill(text: "Roll again", fullWidth: true, action: onAgain)
                Pill(text: "Start the game", fullWidth: true, fill: accent, ink: accent.ink, action: onStart)
            }
        }
        .padding(16)
        .background(Color(hex: "0C0C0C").opacity(0.97), in: RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.16), lineWidth: 1))
        .opacity(shown ? 1 : 0)
        .scaleEffect(shown ? 1 : 0.95)
        .onAppear { withAnimation(.rift(0.52)) { shown = true } }
    }
}

struct DieKindSwitch: View {
    let kind: FirstRoll.DieKind
    let enabled: Bool
    let onPick: (FirstRoll.DieKind) -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 18)
                .fill(.white)
                .frame(width: 49, height: 36)
                .offset(x: kind == .d20 ? 0 : 49)
                .animation(.rift(0.5), value: kind)
            HStack(spacing: 0) {
                ForEach(FirstRoll.DieKind.allCases, id: \.self) { option in
                    Button { onPick(option) } label: {
                        Text(option.label)
                            .font(RiftFont.display(14, weight: 800))
                            .tracking(14 * 0.06)
                            .foregroundStyle(option == kind ? .black : .white.opacity(0.8))
                            .frame(width: 49, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressScale())
                    .disabled(!enabled)
                    .accessibilityLabel(option.label)
                    .accessibilityAddTraits(option == kind ? .isSelected : [])
                }
            }
        }
        .padding(3)
        .frame(width: 104, height: 42)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 21))
    }
}
