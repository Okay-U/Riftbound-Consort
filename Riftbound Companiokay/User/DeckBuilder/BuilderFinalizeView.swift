//
//  BuilderFinalizeView.swift
//  Riftbound Companiokay
//

import SwiftUI

struct BuilderFinalizeView: View {
    @ObservedObject var state: DeckBuilderState
    @EnvironmentObject var cardStore: CardStore
    @FocusState private var nameFocused: Bool

    var body: some View {
        Form {
            Section("Deck name") {
                TextField("e.g. Annie Aggro", text: $state.deckName)
                    .focused($nameFocused)
                    .textInputAutocapitalization(.words)
            }

            summarySection
            runesPreviewSection
            issuesSection
        }
        .onAppear { nameFocused = true }
    }

    private var summarySection: some View {
        Section("Summary") {
            row("Legend",     state.legend?.name ?? "—")
            row("Champion",   state.champion?.name ?? "—")
            row("Domains",    state.legendDomains.joined(separator: " / "))
            row("Battlefields",
                state.battlefields.map { $0.name }.joined(separator: ", "))
            row("Main deck",  "\(state.mainCount) / \(DeckBuilderState.mainDeckTarget)")
            row("Sideboard",  "\(state.sideCount)")
            row("Signature",
                "\(state.signatureCopyCount) / \(DeckBuilderState.signatureLimit)")
        }
    }

    private var runesPreviewSection: some View {
        Section("Auto-runes") {
            ForEach(resolvedRunes, id: \.domain) { entry in
                HStack {
                    Text(entry.domain.capitalized)
                    Spacer()
                    if let runeName = entry.runeName {
                        Text("\(DeckBuilderState.runePerDomain)× \(runeName)")
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
    }

    @ViewBuilder
    private var issuesSection: some View {
        let problems = openIssues
        if !problems.isEmpty {
            Section("Fix before saving") {
                ForEach(problems, id: \.self) { p in
                    Label(p, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.footnote)
                }
            }
        }
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
        if !state.canAdvanceFromLegend       { out.append("Legend not picked.") }
        if !state.canAdvanceFromChampion     { out.append("Champion not picked.") }
        if !state.canAdvanceFromBattlefield  { out.append("Need 3 battlefields.") }
        if !state.canAdvanceFromMain         { out.append("Main deck must be 39 cards.") }
        if !state.canAdvanceFromSide         { out.append("Sideboard must be 0 or 8 cards.") }
        return out
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}
