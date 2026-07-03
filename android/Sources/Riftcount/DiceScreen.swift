import SwiftUI

/// Dice roller, ported from the iOS DiceView.
/// Shake-to-roll is omitted on Android (no accelerometer bridge); the die
/// itself and the Roll button both roll.
enum DieType: Int, CaseIterable, Identifiable {
    case d6 = 6
    case d8 = 8
    case d12 = 12
    case d20 = 20

    var id: Int { rawValue }
    var label: String { "D\(rawValue)" }

    /// Number of edges of the polygon used to represent this die.
    var faceSides: Int {
        switch self {
        case .d6: return 4    // flat rounded square
        case .d8: return 4    // rotated square (diamond)
        case .d12: return 5   // pentagon
        case .d20: return 8   // octagon (stop-sign style)
        }
    }

    /// Rotation in degrees applied to the face polygon for visual orientation.
    var faceRotation: Double {
        switch self {
        case .d6: return 45     // square sides horizontal/vertical
        case .d8: return 0      // diamond (vertex up)
        case .d12: return 0     // pentagon point up
        case .d20: return 22.5  // octagon flat top
        }
    }
}

struct DiceScreen: View {
    @AppStorage("diceType") var diceTypeRaw: Int = 6

    @State var value: Int = 1
    @State var isRolling: Bool = false
    @State var rollScale: CGFloat = 1.0

    private var selectedDie: DieType {
        DieType(rawValue: diceTypeRaw) ?? .d6
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Dice")
                .font(.title2.bold())

            SegmentedControl(selection: $diceTypeRaw,
                             options: DieType.allCases.map { ($0.label, $0.rawValue) })
            .padding(.horizontal)
            .onChange(of: diceTypeRaw) { (_: Int, _: Int) in
                value = 1
            }

            Button { roll() } label: {
                DieFace(die: selectedDie, value: value, rollScale: rollScale)
                    .frame(width: 220, height: 220)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)

            Button {
                roll()
            } label: {
                Text("Roll")
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear {
            // Migrate legacy D4/D10 selections to D6.
            if DieType(rawValue: diceTypeRaw) == nil {
                diceTypeRaw = DieType.d6.rawValue
            }
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
        let hops = Int.random(in: 11...14)

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

struct DieFace: View {
    let die: DieType
    let value: Int
    let rollScale: CGFloat

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.22),
                Color.white.opacity(0.06),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
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
                    .shadow(color: Color.black.opacity(0.25), radius: 12, y: 6)
                    .rotationEffect(Angle(degrees: die.faceRotation))

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
struct RegularPolygon: Shape {
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
            let p1 = CGPoint(x: curr.x + v1.0 * cornerRadius,
                             y: curr.y + v1.1 * cornerRadius)
            if i == 0 { path.move(to: p1) } else { path.addLine(to: p1) }
            path.addQuadCurve(
                to: CGPoint(x: curr.x + v2.0 * cornerRadius,
                            y: curr.y + v2.1 * cornerRadius),
                control: curr
            )
        }
        path.closeSubpath()
        return path
    }

    // Tuple instead of CGVector: its initializer is internal in the Swift
    // Android SDK's Foundation.
    private func unitVector(from a: CGPoint, to b: CGPoint) -> (CGFloat, CGFloat) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len = max(sqrt(dx * dx + dy * dy), 0.0001)
        return (dx / len, dy / len)
    }
}
