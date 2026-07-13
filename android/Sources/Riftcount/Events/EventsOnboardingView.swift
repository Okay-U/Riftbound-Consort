import SwiftUI

/// Contextual tour for the Events tab, ported from iOS. Shown the first time
/// the Events tab is opened (gate: "didOnboardEvents"); replayable from
/// Settings. Arena look: dark, green-only accent, glow. Unmapped SF Symbols
/// swapped for mapped ones or the drawn BuildingGlyph; "map" wording dropped
/// (store search is list-only on Android).
struct EventsOnboardingView: View {
    @AppStorage("didOnboardEvents") var didOnboardEvents = false
    @Environment(\.dismiss) var dismiss
    @State var index = 0

    private let pages = EventsOnboardingPage.all

    var body: some View {
        ZStack(alignment: .topTrailing) {
            EventsTheme.bg.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(pages) { page in
                    EventsOnboardingPageView(page: page)
                        .tag(page.index)
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
        .preferredColorScheme(.dark)
    }

    // MARK: - Controls

    private var skip: some View {
        Button("Skip") { finish() }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(EventsTheme.textSecondary)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(EventsTheme.card))
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
                    RoundedRectangle(cornerRadius: EventsTheme.ctaRadius, style: .continuous)
                        .fill(
                            LinearGradient(colors: [EventsTheme.green, EventsTheme.green.opacity(0.75)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                )
                .shadow(color: EventsTheme.green.opacity(0.35), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
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

struct EventsOnboardingPageView: View {
    let page: EventsOnboardingPage

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
            RadialGradient(colors: [EventsTheme.green.opacity(0.35), .clear],
                           center: .center, startRadius: 0, endRadius: 110)
                .frame(width: 220, height: 220)
                .allowsHitTesting(false)
            Circle()
                .fill(EventsTheme.greenSoft)
                .frame(width: 100, height: 100)
                .overlay(Circle().stroke(EventsTheme.green.opacity(0.4), lineWidth: 1))
            heroIcon
        }
    }

    @ViewBuilder
    private var heroIcon: some View {
        if page.symbol == "building" {
            BuildingGlyph().scaleEffect(2.2)
        } else {
            Image(systemName: page.symbol)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(EventsTheme.green)
        }
    }

    private func bulletRow(_ bullet: EventsOnboardingBullet) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Group {
                if bullet.symbol == "building" {
                    BuildingGlyph()
                } else {
                    Image(systemName: bullet.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(EventsTheme.green)
                }
            }
            .frame(width: 38, height: 38)
            .background(Circle().fill(EventsTheme.greenSoft))
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

struct EventsOnboardingBullet: Identifiable {
    let id = UUID()
    let symbol: String   // SkipUI-mapped SF name, or "building" for the drawn glyph
    let title: String
    let detail: String
}

struct EventsOnboardingPage: Identifiable {
    let index: Int
    let symbol: String
    let title: String
    let subtitle: String
    let bullets: [EventsOnboardingBullet]

    var id: Int { index }

    static let all: [EventsOnboardingPage] = [
        EventsOnboardingPage(
            index: 0,
            symbol: "trophy",
            title: "Events",
            subtitle: "Your tournament companion for Riftbound.",
            bullets: [
                .init(symbol: "calendar", title: "Follow your events",
                      detail: "Standings, pairings and results, live."),
                .init(symbol: "building", title: "Find local stores",
                      detail: "Search, save favorites, see their calendar."),
                .init(symbol: "play.fill", title: "Play connected",
                      detail: "Link a tournament match to your Scoreboard.")
            ]
        ),
        EventsOnboardingPage(
            index: 1,
            symbol: "lock.fill",
            title: "Sign in",
            subtitle: "Use your Riftbound Locator account.",
            bullets: [
                .init(symbol: "envelope.fill", title: "Email login",
                      detail: "The same account as locator.riftbound.uvsgames.com."),
                .init(symbol: "lock.fill", title: "Your password is never stored",
                      detail: "We keep only a secure login token on your device."),
                .init(symbol: "person.crop.circle", title: "Sign out anytime",
                      detail: "From the account button in the Events tab.")
            ]
        ),
        EventsOnboardingPage(
            index: 2,
            symbol: "building",
            title: "Find your stores",
            subtitle: "Discover and save the shops you play at.",
            bullets: [
                .init(symbol: "magnifyingglass", title: "Search by city",
                      detail: "See all the stores near you."),
                .init(symbol: "heart.fill", title: "Save favorites",
                      detail: "Tap the heart on any store."),
                .init(symbol: "calendar", title: "Store Calendar",
                      detail: "Every event at your saved stores, by date.")
            ]
        ),
        EventsOnboardingPage(
            index: 3,
            symbol: "checkmark.circle.fill",
            title: "Register in seconds",
            subtitle: "Sign up for events right here.",
            bullets: [
                .init(symbol: "list.bullet", title: "Browse events",
                      detail: "Upcoming, live and past."),
                .init(symbol: "checkmark.circle.fill", title: "Sign up",
                      detail: "Register and pay in person at the store."),
                .init(symbol: "xmark", title: "Drop anytime",
                      detail: "Change your mind with one tap.")
            ]
        ),
        EventsOnboardingPage(
            index: 4,
            symbol: "person.fill",
            title: "Live, in the app",
            subtitle: "No more juggling the website during rounds.",
            bullets: [
                .init(symbol: "mappin.circle", title: "Pairings and your table",
                      detail: "Know exactly where to sit each round."),
                .init(symbol: "list.bullet", title: "Live standings",
                      detail: "Track your place as rounds finish."),
                .init(symbol: "pencil", title: "Report results",
                      detail: "Submit your match without leaving the app."),
                .init(symbol: "chart.bar.fill", title: "Can I draw?",
                      detail: "Your top-cut outlook, shown automatically.")
            ]
        ),
        EventsOnboardingPage(
            index: 5,
            symbol: "play.fill",
            title: "Match mode",
            subtitle: "Score and report from the Scoreboard.",
            bullets: [
                .init(symbol: "gearshape", title: "Turn it on in Settings",
                      detail: "Under the Tournament section."),
                .init(symbol: "mappin.circle", title: "Table and opponent",
                      detail: "Shown right on your Scoreboard."),
                .init(symbol: "pencil", title: "Report on the spot",
                      detail: "Send your result the moment you finish.")
            ]
        )
    ]
}
