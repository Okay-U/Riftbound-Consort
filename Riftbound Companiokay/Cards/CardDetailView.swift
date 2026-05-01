//
//  CardDetailView.swift
//  Riftbound Companiokay
//

import SwiftUI

struct CardDetailView: View {
    let card: Card

    @EnvironmentObject var decklistStore: DecklistStore
    @State private var showAddToDeck: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AsyncImage(url: card.media?.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.secondary.opacity(0.2))
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                            }
                            .aspectRatio(0.72, contentMode: .fit)
                    default:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.secondary.opacity(0.2))
                            .overlay { ProgressView() }
                            .aspectRatio(0.72, contentMode: .fit)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    statsRow

                    if let plain = card.text?.plain, !plain.isEmpty {
                        Text(plain)
                            .font(.body)
                    }

                    if let flavour = card.text?.flavour, !flavour.isEmpty {
                        Text(flavour)
                            .font(.footnote)
                            .italic()
                            .foregroundStyle(.secondary)
                    }

                    if let artist = card.media?.artist {
                        Text("Art by \(artist)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 20)
        }
        .navigationTitle(card.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddToDeck = true
                } label: {
                    Label("Add to Deck", systemImage: "plus.rectangle.on.rectangle")
                }
            }
        }
        .sheet(isPresented: $showAddToDeck) {
            AddToDeckSheet(card: card)
                .environmentObject(decklistStore)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            if let type = card.classification?.type {
                statBadge(label: type)
            }
            if let rarity = card.classification?.rarity {
                statBadge(label: rarity)
            }
            if let energy = card.attributes?.energy {
                statBadge(label: "⚡ \(energy)")
            }
            if let power = card.attributes?.power {
                statBadge(label: "⚔ \(power)")
            }
        }
        .flexibleWidth()
    }

    private func statBadge(label: String) -> some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.secondary.opacity(0.2), in: Capsule())
    }
}

private extension View {
    func flexibleWidth() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AddToDeckSheet: View {
    let card: Card
    @EnvironmentObject var decklistStore: DecklistStore
    @Environment(\.dismiss) private var dismiss
    @State private var newDeckName: String = ""
    @State private var showNewDeckField: Bool = false

    var body: some View {
        NavigationStack {
            List {
                if decklistStore.lists.isEmpty {
                    Text("No decklists yet — create one below.")
                        .foregroundStyle(.secondary)
                }
                ForEach(decklistStore.lists) { list in
                    Button {
                        decklistStore.add(card, to: list)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(list.name)
                                Text("Adds to: \(card.preferredSlot.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }

                if showNewDeckField {
                    HStack {
                        TextField("Deck name", text: $newDeckName)
                        Button("Create") {
                            let name = newDeckName.trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty else { return }
                            let new = decklistStore.create(name: name)
                            decklistStore.add(card, to: new)
                            dismiss()
                        }
                        .disabled(newDeckName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("Add to Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Deck") { showNewDeckField.toggle() }
                }
            }
        }
    }
}
