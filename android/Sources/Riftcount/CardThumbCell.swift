import SwiftUI

struct CardThumbCell: View {
    let card: Card
    let isSelected: Bool
    var badge: String? = nil       // e.g. "×2"
    var dimmed: Bool = false

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.22),
                Color.white.opacity(0.06),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var strokeColor: Color {
        isSelected ? Color.accentColor : Color.white.opacity(0.35)
    }

    private var strokeWidth: CGFloat {
        isSelected ? 2.5 : 1.5
    }

    private var aspect: CGFloat {
        let o = card.orientation?.lowercased()
        // Landscape (battlefields) ≈ 1.4 wide-to-tall. Portrait default.
        return o == "landscape" ? 1.4 : 0.72
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                CachedRemoteImage(url: card.media?.imageURL) { img in
                    img.resizable()
                        .scaledToFit()
                } placeholder: {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.15))
                        .overlay(ProgressView())
                }
                .aspectRatio(aspect, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                if let badge {
                    Text(badge)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Color.black.opacity(0.7))
                        )
                        .foregroundStyle(.white)
                        .padding(6)
                }
            }

            Text(card.name)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(strokeColor, lineWidth: strokeWidth)
        )
        .opacity(dimmed ? 0.4 : 1.0)
    }
}

/// Simple empty-state stand-in (ContentUnavailableView is not bridged).
struct EmptyStateView: View {
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}
