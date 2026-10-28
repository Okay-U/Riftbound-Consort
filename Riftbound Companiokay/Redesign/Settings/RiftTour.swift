//
//  RiftTour.swift
//  Riftbound Companiokay
//
//  The first-launch tour (classic `OnboardingView`, six pages, `didOnboard`), the Events tour (classic
//  `EventsOnboardingView`, `didOnboardEvents`) and the 4.0 What's new card (`didSeeWhatsNew40`, once for people who
//  update) in the redesign (Android `Tour.kt`): swipe or Next, Skip until the last page, each page rising in the
//  first time it shows.
//

import SwiftUI

enum TourKind: Identifiable {
    case main, events, whatsNew
    var id: Self { self }
}

private struct TourPage {
    let symbol: String
    let accent: Color
    let title: String
    let subtitle: String
    let points: [(String, String)]
}

/// The tour as a full-screen cover: done closes it and marks it seen.
struct RiftTour: View {
    let kind: TourKind
    @Environment(\.dismiss) private var dismiss
    @Environment(\.riftPage) private var page
    @AppStorage("didOnboard") private var didOnboard = false
    @AppStorage("didOnboardEvents") private var didOnboardEvents = false
    @AppStorage("didSeeWhatsNew40") private var didSeeWhatsNew = false
    @State private var current = 0
    /// Pages already shown rise in only the first time; the first one as the tour appears.
    @State private var seen: Set<Int> = []

    var body: some View {
        let pages = switch kind {
        case .main: Self.mainPages
        case .events: Self.eventsPages
        case .whatsNew: Self.whatsNewPages
        }
        let last = current == pages.count - 1
        let accent = pages[current].accent
        ZStack(alignment: .top) {
            page.ignoresSafeArea()
            TabView(selection: $current) {
                ForEach(pages.indices, id: \.self) { i in
                    PageView(page: pages[i], shown: seen.contains(i)).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)
            HStack {
                Spacer()
                Button("Skip", action: finish)
                    .font(RiftFont.text(14, .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.06), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
                    .opacity(last ? 0 : 1)
                    .disabled(last)
                    .animation(.easeInOut(duration: 0.3), value: last)
            }
            .padding(.top, 14)
            .padding(.horizontal, 18)
            VStack(spacing: 18) {
                Spacer()
                if pages.count > 1 {
                    HStack(spacing: 7) {
                        ForEach(pages.indices, id: \.self) { i in
                            Capsule()
                                .fill(i == current ? accent : .white.opacity(0.3))
                                .frame(width: i == current ? 22 : 7, height: 7)
                        }
                    }
                    .animation(.rift(0.3), value: current)
                    .accessibilityHidden(true)
                }
                WideButton(text: !last ? "Next" : kind == .whatsNew ? "Continue" : "Get started", fill: RiftColor.you, ink: .black) {
                    if last { finish() } else { withAnimation(.rift(0.5)) { current += 1 } }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .onAppear { seen.insert(current) }
        .onChange(of: current) { _, page in seen.insert(page) }
    }

    private func finish() {
        switch kind {
        case .main:
            didOnboard = true
            // A new install starts on 4.0: there is no update to tell it about.
            didSeeWhatsNew = true
        case .events: didOnboardEvents = true
        case .whatsNew: didSeeWhatsNew = true
        }
        dismiss()
    }

    private static let mainPages = [
        TourPage(symbol: "trophy", accent: RiftColor.gold, title: "Riftcount", subtitle: "Score tracker and more for Riftbound TCG",
                 points: [("See what's new", "with our latest version"), ("Show this app to your friends", "while playing :)")]),
        TourPage(symbol: "rectangle.portrait.bottomhalf.filled", accent: RiftColor.you, title: "Scoreboard", subtitle: "Track every point with one tap",
                 points: [
                    ("Conquer, hold, effect", "One tap per point"),
                    ("Track XP", "Gain and spend XP right on your half"),
                    ("Who goes first", "Roll the dice in the middle, D6 or D20"),
                    ("Reset or end", "Reset Score starts over, or ends a game after a concession"),
                    ("Pick decks", "Tap a name to choose your deck and your opponent's legend"),
                    ("Undo", "Rewind step by step when you misclick"),
                 ]),
        TourPage(symbol: "calendar", accent: RiftColor.opponent, title: "Events", subtitle: "Your tournament companion",
                 points: [
                    ("Follow your events", "Standings, pairings and results, live"),
                    ("Find local stores", "Search, save favorites, see their calendar"),
                    ("Report results directly", "Your table on the Scoreboard, Report sends the result"),
                 ]),
        TourPage(symbol: "rectangle.portrait.on.rectangle.portrait", accent: CardStyle.domainColor("mind"), title: "Cards", subtitle: "Browse the whole pool",
                 points: [
                    ("Search", "Find any card by name, type, or text"),
                    ("Filter & sort", "By domain, type, energy and more"),
                    ("Card view", "Tap any card for full art and details"),
                 ]),
        TourPage(symbol: "square.3.layers.3d", accent: CardStyle.domainColor("body"), title: "Decks", subtitle: "Build, browse, analyze",
                 points: [
                    ("Build wizard", "Legend → champion → battlefields → cards → runes"),
                    ("Draw hand", "Simulate openings with a mulligan"),
                    ("Draw odds", "Chance to draw key cards by turn N"),
                    ("Deck stats", "Energy curve, power by domain, type breakdown"),
                    ("Import / Export", "Copy decklists as text, paste in or share out"),
                 ]),
        TourPage(symbol: "gearshape", accent: RiftColor.you, title: "Make it yours", subtitle: "Tweak in Settings whenever",
                 points: [
                    ("Player colors", "16 colors, one per seat"),
                    ("Legend art", "Your legends' splash art behind the halves"),
                    ("Haptics", "Toggle feedback to taste"),
                    ("True black", "Pure black for OLED screens, or a dark grey"),
                 ]),
    ]

    private static let eventsPages = [
        TourPage(symbol: "trophy", accent: RiftColor.you, title: "Events", subtitle: "Your tournament companion.",
                 points: [
                    ("Find your stores", "Discover and save the shops you play at."),
                    ("Register in seconds", "Sign up for events right here."),
                    ("Live, in the app", "No more juggling the website during rounds."),
                    ("Match mode", "Score and report from the Scoreboard."),
                 ]),
        TourPage(symbol: "lock.shield", accent: RiftColor.you, title: "Sign in", subtitle: "Use your Riot ID on PlayRiftbound.",
                 points: [
                    ("Riot's own pages", "Sign in happens on Riot's own pages; Riftcount never sees or saves your password."),
                    ("Nothing stored by us", "Your session stays in the in-app browser on your device."),
                    ("Sign out anytime", "From the menu in the PlayRiftbound segment."),
                 ]),
    ]

    /// Once, the first time 4.0 opens after an update (Okay's text, 2026-10-28).
    private static let whatsNewPages = [
        TourPage(symbol: "sparkles", accent: RiftColor.gold, title: "Riftcount 4.0", subtitle: "ReDesign Update",
                 points: [
                    ("Scoreboard, Events, Cards, Decks", "have all new looks"),
                    ("Legend art", "Turn it on and your legend and your opponent's show as splash art behind their halves."),
                    ("Cards", "Search by rules text and a shortlist were added."),
                    ("Events", "Again functional with the new platform. Report matches, find events, register, drop, view live standings and pairings."),
                 ]),
    ]
}

private struct PageView: View {
    let page: TourPage
    let shown: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: page.symbol)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(page.accent)
                    .frame(width: 84, height: 84)
                    .background(page.accent.opacity(0.14), in: Circle())
                    .overlay(Circle().stroke(page.accent.opacity(0.4), lineWidth: 1))
                    .shadow(color: page.accent.opacity(0.3), radius: 15)
                    .riseIn(shown, delay: 0)
                Text(page.title).font(RiftFont.display(46)).foregroundStyle(.white).padding(.top, 26).riseIn(shown, delay: 0.08)
                Text(page.subtitle)
                    .font(RiftFont.text(16, .regular))
                    .lineSpacing(4)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 8)
                    .riseIn(shown, delay: 0.14)
                ForEach(Array(page.points.enumerated()), id: \.offset) { i, point in
                    HStack(alignment: .top, spacing: 14) {
                        Circle()
                            .fill(page.accent)
                            .frame(width: 8, height: 8)
                            .shadow(color: page.accent.opacity(0.6), radius: 4)
                            .padding(.top, 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(point.0).font(RiftFont.text(15.5, .semibold)).foregroundStyle(.white)
                            Text(point.1).font(RiftFont.text(13, .regular)).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.top, i == 0 ? 28 : 16)
                    .riseIn(shown, delay: 0.2 + Double(i) * 0.06)
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 76)
            .padding(.bottom, 150)
        }
        .scrollIndicators(.hidden)
    }
}
