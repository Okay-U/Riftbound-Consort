import SwiftUI

struct OnboardingBullet: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let detail: String
}

struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let bullets: [OnboardingBullet]
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: page.symbol)
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(page.tint)
                    .padding(.top, 32)

                VStack(spacing: 8) {
                    Text(page.title)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text(page.subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                if !page.bullets.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(page.bullets) { b in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: b.symbol)
                                    .font(.title3)
                                    .foregroundStyle(page.tint)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(b.title)
                                        .font(.headline)
                                    Text(b.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
                }

                Spacer(minLength: 80)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
