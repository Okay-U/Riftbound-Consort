import SwiftUI

struct OnboardingView: View {
    @AppStorage("didOnboard") private var didOnboard: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Riftcount",
            subtitle: "Score tracker and more for Riftbound TCG",
            symbol: "trophy.fill",
            tint: .yellow,
            bullets: [
                OnboardingBullet(symbol: "sparkles",
                                 title: "See what's new",
                                 detail: "with our latest version"),
                OnboardingBullet(symbol: "person.2.fill",
                                 title: "Show this app to your friends",
                                 detail: "while playing :)")
            ]
        ),
        OnboardingPage(
            title: "Scoreboard",
            subtitle: "Track every point with one tap",
            symbol: "rectangle.split.1x2.fill",
            tint: .green,
            bullets: [
                OnboardingBullet(symbol: "hand.tap.fill",
                                 title: "Tap to score",
                                 detail: "Top half = +, bottom half = −"),
                OnboardingBullet(symbol: "arrow.left.arrow.right",
                                 title: "Track XP",
                                 detail: "Swipe a tile left or right — or tap the XP button up top — to count experience"),
                OnboardingBullet(symbol: "rectangle.stack.person.crop.fill",
                                 title: "Pick decks",
                                 detail: "Choose your deck and opponent's to track win stats"),
                OnboardingBullet(symbol: "timer",
                                 title: "Game timer",
                                 detail: "Start and pause to time each match"),
                OnboardingBullet(symbol: "checkmark.seal.fill",
                                 title: "Won / Lost",
                                 detail: "Log results to build winrate per deck"),
                OnboardingBullet(symbol: "arrow.uturn.backward",
                                 title: "Undo",
                                 detail: "Rewind step-by-step when you misclick"),
                OnboardingBullet(symbol: "slider.horizontal.3",
                                 title: "Quick settings",
                                 detail: "Switch 2 ↔ 4 player mode and customize target score for battlefields like Aspirants Climb")
            ]
        ),
        OnboardingPage(
            title: "Dice",
            subtitle: "Roll any die you need",
            symbol: "dice.fill",
            tint: .orange,
            bullets: [
                OnboardingBullet(symbol: "die.face.6.fill",
                                 title: "D6 / D8 / D12 / D20",
                                 detail: "Switch dice on the fly"),
                OnboardingBullet(symbol: "iphone.radiowaves.left.and.right",
                                 title: "Shake to roll",
                                 detail: "Optional gesture, toggle in Settings")
            ]
        ),
        OnboardingPage(
            title: "Cards",
            subtitle: "Browse the whole pool",
            symbol: "rectangle.stack.fill",
            tint: .teal,
            bullets: [
                OnboardingBullet(symbol: "magnifyingglass",
                                 title: "Search",
                                 detail: "Find any card by name, type, or text"),
                OnboardingBullet(symbol: "line.3.horizontal.decrease.circle",
                                 title: "Filter",
                                 detail: "Narrow by domain, type, energy, runes, more"),
                OnboardingBullet(symbol: "arrow.up.arrow.down",
                                 title: "Sort",
                                 detail: "Energy ascending, name, domain order"),
                OnboardingBullet(symbol: "rectangle.portrait.fill",
                                 title: "Card view",
                                 detail: "Tap any card for full art + details")
            ]
        ),
        OnboardingPage(
            title: "Decks",
            subtitle: "Build, browse, analyze",
            symbol: "square.stack.3d.up.fill",
            tint: .blue,
            bullets: [
                OnboardingBullet(symbol: "wand.and.stars",
                                 title: "Build wizard",
                                 detail: "Legend → champion → battlefields → cards → runes"),
                OnboardingBullet(symbol: "rectangle.portrait.on.rectangle.portrait",
                                 title: "Draw hand",
                                 detail: "Simulate openings with mulligan support"),
                OnboardingBullet(symbol: "percent",
                                 title: "Draw odds",
                                 detail: "Hypergeometric chance to draw key cards by turn N"),
                OnboardingBullet(symbol: "chart.bar.fill",
                                 title: "Deck stats",
                                 detail: "Energy curve, power by domain, type breakdown"),
                OnboardingBullet(symbol: "doc.on.clipboard",
                                 title: "Import / Export",
                                 detail: "Copy decklists as text — paste in or share out via clipboard")
            ]
        ),
        OnboardingPage(
            title: "Make it yours",
            subtitle: "Tweak in Settings whenever",
            symbol: "gearshape.fill",
            tint: .purple,
            bullets: [
                OnboardingBullet(symbol: "paintpalette.fill",
                                 title: "Tile colors",
                                 detail: "15-color palette per player slot"),
                OnboardingBullet(symbol: "iphone",
                                 title: "Stay awake",
                                 detail: "Screen stays on during games"),
                OnboardingBullet(symbol: "hand.raised.fill",
                                 title: "Haptics & sounds",
                                 detail: "Toggle feedback to taste"),
                OnboardingBullet(symbol: "rectangle.on.rectangle.angled",
                                 title: "Live Activity",
                                 detail: "Optional Lock Screen + Dynamic Island scoreboard with ± buttons (2-player)")
            ]
        )
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $index) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { i, page in
                    OnboardingPageView(page: page)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            if !isLast {
                Button("Skip") { finish() }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 12)
                    .padding(.trailing, 16)
            }

            VStack {
                Spacer()
                Button(action: advance) {
                    Text(isLast ? "Get Started" : "Next")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(pages[index].tint, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 56)
            }
        }
        .interactiveDismissDisabled(true)
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

#Preview {
    OnboardingView()
}
