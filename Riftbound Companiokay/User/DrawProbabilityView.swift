//
//  DrawProbabilityView.swift
//  Riftbound Companiokay
//

import SwiftUI

struct DrawProbabilityView: View {
    let deck: Decklist
    @EnvironmentObject var cardStore: CardStore

    @State private var selectedIds: Set<String> = []
    @State private var draws: Int = 4
    @State private var atLeast: Int = 1

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
        Form {
            controlsSection
            cardListSection
            formulaSection
        }
        .navigationTitle("Draw odds")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { clampSteppers() }
        .onChange(of: deckSize) { _, _ in clampSteppers() }
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
            Stepper(value: $draws, in: 1...max(1, deckSize)) {
                HStack {
                    Text("Draws")
                    Spacer()
                    Text("\(draws)").monospacedDigit().foregroundStyle(.secondary)
                }
            }
            Stepper(value: $atLeast, in: 1...max(1, selectedCopies)) {
                HStack {
                    Text("At least")
                    Spacer()
                    Text("\(atLeast)").monospacedDigit().foregroundStyle(.secondary)
                }
            }
            .disabled(selectedCopies == 0)
            .onChange(of: selectedCopies) { _, newValue in
                if atLeast > max(1, newValue) { atLeast = max(1, newValue) }
            }

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
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(prob >= 0.5 && selectedCopies > 0 ? .green : .primary)
            }
            HStack {
                Text("Selected pool")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(selectedCopies) of \(deckSize)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
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
                            Image(systemName: selectedIds.contains(entry.id)
                                  ? "checkmark.circle.fill"
                                  : "circle")
                                .foregroundStyle(selectedIds.contains(entry.id)
                                                 ? Color.accentColor
                                                 : .secondary)
                            Text(entry.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("×\(entry.copies)")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                if !selectedIds.isEmpty {
                    Button(role: .destructive) {
                        selectedIds.removeAll()
                    } label: {
                        Label("Clear selection", systemImage: "xmark.circle")
                    }
                }
            }
        } header: {
            HStack {
                Text("Cards (tap to select any)")
                Spacer()
                Text("\(selectedIds.count) selected")
                    .font(.caption.monospacedDigit())
            }
        }
    }

    private func toggle(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    // MARK: - Formula section

    private var formulaSection: some View {
        Section("Formula") {
            Text("Hypergeometric: P(X ≥ k) over deck of \(deckSize), drawing \(draws).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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
