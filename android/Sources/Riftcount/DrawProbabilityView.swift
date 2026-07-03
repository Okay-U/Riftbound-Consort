import SwiftUI

/// Hypergeometric draw-odds calculator, ported from iOS.
/// Steppers replaced with drawn ± controls (Stepper is not bridged).
struct DrawProbabilityView: View {
    let deck: Decklist
    @Environment(CardStore.self) var cardStore

    @State var selectedIds: Set<String> = []
    @State var draws: Int = 4
    @State var atLeast: Int = 1

    private struct DeckCardEntry: Identifiable, Hashable {
        let id: String
        let name: String
        let copies: Int
    }

    private var deckSize: Int {
        deck.mainDeck.reduce(0) { $0 + $1.count }
    }

    private var deckEntries: [DeckCardEntry] {
        deck.mainDeck
            .map { DeckCardEntry(id: $0.cardId, name: $0.cardName, copies: $0.count) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var selectedCopies: Int {
        deckEntries
            .filter { selectedIds.contains($0.id) }
            .reduce(0) { $0 + $1.copies }
    }

    var body: some View {
        List {
            controlsSection
            cardListSection
            Section("Formula") {
                Text("Hypergeometric: P(X ≥ k) over deck of \(deckSize), drawing \(draws).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Draw odds")
        .onAppear { clampSteppers() }
    }

    private func clampSteppers() {
        let drawMax = max(1, deckSize)
        if draws > drawMax { draws = drawMax }
        if draws < 1 { draws = 1 }
        let atLeastMax = max(1, selectedCopies)
        if atLeast > atLeastMax { atLeast = atLeastMax }
        if atLeast < 1 { atLeast = 1 }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlsSection: some View {
        Section("Settings") {
            stepperRow(label: "Draws",
                       value: draws,
                       decEnabled: draws > 1,
                       incEnabled: draws < max(1, deckSize),
                       onDec: { draws -= 1 },
                       onInc: { draws += 1 })

            stepperRow(label: "At least",
                       value: atLeast,
                       decEnabled: atLeast > 1 && selectedCopies > 0,
                       incEnabled: atLeast < max(1, selectedCopies) && selectedCopies > 0,
                       onDec: { atLeast -= 1 },
                       onInc: { atLeast += 1 })

            let prob = Self.hypergeometricAtLeast(
                N: deckSize,
                K: selectedCopies,
                n: min(draws, deckSize),
                k: atLeast
            )
            HStack {
                Text("Chance")
                    .font(.headline)
                Spacer()
                Text(selectedCopies == 0 ? "—" : Self.formatPercent(prob))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(prob >= 0.5 && selectedCopies > 0 ? Color.green : Color.primary)
            }
            HStack {
                Text("Selected pool")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(selectedCopies) of \(deckSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stepperRow(label: String,
                            value: Int,
                            decEnabled: Bool,
                            incEnabled: Bool,
                            onDec: @escaping () -> Void,
                            onInc: @escaping () -> Void) -> some View {
        HStack {
            Text(label)
            Spacer()
            Button(action: onDec) {
                MinusCircleGlyph(enabled: decEnabled)
            }
            .buttonStyle(.plain)
            .disabled(!decEnabled)

            Text("\(value)")
                .frame(minWidth: 34)

            Button(action: onInc) {
                PlusCircleGlyph(enabled: incEnabled)
            }
            .buttonStyle(.plain)
            .disabled(!incEnabled)
        }
    }

    // MARK: - Card list

    @ViewBuilder
    private var cardListSection: some View {
        Section {
            if deckEntries.isEmpty {
                Text("Main deck is empty.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(deckEntries) { entry in
                    Button {
                        toggle(entry.id)
                    } label: {
                        HStack(spacing: 10) {
                            if selectedIds.contains(entry.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            } else {
                                Circle()
                                    .stroke(Color.secondary, lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                            }
                            Text(entry.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("×\(entry.copies)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                if !selectedIds.isEmpty {
                    Button {
                        selectedIds.removeAll()
                    } label: {
                        Text("Clear selection")
                            .foregroundStyle(.red)
                    }
                }
            }
        } header: {
            HStack {
                Text("Cards (tap to select any)")
                Spacer()
                Text("\(selectedIds.count) selected")
                    .font(.caption)
            }
        }
    }

    private func toggle(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
        clampSteppers()
    }

    // MARK: - Math

    static func binomial(_ n: Int, _ k: Int) -> Double {
        if k < 0 || k > n { return 0 }
        let kk = min(k, n - k)
        var result: Double = 1
        for i in 0..<kk {
            result *= Double(n - i)
            result /= Double(i + 1)
        }
        return result
    }

    static func hypergeometricAtLeast(N: Int, K: Int, n: Int, k: Int) -> Double {
        guard N > 0, K >= 0, n >= 0, k >= 0, n <= N, K <= N else { return 0 }
        let denom = binomial(N, n)
        guard denom > 0 else { return 0 }
        let upper = min(K, n)
        guard k <= upper else { return 0 }
        var total: Double = 0
        for i in k...upper {
            total += binomial(K, i) * binomial(N - K, n - i)
        }
        return total / denom
    }

    static func formatPercent(_ p: Double) -> String {
        let pct = max(0, min(1, p)) * 100
        return String(format: "%.1f%%", pct)
    }
}
