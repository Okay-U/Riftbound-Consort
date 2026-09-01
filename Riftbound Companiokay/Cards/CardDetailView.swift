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
                            .overlay {
                                GeometryReader { geo in
                                    // Guard the first frame: it can measure zero.
                                    if geo.size.height > 0, errataStore.erratum(for: card) != nil {
                                        ErrataStamp(cardHeight: geo.size.height)
                                            .frame(width: geo.size.width, height: geo.size.height,
                                                   alignment: .bottomLeading)
                                    }
                                }
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
/// Riot bakes a BANNED stamp into the bottom-right of the image, so this sits
/// bottom-left — a card can be both, and on Draven they collided. Every
/// dimension is a fraction of the rendered card height, taken by measuring
/// Riot's own stamp in the source art (box 6.54% of image height, inset 5.29%),
/// so the two line up at any size instead of drifting apart on a bigger screen.
///
/// Amber rather than red so it does not read as a second ban, with the same
/// soft glow underneath that Riot gives theirs.
struct ErrataStamp: View {
    /// Rendered height of the card image this sits on.
    let cardHeight: CGFloat

    private var fontSize: CGFloat { cardHeight * 0.0353 }
    private var hPad: CGFloat { cardHeight * 0.018 }
    private var vPad: CGFloat { cardHeight * 0.008 }
    private var stroke: CGFloat { max(1, cardHeight * 0.0035) }
    private var corner: CGFloat { cardHeight * 0.006 }
    private var inset: CGFloat { cardHeight * 0.0529 }

    var body: some View {
        Text("ERRATA")
            .font(.system(size: fontSize, weight: .heavy))
            .tracking(fontSize * 0.09)
            .foregroundStyle(Color.yellow)
            .padding(.horizontal, hPad).padding(.vertical, vPad)
            .background(RoundedRectangle(cornerRadius: corner).fill(Color.black.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: corner).stroke(Color.yellow, lineWidth: stroke))
            .shadow(color: Color.yellow.opacity(0.45), radius: cardHeight * 0.013)
            .padding(inset)
    }
}
