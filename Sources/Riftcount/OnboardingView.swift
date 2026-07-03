import SwiftUI

/// First-launch tour, ported from iOS. Page-style TabView with custom dots
/// (system index dots skipped for cross-platform consistency). Content adapted
/// for Android: no shake-to-roll, Live Activity, or stay-awake bullets.
/// Unmapped SF Symbols render as drawn glyphs (OnboardingGlyph).
struct OnboardingView: View {
    @AppStorage("didOnboard") var didOnboard: Bool = false
    @Environment(\.dismiss) var dismiss
    @State var index: Int = 0

    private let pages = OnboardingPage.all

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(pages) { page in
                    OnboardingPageView(page: page)
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

            if !isLast {
                Button("Skip") { finish() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                    .padding(.top, 14).padding(.trailing, 18)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(pages.indices, id: \.self) { i in
                Capsule()
                    .fill(i == index ? pages[index].tint : Color.white.opacity(0.25))
                    .frame(width: i == index ? 22 : 7, height: 7)
                    .animation(.easeInOut(duration: 0.2), value: index)
            }
        }
    }

    private var cta: some View {
        Button(action: advance) {
            Text(isLast ? "Get Started" : "Next")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(pages[index].tint)
                )
        }
        .buttonStyle(.plain)
    }

    private var isLast: Bool { index == pages.count - 1 }

    private func advance() {
        if isLast { finish() }
        else { withAnimation { index += 1 } }
    }

    private func finish() {
        didOnboard = true
        dismiss()
    }
}

// MARK: - Page rendering

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                OnboardingGlyphView(glyph: page.glyph, size: 72, tint: page.tint)
                    .padding(.top, 32)

                VStack(spacing: 8) {
                    Text(page.title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(page.subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(page.bullets) { b in
                        HStack(alignment: .top, spacing: 14) {
                            OnboardingGlyphView(glyph: b.glyph, size: 22, tint: page.tint)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b.title)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(b.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)

                Spacer(minLength: 150)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Glyphs

/// Icon source for onboarding rows: a SkipUI-mapped SF Symbol, a unicode
/// character, or a small drawn shape for symbols missing from the map.
enum OnboardingGlyph {
    case symbol(String)
    case text(String)
    case tiles      // scoreboard: two stacked rounded rects
    case card       // single card outline
    case cards      // two overlapping cards
    case die        // D6 face with pips
    case clock      // circle + hands
    case undo       // mirrored clockwise arrow
    case filter     // funnel (reuses FilterGlyph)
    case palette    // 2×2 color dots
}

struct OnboardingGlyphView: View {
    let glyph: OnboardingGlyph
    let size: CGFloat
    let tint: Color

    var body: some View {
        switch glyph {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: size * 0.9, weight: .semibold))
                .foregroundStyle(tint)
        case .text(let string):
            Text(string)
                .font(.system(size: size * 0.85, weight: .bold))
                .foregroundStyle(tint)
        case .tiles:
            VStack(spacing: size * 0.09) {
                RoundedRectangle(cornerRadius: size * 0.12)
                    .fill(tint)
                    .frame(width: size * 0.82, height: size * 0.38)
                RoundedRectangle(cornerRadius: size * 0.12)
                    .fill(tint.opacity(0.55))
                    .frame(width: size * 0.82, height: size * 0.38)
            }
            .frame(width: size, height: size)
        case .card:
            RoundedRectangle(cornerRadius: size * 0.1)
                .stroke(tint, lineWidth: max(1.5, size * 0.06))
                .frame(width: size * 0.62, height: size * 0.86)
                .frame(width: size, height: size)
        case .cards:
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.1)
                    .fill(tint.opacity(0.45))
                    .frame(width: size * 0.56, height: size * 0.78)
                    .offset(x: size * 0.14, y: -size * 0.06)
                RoundedRectangle(cornerRadius: size * 0.1)
                    .fill(tint)
                    .frame(width: size * 0.56, height: size * 0.78)
                    .offset(x: -size * 0.1, y: size * 0.06)
            }
            .frame(width: size, height: size)
        case .die:
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.18)
                    .stroke(tint, lineWidth: max(1.5, size * 0.06))
                let pip = size * 0.12
                Circle().fill(tint).frame(width: pip, height: pip)
                    .offset(x: -size * 0.2, y: -size * 0.2)
                Circle().fill(tint).frame(width: pip, height: pip)
                Circle().fill(tint).frame(width: pip, height: pip)
                    .offset(x: size * 0.2, y: size * 0.2)
            }
            .frame(width: size * 0.9, height: size * 0.9)
            .frame(width: size, height: size)
        case .clock:
            ZStack {
                Circle()
                    .stroke(tint, lineWidth: max(1.5, size * 0.07))
                // Hands: minute up, hour right.
                Rectangle().fill(tint)
                    .frame(width: max(1.5, size * 0.07), height: size * 0.28)
                    .offset(y: -size * 0.14)
                Rectangle().fill(tint)
                    .frame(width: size * 0.2, height: max(1.5, size * 0.07))
                    .offset(x: size * 0.1)
            }
            .frame(width: size, height: size)
        case .undo:
            Image(systemName: "arrow.clockwise.circle")
                .font(.system(size: size * 0.9, weight: .semibold))
                .foregroundStyle(tint)
                .scaleEffect(x: -1, y: 1)
        case .filter:
            // Funnel: three shrinking bars (FilterGlyph hardcodes its colors).
            VStack(spacing: size * 0.14) {
                Capsule().fill(tint).frame(width: size * 0.8, height: size * 0.11)
                Capsule().fill(tint).frame(width: size * 0.55, height: size * 0.11)
                Capsule().fill(tint).frame(width: size * 0.28, height: size * 0.11)
            }
            .frame(width: size, height: size)
        case .palette:
            VStack(spacing: size * 0.09) {
                HStack(spacing: size * 0.09) {
                    Circle().fill(Color.red).frame(width: size * 0.3, height: size * 0.3)
                    Circle().fill(Color.yellow).frame(width: size * 0.3, height: size * 0.3)
                }
                HStack(spacing: size * 0.09) {
                    Circle().fill(Color.green).frame(width: size * 0.3, height: size * 0.3)
                    Circle().fill(Color.blue).frame(width: size * 0.3, height: size * 0.3)
                }
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Content

struct OnboardingBullet: Identifiable {
    let id = UUID()
    let glyph: OnboardingGlyph
    let title: String
    let detail: String
}

struct OnboardingPage: Identifiable {
    let index: Int
    let title: String
    let subtitle: String
    let glyph: OnboardingGlyph
    let tint: Color
    let bullets: [OnboardingBullet]

    var id: Int { index }

    static let all: [OnboardingPage] = [
        OnboardingPage(
            index: 0,
            title: "Riftcount",
            subtitle: "Score tracker and more for Riftbound TCG",
            glyph: .symbol("trophy"),
            tint: .yellow,
            bullets: [
                OnboardingBullet(glyph: .symbol("star.fill"),
                                 title: "See what's new",
                                 detail: "with our latest version"),
                OnboardingBullet(glyph: .symbol("person.fill"),
                                 title: "Show this app to your friends",
                                 detail: "while playing :)")
            ]
        ),
        OnboardingPage(
            index: 1,
            title: "Scoreboard",
            subtitle: "Track every point with one tap",
            glyph: .tiles,
            tint: .green,
            bullets: [
                OnboardingBullet(glyph: .symbol("plus.circle.fill"),
                                 title: "Tap to score",
                                 detail: "Top half = +, bottom half = −"),
                OnboardingBullet(glyph: .text("↔"),
                                 title: "Track XP",
                                 detail: "Swipe a tile left or right — or tap the XP button up top — to count experience"),
                OnboardingBullet(glyph: .cards,
                                 title: "Pick decks",
                                 detail: "Choose your deck and opponent's to track win stats"),
                OnboardingBullet(glyph: .clock,
                                 title: "Game timer",
                                 detail: "Start and pause to time each match"),
                OnboardingBullet(glyph: .symbol("checkmark.circle.fill"),
                                 title: "Won / Lost",
                                 detail: "Log results to build winrate per deck"),
                OnboardingBullet(glyph: .undo,
                                 title: "Undo",
                                 detail: "Rewind step-by-step when you misclick"),
                OnboardingBullet(glyph: .symbol("line.3.horizontal"),
                                 title: "Quick settings",
                                 detail: "Switch 2 ↔ 4 player mode")
            ]
        ),
        OnboardingPage(
            index: 2,
            title: "Dice",
            subtitle: "Roll any die you need",
            glyph: .die,
            tint: .orange,
            bullets: [
                OnboardingBullet(glyph: .die,
                                 title: "D6 / D8 / D12 / D20",
                                 detail: "Switch dice on the fly"),
                OnboardingBullet(glyph: .symbol("play.fill"),
                                 title: "Tap Roll",
                                 detail: "Big button, quick rolls")
            ]
        ),
        OnboardingPage(
            index: 3,
            title: "Cards",
            subtitle: "Browse the whole pool",
            glyph: .cards,
            tint: .teal,
            bullets: [
                OnboardingBullet(glyph: .symbol("magnifyingglass"),
                                 title: "Search",
                                 detail: "Find any card by name, type, or text"),
                OnboardingBullet(glyph: .filter,
                                 title: "Filter",
                                 detail: "Narrow by domain, type, energy, runes, more"),
                OnboardingBullet(glyph: .text("↑↓"),
                                 title: "Sort",
                                 detail: "Energy ascending, name, domain order"),
                OnboardingBullet(glyph: .card,
                                 title: "Card view",
                                 detail: "Tap any card for full art + details")
            ]
        ),
        OnboardingPage(
            index: 4,
            title: "Decks",
            subtitle: "Build, browse, analyze",
            glyph: .cards,
            tint: .blue,
            bullets: [
                OnboardingBullet(glyph: .symbol("star.fill"),
                                 title: "Build wizard",
                                 detail: "Legend → champion → battlefields → cards → runes"),
                OnboardingBullet(glyph: .cards,
                                 title: "Draw hand",
                                 detail: "Simulate openings with mulligan support"),
                OnboardingBullet(glyph: .text("%"),
                                 title: "Draw odds",
                                 detail: "Hypergeometric chance to draw key cards by turn N"),
                OnboardingBullet(glyph: .symbol("chart.bar.fill"),
                                 title: "Deck stats",
                                 detail: "Energy curve, power by domain, type breakdown"),
                OnboardingBullet(glyph: .symbol("square.and.arrow.up"),
                                 title: "Import / Export",
                                 detail: "Paste decklists in, share them out")
            ]
        ),
        OnboardingPage(
            index: 5,
            title: "Make it yours",
            subtitle: "Tweak in Settings whenever",
            glyph: .symbol("gearshape.fill"),
            tint: .purple,
            bullets: [
                OnboardingBullet(glyph: .palette,
                                 title: "Tile colors",
                                 detail: "15-color palette per player slot"),
                OnboardingBullet(glyph: .symbol("bell.fill"),
                                 title: "Haptics",
                                 detail: "Toggle feedback to taste"),
                OnboardingBullet(glyph: .symbol("trophy"),
                                 title: "Match mode",
                                 detail: "Link live tournament matches to your Scoreboard")
            ]
        )
    ]
}
