//
//  EventsTheme.swift
//  Riftbound Companiokay
//
//  Design tokens + reusable building blocks for the Events tab redesign ("Arena").
//  Dark, true-black native. Accent is GREEN only (the same green as the Decks
//  win-rate bar) — no blue/purple in Events content; gold is reserved for the
//  round-winner crown. No image assets: every icon is an SF Symbol, every glow a
//  gradient.
//

import SwiftUI

nonisolated enum EventsTheme {
    // Surfaces
    static let bg        = Color.black
    static let card      = Color(red: 0.086, green: 0.086, blue: 0.094) // #161618 elevated card
    static let cardInset = Color(red: 0.059, green: 0.059, blue: 0.067) // #0F0F11 nested tile
    static let hairline  = Color.white.opacity(0.06)

    // Text
    static let textPrimary   = Color.white
    static let textSecondary = Color(red: 0.557, green: 0.557, blue: 0.576) // #8E8E93
    static let textTertiary  = Color(red: 0.388, green: 0.388, blue: 0.4)   // #636366

    // Accent — GREEN only. Matches the app's win-rate / legal-deck green.
    static let green     = Color.green
    static let greenSoft = Color.green.opacity(0.16)
    static let gold      = Color(red: 1.0, green: 0.839, blue: 0.039) // #FFD60A — round-winner crown only

    // Green-tinted gradient fills (used inside the green-bordered "your match" cards)
    static let matchFillTop    = Color(red: 0.055, green: 0.122, blue: 0.078) // #0E1F14
    static let matchFillBottom = Color(red: 0.047, green: 0.059, blue: 0.102) // #0C0F1A
    // Neutral dark gradient fill (event overview card)
    static let overviewFillTop    = Color(red: 0.082, green: 0.090, blue: 0.122) // #15171F
    static let overviewFillBottom = Color(red: 0.055, green: 0.059, blue: 0.075) // #0E0F13

    // Radii
    static let cardRadius: CGFloat = 18
    static let pillRadius: CGFloat = 15
    static let ctaRadius:  CGFloat = 16
    static let chipRadius: CGFloat = 7
}

// MARK: - Reusable building blocks

extension View {
    /// Elevated card / row background: dark fill, continuous corners, hairline border.
    func eventsCard(radius: CGFloat = EventsTheme.cardRadius) -> some View {
        self
            .background(EventsTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(EventsTheme.hairline, lineWidth: 1)
            )
    }

    /// Green gradient border wrapping a dark green-tinted fill — the "your match" treatment.
    func greenGradientBorder(radius: CGFloat = EventsTheme.cardRadius) -> some View {
        self
            .background(
                LinearGradient(colors: [EventsTheme.matchFillTop, EventsTheme.matchFillBottom],
                               startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .padding(1.5)
            .background(
                LinearGradient(colors: [EventsTheme.green, EventsTheme.green.opacity(0.5)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius + 1.5, style: .continuous))
    }
}

/// Small green "LIVE" pill, optionally with a pulsing dot.
struct LiveBadge: View {
    var pulsing = false
    @State private var on = false

    var body: some View {
        HStack(spacing: 5) {
            if pulsing {
                Circle()
                    .fill(EventsTheme.green)
                    .frame(width: 6, height: 6)
                    .opacity(on ? 0.3 : 1)
                    .scaleEffect(on ? 0.7 : 1)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: on)
                    .onAppear { on = true }
            }
            Text("LIVE").font(.system(size: 10, weight: .bold)).tracking(0.4)
        }
        .foregroundStyle(EventsTheme.green)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(EventsTheme.greenSoft, in: Capsule())
    }
}

/// Uppercase section header with a leading SF Symbol, optional trailing accessory.
struct SectionHeader<Trailing: View>: View {
    let symbol: String
    let title: String
    @ViewBuilder var trailing: Trailing

    init(_ symbol: String, _ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.symbol = symbol
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
            Text(title).tracking(0.4).textCase(.uppercase)
            Spacer(minLength: 8)
            trailing
        }
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(EventsTheme.textSecondary)
    }
}
