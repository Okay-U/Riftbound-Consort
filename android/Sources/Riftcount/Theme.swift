import SwiftUI

/// Shared iOS-parity surface style: soft white gradient card with stroke
/// and drop shadow, as used across the iOS Decks tab and builder cells.
extension View {
    func cardSurface(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.06),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 12, y: 6)
    }
}
