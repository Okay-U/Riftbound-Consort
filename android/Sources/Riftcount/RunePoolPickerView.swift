import SwiftUI

struct RunePoolPickerView: View {
    let state: DeckBuilderState

    private var domains: [String] { state.legendDomains }

    var body: some View {
        VStack(spacing: 0) {
            BuilderCounterBar(
                title: "Runes",
                trailing: "\(state.runeTotalCount) / \(DeckBuilderState.runeTotal)",
                complete: state.runeTotalCount == DeckBuilderState.runeTotal
            )
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(domains, id: \.self) { domain in
                        runeRow(for: domain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private func runeRow(for domain: String) -> some View {
        let key = domain.lowercased()
        let count = state.runeCounts[key] ?? 0
        let atMax = state.runeTotalCount >= DeckBuilderState.runeTotal
        let atMin = count <= 0

        HStack(spacing: 14) {
            runeIcon(for: domain)
            Text(domain.capitalized)
                .font(.headline)
            Spacer()
            Button {
                state.decRune(domain: domain)
            } label: {
                stepCircle(minus: true, disabled: atMin)
            }
            .buttonStyle(.plain)
            .disabled(atMin)

            Text("\(count)")
                .font(.title3.weight(.semibold))
                .frame(minWidth: 32)

            Button {
                state.incRune(domain: domain)
            } label: {
                stepCircle(minus: false, disabled: atMax)
            }
            .buttonStyle(.plain)
            .disabled(atMax)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
        )
    }

    private func stepCircle(minus: Bool, disabled: Bool) -> some View {
        let tint: Color = disabled ? Color.secondary.opacity(0.4) : (minus ? .red : .green)
        return ZStack {
            Circle()
                .fill(tint)
                .frame(width: 30, height: 30)
            Capsule()
                .fill(Color.white)
                .frame(width: 12, height: 2.5)
            if !minus {
                Capsule()
                    .fill(Color.white)
                    .frame(width: 2.5, height: 12)
            }
        }
    }

    @ViewBuilder
    private func runeIcon(for domain: String) -> some View {
        if let asset = CardFilters.runeAssetName(for: domain) {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
        } else {
            Circle()
                .fill(Color.white)
                .frame(width: 36, height: 36)
        }
    }
}
