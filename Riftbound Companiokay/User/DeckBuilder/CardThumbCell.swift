//
//  CardThumbCell.swift
//  Riftbound Companiokay
//

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
                Color.white.opacity(0.06)
            ],
            startPoint: .topLeading,
            endPoint:   .bottomTrailing
        )
    }

    private var strokeColor: Color {
        isSelected ? .accentColor : .white.opacity(0.35)
    }

    private var strokeWidth: CGFloat {
        isSelected ? 2.5 : 1.5
    }

    private var aspectRatio: CGFloat {
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
                        .fill(.thinMaterial)
                        .overlay(ProgressView())
                }
                .aspectRatio(aspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                if let badge {
                    Text(badge)
                        .font(.caption.weight(.bold).monospacedDigit())
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
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
        .opacity(dimmed ? 0.4 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
