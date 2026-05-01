//
//  DeckDetailView.swift
//  Riftbound Companiokay
//

import SwiftUI

struct DeckDetailView: View {
    let deck: Decklist
    @EnvironmentObject var store: DecklistStore
    @State private var showRenameAlert: Bool = false
    @State private var newName: String = ""

    private var current: Decklist {
        store.lists.first(where: { $0.id == deck.id }) ?? deck
    }
    private var legality: DeckLegality { DeckLegality.evaluate(current) }

    var body: some View {
        List {
            legalitySection
            singularSection(title: "Champion (1)",
                            entry: current.champion,
                            slot: .champion)
            singularSection(title: "Legend (1)",
                            entry: current.legend,
                            slot: .legend)
            multiSection(title: "Battlefields",
                         expected: "3",
                         entries: current.battlefields,
                         slot: .battlefield)
            multiSection(title: "Main deck",
                         expected: "39",
                         entries: current.mainDeck,
                         slot: .mainDeck)
            multiSection(title: "Side deck",
                         expected: "0 or 8",
                         entries: current.sideDeck,
                         slot: .sideDeck)
            multiSection(title: "Runes",
                         expected: "12",
                         entries: current.runes,
                         slot: .rune)
            statsPlaceholderSection
        }
        .navigationTitle(current.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Rename") {
                    newName = current.name
                    showRenameAlert = true
                }
            }
        }
        .alert("Rename Deck", isPresented: $showRenameAlert) {
            TextField("Name", text: $newName)
            Button("Save") {
                let trimmed = newName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                store.rename(current, to: trimmed)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Sections

    private var legalitySection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: legality.isLegal
                      ? "checkmark.seal.fill"
                      : "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(legality.isLegal ? .green : .orange)
                Text(legality.isLegal ? "Legal deck" : "Illegal deck")
                    .font(.headline)
            }
            if !legality.isLegal {
                ForEach(legality.issues, id: \.self) { issue in
                    Text(issue)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func singularSection(title: String,
                                 entry: DecklistEntry?,
                                 slot: DeckSlot) -> some View {
        Section(title) {
            if let entry {
                HStack {
                    Text(entry.cardName)
                    Spacer()
                    Button(role: .destructive) {
                        store.remove(entry, from: current, slot: slot)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("Not set")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func multiSection(title: String,
                              expected: String,
                              entries: [DecklistEntry],
                              slot: DeckSlot) -> some View {
        let total = entries.reduce(0) { $0 + $1.count }
        Section("\(title) (\(total)/\(expected))") {
            if entries.isEmpty {
                Text("Empty")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(entries, id: \.cardId) { entry in
                    HStack {
                        Text(entry.cardName)
                        Spacer()
                        HStack(spacing: 8) {
                            Button {
                                store.decrement(entry, in: current, slot: slot)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            Text("×\(entry.count)")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    offsets.forEach {
                        store.remove(entries[$0], from: current, slot: slot)
                    }
                }
            }
        }
    }

    private var statsPlaceholderSection: some View {
        Section("Stats") {
            NavigationLink {
                GameHistoryView(scope: .deck(current.id), title: current.name)
            } label: {
                Label("Game history", systemImage: "clock.arrow.circlepath")
            }
        }
    }
}
