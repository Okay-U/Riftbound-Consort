//
//  HalfParts.swift
//  Riftbound Companiokay
//
//  The pieces of a scoreboard half (Android `HalfParts.kt`): the top line with name, GOES FIRST and XP;
//  the four action pills; the win text; the questions that wait on a half.
//

import SwiftUI

struct TopLine: View {
    let legend: String
    let accent: Color
    let starter: Bool
    let xp: Int
    let onXp: (Int) -> Void
    var shown = true
    var onName: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                name
                if starter {
                    Text("GOES FIRST")
                        .caps(9.5, tracking: 0.1, weight: .bold)
                        .foregroundStyle(accent.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accent, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .layoutPriority(-1)
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                Text("XP \(xp)")
                    .font(RiftFont.text(12, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.84))
                XpButton(text: "−", label: "Spend one XP", enabled: shown, accent: accent) { onXp(-1) }
                XpButton(text: "+", label: "Gain one XP", enabled: shown, accent: accent) { onXp(1) }
            }
        }
        // Fades out once the game is decided, like the mock's `.ended .topline`.
        .opacity(shown ? 1 : 0)
        .animation(.easeInOut(duration: 0.5), value: shown)
    }

    @ViewBuilder private var name: some View {
        let text = Text(legend.uppercased())
            .caps(11)
            .foregroundStyle(.white.opacity(0.78))
            .lineLimit(1)
        if let onName {
            // The name opens the game setup (deck, opponent), like the classic deck pill.
            Button(action: onName) { text.padding(.vertical, 6) }
                .buttonStyle(PressScale(scale: 0.96))
                .accessibilityLabel("Change \(legend)")
        } else {
            text
        }
    }
}

private struct XpButton: View {
    let text: String
    let label: String
    let enabled: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        LitButton(accessibility: label, enabled: enabled, action: action) { lit in
            Text(text)
                .font(RiftFont.text(15, .semibold))
                .foregroundStyle(Color.white.mix(with: accent.ink, by: lit))
                .frame(width: 30, height: 30)
                .background(Color.black.opacity(0.35).mix(with: accent, by: 0.9 * lit), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.24).mix(with: accent, by: lit), lineWidth: 1))
                .contentShape(Circle())
        }
    }
}

struct ActionRow: View {
    let accent: Color
    /// Bumped by a tap on the score: the +1 pills light up one after the other (Okay, 2026-10-26).
    var cue = 0
    let onConquer: () -> Void
    let onHold: () -> Void
    let onEffect: () -> Void
    let onFix: () -> Void

    var body: some View {
        GlassGroup(spacing: 8) {
            HStack(spacing: 8) {
                ActionButton(title: "Conquer", delta: "+1", label: "Conquer, plus one point", filled: true, accent: accent, cue: cue, wave: 0, action: onConquer)
                ActionButton(title: "Hold", delta: "+1", label: "Hold, plus one point", filled: false, accent: accent, cue: cue, wave: 1, action: onHold)
                ActionButton(title: "Effect", delta: "+1", label: "Card effect, plus one point", filled: false, accent: accent, cue: cue, wave: 2, action: onEffect)
                ActionButton(title: "Fix", delta: "−1", label: "Correct, minus one point", filled: false, accent: accent, action: onFix)
            }
        }
    }
}

/// Liquid Glass shapes that sit close together render as one group on iOS 26.
private struct GlassGroup<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}

/// Four players: the same four actions as a 2×2 grid, so the labels fit a quarter of the table.
struct ActionGrid: View {
    let accent: Color
    var cue = 0
    let onConquer: () -> Void
    let onHold: () -> Void
    let onEffect: () -> Void
    let onFix: () -> Void

    var body: some View {
        GlassGroup(spacing: 6) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    ActionButton(title: "Conquer", delta: "+1", label: "Conquer, plus one point", filled: true, accent: accent, height: 40, cue: cue, wave: 0, action: onConquer)
                    ActionButton(title: "Hold", delta: "+1", label: "Hold, plus one point", filled: false, accent: accent, height: 40, cue: cue, wave: 1, action: onHold)
                }
                HStack(spacing: 6) {
                    ActionButton(title: "Effect", delta: "+1", label: "Card effect, plus one point", filled: false, accent: accent, height: 40, cue: cue, wave: 2, action: onEffect)
                    ActionButton(title: "Fix", delta: "−1", label: "Correct, minus one point", filled: false, accent: accent, height: 40, action: onFix)
                }
            }
        }
    }
}

/// Conquer is filled in the half's colour and glows; the others light up in it for a moment when tapped.
/// Liquid Glass on iOS 26 (Okay, 2026-10-22), the mock's capsules before. A tap on the score lights the
/// +1 pills the same way, a wave from Conquer on (`cue`, `wave`): points go here, not on the number.
private struct ActionButton: View {
    let title: String
    let delta: String
    let label: String
    let filled: Bool
    let accent: Color
    var height: CGFloat = 54
    var cue = 0
    /// Its place in the wave; nil stays out of it (Fix).
    var wave: Int? = nil
    let action: () -> Void
    @State private var nudge: CGFloat = 0

    var body: some View {
        button
            .scaleEffect(1 + 0.05 * nudge)
            .onChange(of: cue) {
                guard let wave else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(90 * wave))
                    withAnimation(.easeOut(duration: 0.16)) { nudge = 1 }
                    try? await Task.sleep(for: .milliseconds(180))
                    withAnimation(.rift(0.7)) { nudge = 0 }
                }
            }
    }

    @ViewBuilder private var button: some View {
        if #available(iOS 26, *) {
            LitButton(accessibility: label, pressedScale: 1, action: action) { pressed in
                let lit = max(pressed, nudge)
                face(color: filled ? accent.ink : .white)
                    .glassEffect(.regular.tint(filled ? accent : accent.opacity(0.9 * lit)).interactive(), in: Capsule())
                    .shadow(color: accent.opacity(glow(lit)), radius: 13 + 6 * lit)
            }
        } else {
            LitButton(accessibility: label, action: action) { pressed in
                let lit = max(pressed, nudge)
                face(color: filled ? accent.ink : Color.white.mix(with: accent.ink, by: lit))
                    .background {
                        Capsule()
                            .fill(filled ? accent.mix(with: .white, by: 0.3 * lit) : Color.black.opacity(0.38).mix(with: accent, by: 0.9 * lit))
                            .shadow(color: accent.opacity(glow(lit)), radius: 13 + 6 * lit)
                    }
                    .overlay {
                        if !filled { Capsule().stroke(Color.white.opacity(0.2).mix(with: accent, by: lit), lineWidth: 1) }
                    }
            }
        }
    }

    private func face(color: Color) -> some View {
        VStack(spacing: 0) {
            Text(title).font(RiftFont.text(13, .semibold))
            Text(delta).font(RiftFont.text(10, .medium)).opacity(filled ? 0.62 : 0.66)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .contentShape(Capsule())
    }

    private func glow(_ lit: CGFloat) -> Double { filled ? 0.45 + 0.35 * lit : 0.5 * lit }
}

/// "WIN · 8–3" over the winner's half, softly in after the line has swept.
struct ResultText: View {
    let title: String
    let sub: String
    let accent: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(RiftFont.display(52)).tracking(52 * 0.16).foregroundStyle(accent)
            Text(sub).font(RiftFont.text(13)).foregroundStyle(.white.opacity(0.82))
        }
        .softIn(delay: 0.25, duration: 1.3)
    }
}

/// A question that waits on a half: the conquering 8th point, or who starts after a lost game.
struct HalfQuestion: View {
    let title: String
    let text: String
    let yes: String
    let no: String
    let accent: Color
    let onYes: () -> Void
    let onNo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(RiftFont.text(16, .bold)).foregroundStyle(.white)
            Text(text)
                .font(RiftFont.text(13))
                .lineSpacing(4)
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            HStack(spacing: 8) {
                Pill(text: yes, fullWidth: true, fill: accent, ink: accent.ink, action: onYes)
                Pill(text: no, fullWidth: true, action: onNo)
            }
            .padding(.top, 14)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "0E0E0E").opacity(0.96), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.14), lineWidth: 1))
        .rise()
    }

    static func finalPoint(accent: Color, onYes: @escaping () -> Void, onNo: @escaping () -> Void) -> HalfQuestion {
        HalfQuestion(
            title: "Final point by conquering",
            text: "It only counts if you already scored every other battlefield this turn. Otherwise you draw a card instead.",
            yes: "Yes, score it", no: "No, draw a card", accent: accent, onYes: onYes, onNo: onNo
        )
    }

    /// After a lost game Riftbound lets the loser pick who starts the next one.
    static func startChoice(accent: Color, onFirst: @escaping () -> Void, onSecond: @escaping () -> Void) -> HalfQuestion {
        HalfQuestion(
            title: "Go first or second?",
            text: "You lost the last game, so you choose who starts this one.",
            yes: "I go first", no: "I go second", accent: accent, onYes: onFirst, onNo: onSecond
        )
    }
}

struct NextGameButton: View {
    let text: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Pill(text: text, height: 54, fullWidth: true, fill: accent, ink: accent.ink, font: RiftFont.text(15, .bold), action: action)
            .softIn(delay: 0.6, duration: 1.0)
    }
}
