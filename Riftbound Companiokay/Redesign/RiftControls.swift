//
//  RiftControls.swift
//  Riftbound Companiokay
//
//  The redesign's small controls (Android `ui/common`): pills, round icons, the lit press of the score
//  buttons, the mocks' soft and rising entrances, the swipe back from the left edge.
//

import SwiftUI
import UIKit

/// Shrinks a little while pressed (the mocks' `:active { scale(.94) }`), no highlight.
struct PressScale: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.rift(0.25), value: configuration.isPressed)
    }
}

/// Lights up under the finger and fades out after the tap (Okay: every tap needs an answer); `label`
/// draws the button for a light of 0 to 1.
struct LitButton<Label: View>: View {
    let accessibility: String
    var enabled = true
    /// 1 for Liquid Glass, which answers the press itself.
    var pressedScale: CGFloat = 0.94
    let action: () -> Void
    @ViewBuilder let label: (CGFloat) -> Label

    var body: some View {
        Button(action: action) { EmptyView() }
            .buttonStyle(LitStyle(pressedScale: pressedScale, label: label))
            .disabled(!enabled)
            .accessibilityLabel(accessibility)
    }
}

private struct LitStyle<Label: View>: ButtonStyle {
    let pressedScale: CGFloat
    let label: (CGFloat) -> Label

    func makeBody(configuration: Configuration) -> some View {
        label(configuration.isPressed ? 1 : 0)
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(configuration.isPressed ? .linear(duration: 0.06) : .rift(0.52), value: configuration.isPressed)
    }
}

/// Rounded pill button: filled (`fill`) or ghost (translucent white).
struct Pill: View {
    let text: String
    var height: CGFloat = 46
    var fullWidth = false
    var fill: Color = .white.opacity(0.10)
    var ink: Color = .white
    var stroke: Color? = nil
    var font: Font = RiftFont.text(14, .semibold)
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(font)
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 14)
                .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: height, maxHeight: height)
                .background(fill, in: Capsule())
                .overlay { if let stroke { Capsule().stroke(stroke, lineWidth: 1) } }
                .contentShape(Capsule())
        }
        .buttonStyle(PressScale())
        .opacity(enabled ? 1 : 0.4)
        .disabled(!enabled)
    }
}

/// Round icon button of the seam (42pt, white 10%).
struct RoundIcon: View {
    let symbol: String
    let label: String
    var tint: Color = .white
    var fill: Color = .white.opacity(0.10)
    var size: CGFloat = 42
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(fill, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(PressScale())
        .opacity(enabled ? 1 : 0.35)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

/// A short note in a dark capsule, rising into place.
struct HalfToast: View {
    let text: String

    var body: some View {
        Text(text)
            .font(RiftFont.text(13))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: "0E0E0E").opacity(0.96), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
            .rise()
    }
}

/// The mocks' "soft" entrance: up from 18pt, from a blur of 10 to sharp.
private struct SoftIn: ViewModifier {
    let delay: Double
    let duration: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 18)
            .blur(radius: shown ? 0 : 10)
            .onAppear { withAnimation(.rift(duration).delay(delay)) { shown = true } }
    }
}

/// Sheets and toasts rise 24pt into place.
private struct Rise: ViewModifier {
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 24)
            .onAppear { withAnimation(.rift(0.65)) { shown = true } }
    }
}

extension View {
    func softIn(delay: Double = 0, duration: Double = 0.9) -> some View {
        modifier(SoftIn(delay: delay, duration: duration))
    }

    func rise() -> some View { modifier(Rise()) }

    /// Lists and text stay readable on an iPad: at most 700pt wide, centred.
    func readableWidth(_ limit: CGFloat = 700) -> some View { frame(maxWidth: limit).frame(maxWidth: .infinity) }

    /// Caps labels of the mocks: Barlow with wide tracking.
    func caps(_ size: CGFloat = 11, tracking: CGFloat = 0.14, weight: Font.Weight = .semibold) -> some View {
        font(RiftFont.text(size, weight)).tracking(size * tracking)
    }
}

/// The system's swipe back from the left edge, for screens that open over a tab instead of being pushed
/// (Okay, 2026-10-26: Cards and Decks had none). A screen-edge recognizer leaves taps and scrolling alone;
/// it goes back once the finger has come 60pt in, or on a quick flick.
private struct EdgeSwipe: UIGestureRecognizerRepresentable {
    let enabled: Bool
    let action: () -> Void

    /// Next to the scroll views and buttons underneath: alone, it could lose the touch to a scroll view's pan.
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIScreenEdgePanGestureRecognizer {
        let pan = UIScreenEdgePanGestureRecognizer()
        pan.edges = .left
        pan.delegate = context.coordinator
        return pan
    }

    func updateUIGestureRecognizer(_ pan: UIScreenEdgePanGestureRecognizer, context: Context) {
        pan.isEnabled = enabled
    }

    func handleUIGestureRecognizerAction(_ pan: UIScreenEdgePanGestureRecognizer, context: Context) {
        let moved = pan.translation(in: pan.view).x
        let flick = pan.velocity(in: pan.view).x > 600
        guard (pan.state == .changed && moved > 60) || (pan.state == .ended && moved > 20 && flick) else { return }
        // Ends this swipe, so it goes back one step only.
        pan.isEnabled = false
        pan.isEnabled = enabled
        action()
    }
}

extension View {
    /// Back by a swipe in from the left edge while `enabled`. Always attached, so switching it on and off
    /// never rebuilds the screen underneath.
    func edgeSwipeBack(enabled: Bool, _ action: @escaping () -> Void) -> some View {
        gesture(EdgeSwipe(enabled: enabled, action: action))
    }
}
