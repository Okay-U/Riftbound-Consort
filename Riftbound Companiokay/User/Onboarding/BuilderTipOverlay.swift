import SwiftUI

struct BuilderTipOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "wand.and.stars")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    Text("Build a deck")
                        .font(.title3.bold())
                    Spacer()
                }

                Text("Walk through these steps in order:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    tipRow(num: "1", text: "Pick a Legend")
                    tipRow(num: "2", text: "Pick its Champion")
                    tipRow(num: "3", text: "Choose Battlefields")
                    tipRow(num: "4", text: "Fill Main + Side decks (3-of cap)")
                    tipRow(num: "5", text: "Adjust Runes (12 total, ±)")
                    tipRow(num: "6", text: "Save your deck")
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Got it")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 28)
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private func tipRow(num: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(num)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.blue))
            Text(text)
                .font(.subheadline)
        }
    }
}
