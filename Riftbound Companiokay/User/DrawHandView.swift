//
//  DrawHandView.swift
//  Riftbound Companiokay
//

import SwiftUI

struct DrawHandView: View {
    let deck: Decklist
    @EnvironmentObject var cardStore: CardStore
    @Environment(\.dismiss) private var dismiss

    @State private var pile: [Card] = []
    @State private var hand: [Card] = []
    @State private var selected: Set<Int> = []
    @State private var mulliganDone: Bool = false

    private let mulliganMax = 2
    private let openingHand = 4

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var canMulligan: Bool {
        !mulliganDone &&
        hand.count == openingHand &&
        !selected.isEmpty &&
        selected.count <= mulliganMax
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                statusBar
                handGrid
                actionButtons
            }
            .navigationTitle("Draw Hand")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if hand.isEmpty { newHand() }
            }
        }
    }

    private var statusBar: some View {
        HStack {
            Text("Hand: \(hand.count)")
            Spacer()
            if hand.count == openingHand && !mulliganDone {
                Text("Tap to mulligan (\(selected.count)/\(mulliganMax))")
                    .foregroundStyle(Color.accentColor)
            }
            Spacer()
            Text("Pile: \(pile.count)")
        }
        .font(.subheadline.monospacedDigit())
        .foregroundStyle(.secondary)
        .padding(.horizontal)
    }

    private var handGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(hand.enumerated()), id: \.offset) { idx, card in
                    cardImage(card, index: idx)
                        .onTapGesture {
                            toggleSelect(idx)
                        }
                }
            }
            .padding(.horizontal)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                drawOne()
            } label: {
                Label("Draw 1", systemImage: "plus.rectangle.portrait")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(pile.isEmpty)

            Button {
                mulligan()
            } label: {
                Label("Mulligan", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!canMulligan)

            Button {
                newHand()
            } label: {
                Label("New", systemImage: "shuffle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    @ViewBuilder
    private func cardImage(_ card: Card, index: Int) -> some View {
        let isSelected = selected.contains(index)
        CachedRemoteImage(url: card.media?.imageURL) { image in
            image
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } placeholder: {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.2))
                .aspectRatio(0.72, contentMode: .fit)
                .overlay(
                    Text(card.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .multilineTextAlignment(.center)
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 4)
        )
        .opacity(isSelected ? 0.85 : 1.0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.name)
        .accessibilityValue(isSelected ? "Selected for mulligan" : "")
        .accessibilityHint(canMulligan || (!mulliganDone && hand.count == openingHand)
                           ? "Double tap to toggle mulligan selection"
                           : "")
    }

    private func toggleSelect(_ idx: Int) {
        guard !mulliganDone, hand.count == openingHand else { return }
        if selected.contains(idx) {
            selected.remove(idx)
        } else if selected.count < mulliganMax {
            selected.insert(idx)
        }
    }

    private func buildPile() -> [Card] {
        let map = Dictionary(uniqueKeysWithValues: cardStore.allCards.map { ($0.id, $0) })
        var cards: [Card] = []
        for entry in deck.mainDeck {
            guard let c = map[entry.cardId] else { continue }
            for _ in 0..<entry.count { cards.append(c) }
        }
        return cards.shuffled()
    }

    private func newHand() {
        var fresh = buildPile()
        let take = min(openingHand, fresh.count)
        hand = Array(fresh.prefix(take))
        fresh.removeFirst(take)
        pile = fresh
        selected.removeAll()
        mulliganDone = false
    }

    private func drawOne() {
        guard !pile.isEmpty else { return }
        hand.append(pile.removeFirst())
        if hand.count > openingHand {
            selected.removeAll()
        }
    }

    private func mulligan() {
        guard canMulligan else { return }
        let indices = selected.sorted(by: >)
        var swapped: [Card] = []
        for idx in indices {
            swapped.append(hand.remove(at: idx))
        }
        pile.append(contentsOf: swapped)
        pile.shuffle()
        let take = min(swapped.count, pile.count)
        for _ in 0..<take {
            hand.append(pile.removeFirst())
        }
        selected.removeAll()
        mulliganDone = true
    }
}
