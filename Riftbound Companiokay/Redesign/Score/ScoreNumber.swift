//
//  ScoreNumber.swift
//  Riftbound Companiokay
//
//  The big number of a half (the mock's "Flow"): the old value blurs up and away, the new one rises in and
//  sharpens, a drop of colour spreads on every point. A won game lifts and shrinks it.
//

import SwiftUI

struct ScoreNumber: View {
    let value: Int
    let accent: Color
    let won: Bool
    let label: String
    var showTarget = true
    var size: CGFloat = 188

    var body: some View {
        ZStack {
            ScoreDrop(value: value, accent: accent, size: size * 0.8)
            Text("\(value)")
                .font(RiftFont.display(size))
                .foregroundStyle(.white)
                .fixedSize()
                .id(value)
                .transition(.scoreMorph(height: size))
        }
        .frame(width: size * 1.38, height: size * 1.04)
        .overlay(alignment: .bottom) {
            if showTarget {
                Text("OF \(ScoreState.target)")
                    .caps(12, tracking: 0.2, weight: .regular)
                    .foregroundStyle(.white.opacity(0.7))
                    .offset(y: 10)
            }
        }
        .scaleEffect(won ? 0.68 : 1)
        .offset(y: won ? 60 : 0)
        .animation(.rift(1.1), value: won)
        .animation(.rift(0.95), value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}

/// The soft ring of colour behind the number on every point (not on the first show).
private struct ScoreDrop: View {
    let value: Int
    let accent: Color
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(accent)
            .frame(width: size, height: size)
            .keyframeAnimator(initialValue: CGFloat(1), trigger: value) { drop, p in
                drop.scaleEffect(0.3 + 2.3 * p).opacity(0.4 * (1 - p))
            } keyframes: { _ in
                KeyframeTrack {
                    MoveKeyframe(0)
                    LinearKeyframe(1, duration: 1.2, timingCurve: .rift)
                }
            }
            .allowsHitTesting(false)
    }
}

private struct Morph: ViewModifier {
    let blur: CGFloat
    let dy: CGFloat
    let scale: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content.blur(radius: blur).scaleEffect(scale).offset(y: dy).opacity(opacity)
    }
}

extension AnyTransition {
    /// In from below, blurred and a little large; out upwards, blurred and a little small.
    static func scoreMorph(height: CGFloat, inDuration: Double = 0.95, outDuration: Double = 0.65) -> AnyTransition {
        let identity = Morph(blur: 0, dy: 0, scale: 1, opacity: 1)
        return .asymmetric(
            insertion: .modifier(active: Morph(blur: 14, dy: height * 0.24, scale: 1.05, opacity: 0), identity: identity)
                .animation(.rift(inDuration)),
            removal: .modifier(active: Morph(blur: 12, dy: -height * 0.26, scale: 0.92, opacity: 0), identity: identity)
                .animation(.timingCurve(0.4, 0, 0.2, 1, duration: outDuration))
        )
    }
}
