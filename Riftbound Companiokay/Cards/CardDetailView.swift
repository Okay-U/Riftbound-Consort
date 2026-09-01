//
//  CardDetailView.swift
//  Riftbound Companiokay
//

import SwiftUI

struct CardDetailView: View {
    let card: Card

    @EnvironmentObject var decklistStore: DecklistStore
    @EnvironmentObject var errataStore: ErrataStore
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
                            .overlay(alignment: .bottomLeading) {
                                if errataStore.erratum(for: card) != nil { ErrataStamp() }
                            }
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

                    if let erratum = errataStore.erratum(for: card) {
                        ErrataCallout(erratum: erratum)
                    }

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
                statBadge(label: "♻ \(power)")
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

/// Riot publishes card errata as articles; neither the printed card nor the
/// card database carries the corrected text. Shown above the printed text
/// because at a table the corrected wording is the one that applies.
struct ErrataCallout: View {
    let erratum: CardErratum

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("ERRATA")
                    .font(.system(size: 10, weight: .heavy)).tracking(0.6)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(Color.yellow.opacity(0.22)))
                    .foregroundStyle(Color.yellow)
                if let set = erratum.set {
                    Text(set).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }

            Text(erratum.newText)
                .font(.body)

            if let note = erratum.note, !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let url = erratum.sourceURL {
                Link("Official errata", destination: url)
                    .font(.footnote.weight(.semibold))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.yellow.opacity(0.09)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.35), lineWidth: 1))
    }
}

/// Drawn by us, not part of the card art.
///
/// Riot bakes a BANNED stamp into the bottom-right of the image itself, so this
/// sits bottom-left: a card can be both banned and errata'd, and on Draven the
/// two would otherwise collide. Same treatment as Riot's stamp — outlined box,
/// heavy letter-spaced caps, no fill over the art — in amber rather than red so
/// the two read as different things at a glance.
struct ErrataStamp: View {
    var compact = false

    private var fontSize: CGFloat { compact ? 8 : 17 }
    private var hPad: CGFloat { compact ? 4 : 9 }
    private var vPad: CGFloat { compact ? 2 : 4 }
    private var stroke: CGFloat { compact ? 1 : 2.5 }
    private var inset: CGFloat { compact ? 4 : 14 }

    var body: some View {
        Text("ERRATA")
            .font(.system(size: fontSize, weight: .heavy))
            .tracking(compact ? 0.5 : 1.5)
            .foregroundStyle(Color.yellow)
            .padding(.horizontal, hPad).padding(.vertical, vPad)
            .background(RoundedRectangle(cornerRadius: compact ? 3 : 5).fill(Color.black.opacity(0.55)))
            .overlay(RoundedRectangle(cornerRadius: compact ? 3 : 5)
                .stroke(Color.yellow, lineWidth: stroke))
            .padding(inset)
    }
}
