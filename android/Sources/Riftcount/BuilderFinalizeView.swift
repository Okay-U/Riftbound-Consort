import SwiftUI

struct BuilderFinalizeView: View {
    let state: DeckBuilderState
    @Environment(CardStore.self) var cardStore

    var body: some View {
        // Bindable wrapper for deckName two-way binding on @Observable.
        @Bindable var state = state

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionTitle("Deck name")
                TextField("e.g. Annie Aggro", text: $state.deckName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 16)

                sectionTitle("Summary")
                VStack(spacing: 8) {
                    row("Legend", state.legend?.name ?? "—")
                    row("Champion", state.champion?.name ?? "—")
                    row("Domains", state.legendDomains.joined(separator: " / "))
                    row("Battlefields",
                        state.battlefields.map { $0.name }.joined(separator: ", "))
                    row("Main deck", "\(state.mainCount) / \(DeckBuilderState.mainDeckTarget)")
                    row("Sideboard", "\(state.sideCount)")
                    row("Signature",
                        "\(state.signatureCopyCount) / \(DeckBuilderState.signatureLimit)")
                }
                .padding(.horizontal, 16)

                sectionTitle("Runes")
                VStack(spacing: 8) {
                    ForEach(resolvedRunes, id: \.domain) { entry in
                        HStack {
                            Text(entry.domain.capitalized)
                            Spacer()
                            if let runeName = entry.runeName {
                                Text("\(state.runeCounts[entry.domain.lowercased()] ?? 0)× \(runeName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No rune found")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)

                if !openIssues.isEmpty {
                    sectionTitle("Fix before saving")
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(openIssues, id: \.self) { p in
                            Text("⚠ \(p)")
                                .foregroundStyle(.orange)
                                .font(.footnote)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
    }

    // MARK: - Computed

    private struct RuneRow: Hashable {
        let domain: String
        let runeName: String?
    }

    private var resolvedRunes: [RuneRow] {
        state.legendDomains.map { domain in
            let card = Card.runeCard(forDomain: domain, in: cardStore.allCards)
            return RuneRow(domain: domain, runeName: card?.name)
        }
    }

    private var openIssues: [String] {
        var out: [String] = []
        if state.deckName.trimmingCharacters(in: .whitespaces).isEmpty {
            out.append("Pick a deck name.")
        }
        if !state.canAdvanceFromLegend { out.append("Legend not picked.") }
        if !state.canAdvanceFromChampion { out.append("Champion not picked.") }
        if !state.canAdvanceFromBattlefield { out.append("Need 3 battlefields.") }
        if !state.canAdvanceFromMain { out.append("Main deck must be 39 cards.") }
        if !state.canAdvanceFromSide { out.append("Sideboard must be 0 or 8 cards.") }
        return out
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
