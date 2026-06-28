//
//  EventsOnboardingView.swift
//  Riftbound Companiokay
//
//  Contextual tour for the Events tab + tournament features, shown the first
//  time the Events tab is opened (gate: "didOnboardEvents"). Styled to match the
//  Events "Arena" look (dark, green-only accent, glow) rather than the generic
//  first-launch tour. Skippable; replayable from Settings.
//

import SwiftUI

struct EventsOnboardingView: View {
    @AppStorage("didOnboardEvents") private var didOnboardEvents = false
    @AppStorage("batterySaver") private var batterySaver = false
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0

    private let pages = EventsOnboardingPage.all

    var body: some View {
        ZStack(alignment: .topTrailing) {
            EventsTheme.bg.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { i, page in
                    EventsOnboardingPageView(page: page, batterySaver: batterySaver)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 18) {
                Spacer()
                dots
                cta
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)

            if !isLast { skip }
        }
    }

    // MARK: - Controls

    private var skip: some View {
        Button("Skip") { finish() }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(EventsTheme.textSecondary)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(EventsTheme.card, in: Capsule())
            .overlay(Capsule().stroke(EventsTheme.hairline, lineWidth: 1))
            .padding(.top, 14).padding(.trailing, 18)
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(pages.indices, id: \.self) { i in
                Capsule()
                    .fill(i == index ? EventsTheme.green : EventsTheme.textTertiary.opacity(0.5))
                    .frame(width: i == index ? 22 : 7, height: 7)
                    .animation(.easeInOut(duration: 0.2), value: index)
            }
        }
    }

    private var cta: some View {
        Button(action: advance) {
            Text(isLast ? "Get Started" : "Next")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(
                    LinearGradient(colors: [EventsTheme.green, EventsTheme.green.opacity(0.75)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: EventsTheme.ctaRadius, style: .continuous)
                )
                .shadow(color: batterySaver ? .clear : EventsTheme.green.opacity(0.35), radius: 16, y: 8)
        }
    }

    private var isLast: Bool { index == pages.count - 1 }

    private func advance() {
        if isLast { finish() }
        else { withAnimation { index += 1 } }
    }

    private func finish() {
        didOnboardEvents = true
        dismiss()
    }
}

// MARK: - Page

private struct EventsOnboardingPageView: View {
    let page: EventsOnboardingPage
    let batterySaver: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                hero
                VStack(spacing: 8) {
                    Text(page.title)
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(page.subtitle)
                        .font(.system(size: 15))
                        .foregroundStyle(EventsTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(page.bullets) { bullet in
                        bulletRow(bullet)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 6)

                Spacer(minLength: 150)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        }
    }

    private var hero: some View {
        ZStack {
            if !batterySaver {
                RadialGradient(colors: [EventsTheme.green.opacity(0.35), .clear],
                               center: .center, startRadius: 0, endRadius: 110)
                    .frame(width: 220, height: 220)
                    .allowsHitTesting(false)
            }
            Circle()
                .fill(EventsTheme.greenSoft)
                .frame(width: 100, height: 100)
                .overlay(Circle().stroke(EventsTheme.green.opacity(0.4), lineWidth: 1))
            Image(systemName: page.symbol)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(EventsTheme.green)
        }
    }

    private func bulletRow(_ bullet: EventsOnboardingBullet) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: bullet.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(EventsTheme.green)
                .frame(width: 38, height: 38)
                .background(EventsTheme.greenSoft, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(bullet.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(bullet.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(EventsTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Content

private struct EventsOnboardingBullet: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let detail: String
}

private struct EventsOnboardingPage: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let subtitle: String
    let bullets: [EventsOnboardingBullet]

    static let all: [EventsOnboardingPage] = [
        EventsOnboardingPage(
            symbol: "trophy.fill",
            title: "Events",
            subtitle: "Your tournament companion for Riftbound.",
            bullets: [
                .init(symbol: "calendar.badge.clock", title: "Follow your events",
                      detail: "Standings, pairings and results, live."),
                .init(symbol: "building.2.fill", title: "Find local stores",
                      detail: "Search, save favorites, see their calendar."),
                .init(symbol: "gamecontroller.fill", title: "Play connected",
                      detail: "Link a tournament match to your Scoreboard.")
            ]
        ),
        EventsOnboardingPage(
            symbol: "lock.shield.fill",
            title: "Sign in",
            subtitle: "Use your Riftbound Locator account.",
            bullets: [
                .init(symbol: "envelope.fill", title: "Email login",
                      detail: "The same account as locator.riftbound.uvsgames.com."),
                .init(symbol: "lock.fill", title: "Your password is never stored",
                      detail: "We keep only a secure login token on your device."),
                .init(symbol: "person.crop.circle", title: "Sign out anytime",
                      detail: "From the account menu in the Events tab.")
            ]
        ),
        EventsOnboardingPage(
            symbol: "building.2.fill",
            title: "Find your stores",
            subtitle: "Discover and save the shops you play at.",
            bullets: [
                .init(symbol: "magnifyingglass", title: "Search by city",
                      detail: "See nearby stores on a list or map."),
                .init(symbol: "heart.fill", title: "Save favorites",
                      detail: "Tap the heart on any store."),
                .init(symbol: "calendar", title: "Store Calendar",
                      detail: "Every event at your saved stores, by date.")
            ]
        ),
        EventsOnboardingPage(
            symbol: "ticket.fill",
            title: "Register in seconds",
            subtitle: "Sign up for events right here.",
            bullets: [
                .init(symbol: "list.bullet.rectangle", title: "Browse events",
                      detail: "Upcoming, live and past."),
                .init(symbol: "checkmark.circle.fill", title: "Sign up",
                      detail: "Register and pay in person at the store."),
                .init(symbol: "xmark.circle", title: "Drop anytime",
                      detail: "Change your mind with one tap.")
            ]
        ),
        EventsOnboardingPage(
            symbol: "person.2.shield.fill",
            title: "Live, in the app",
            subtitle: "No more juggling the website during rounds.",
            bullets: [
                .init(symbol: "chair.fill", title: "Pairings and your table",
                      detail: "Know exactly where to sit each round."),
                .init(symbol: "list.number", title: "Live standings",
                      detail: "Track your place as rounds finish."),
                .init(symbol: "square.and.pencil", title: "Report results",
                      detail: "Submit your match without leaving the app."),
                .init(symbol: "chart.bar.doc.horizontal", title: "Can I draw?",
                      detail: "Your top-cut outlook, shown automatically.")
            ]
        ),
        EventsOnboardingPage(
            symbol: "gamecontroller.fill",
            title: "Match mode",
            subtitle: "Score and report from the Scoreboard.",
            bullets: [
                .init(symbol: "switch.2", title: "Turn it on in Settings",
                      detail: "Under the Tournament section."),
                .init(symbol: "chair.fill", title: "Table and opponent",
                      detail: "Shown right on your Scoreboard."),
                .init(symbol: "square.and.pencil", title: "Report on the spot",
                      detail: "Send your result the moment you finish.")
            ]
        )
    ]
}

#Preview {
    EventsOnboardingView()
}
