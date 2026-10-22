//
//  HandSheet.swift
//  Riftbound Companiokay
//
//  The test hand (Android `HandSheet.kt`): four cards fly off the pile into a fan; tap up to two for the
//  mulligan, draw one at a time. A new hand or a mulligan first sends the cards back onto the pile.
//

import SwiftUI

private let cardSize = CGSize(width: 112, height: 157)
private let pileSize = CGSize(width: 56, height: 78)
private let pileInset: CGFloat = 6
private let collectSeconds = 0.38
private let collectStagger = 0.045

struct HandSheet: View {
    let deck: Decklist
    let cards: [String: Card]
    @State private var hand: Hand
    /// Cards flying back onto the pile before the hand changes.
    @State private var returning: Set<Int> = []
    /// The first id of the cards new to the fan: they take turns off the pile.
    @State private var dealtFrom = 0
    @State private var toast: BoardToast?

    init(deck: Decklist, cards: [String: Card]) {
        self.deck = deck
        self.cards = cards
        _hand = State(initialValue: Hand.deal(deck))
    }

    var body: some View {
        let busy = !returning.isEmpty
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(status)
                        Spacer()
                        Text("\(hand.pile.count) left in deck")
                    }
                    .font(RiftFont.text(12, .semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    fan
                    HStack(spacing: 8) {
                        WideButton(text: "New hand", enabled: !busy) {
                            sendBack(Set(hand.cards.map(\.id)), then: Hand.deal(deck, firstId: hand.nextId))
                        }
                        WideButton(text: "Draw 1", enabled: hand.canDraw && !busy) {
                            dealtFrom = hand.nextId
                            hand = hand.draw()
                            Haptics.light()
                        }
                        WideButton(text: hand.marked.isEmpty ? "Mulligan" : "Mulligan \(hand.marked.count)", fill: RiftColor.gold, ink: .black,
                                   enabled: hand.canMulligan && !busy) {
                            sendBack(hand.marked, then: hand.mulligan())
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(16)
            }
            .navigationTitle("Test hand · \(deck.name)")
            .navigationBarTitleDisplayMode(.inline)
        }
        .overlay(alignment: .bottom) {
            if let toast {
                HalfToast(text: toast.text)
                    .padding(.bottom, 24)
                    .id(toast.id)
                    .task(id: toast.id) {
                        try? await Task.sleep(for: .seconds(2.2))
                        if self.toast?.id == toast.id { self.toast = nil }
                    }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var status: String {
        if hand.cards.isEmpty { return "The main deck is empty" }
        if hand.mulliganUsed { return "Mulligan used · \(hand.cards.count) cards" }
        if !hand.marked.isEmpty { return "\(hand.marked.count) marked for mulligan" }
        return "Tap up to 2 cards to mulligan"
    }

    private func sendBack(_ ids: Set<Int>, then next: Hand) {
        returning = ids
        Haptics.light()
        Task {
            try? await Task.sleep(for: .seconds(collectSeconds + Double(ids.count) * collectStagger))
            dealtFrom = hand.nextId
            hand = next
            returning = []
        }
    }

    /// The mock's fan: cards on an arc of 300pt radius, up to 40° wide; a marked card lifts and glows amber.
    private var fan: some View {
        GeometryReader { geo in
            let n = hand.cards.count
            let spread = min(40, 11 * Double(max(n - 1, 0)))
            ZStack(alignment: .topLeading) {
                PileBack(count: hand.pile.count)
                    .offset(x: geo.size.width - pileInset - pileSize.width, y: pileInset)
                ForEach(Array(hand.cards.enumerated()), id: \.element.id) { i, handCard in
                    FanCard(
                        card: cards[handCard.cardId],
                        angle: n <= 1 ? 0 : -spread / 2 + Double(i) * spread / Double(n - 1),
                        marked: hand.marked.contains(handCard.id),
                        order: max(0, handCard.id - dealtFrom),
                        returning: returning.contains(handCard.id),
                        backOrder: hand.cards.dropFirst(i + 1).filter { returning.contains($0.id) }.count,
                        width: geo.size.width
                    ) {
                        guard returning.isEmpty else { return }
                        let (next, note) = hand.toggle(handCard.id)
                        hand = next
                        if let note { toast = BoardToast(text: note) } else { Haptics.selection() }
                    }
                }
            }
        }
        .frame(height: 300)
        .padding(.top, 6)
    }
}

private struct PileBack: View {
    let count: Int

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 9)
        Text("\(count)")
            .font(RiftFont.display(20))
            .foregroundStyle(.white.opacity(0.75))
            .frame(width: pileSize.width, height: pileSize.height)
            .background(LinearGradient(colors: [Color(hex: "262626"), Color(hex: "0C0C0C")], startPoint: .topLeading, endPoint: .bottomTrailing), in: shape)
            .overlay(shape.stroke(.white.opacity(0.18), lineWidth: 1))
            .accessibilityLabel("\(count) cards left in the deck")
    }
}

private struct FanCard: View {
    let card: Card?
    let angle: Double
    let marked: Bool
    let order: Int
    let returning: Bool
    let backOrder: Int
    let width: CGFloat
    let onTap: () -> Void
    @State private var away: Double = 0

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12)
        Button(action: onTap) {
            Group {
                if let card {
                    CardTile(card: card, errata: false, imageWidth: cardSize.width)
                } else {
                    shape.fill(Color(hex: "1A1A1A"))
                }
            }
            .frame(width: cardSize.width, height: cardSize.height)
            .clipShape(shape)
            .overlay { if marked { shape.stroke(RiftColor.gold, lineWidth: 2) } }
            .shadow(color: marked ? RiftColor.gold.opacity(0.5) : .clear, radius: 9)
        }
        .buttonStyle(PressScale(scale: 0.97))
        .modifier(FanSpot(v: away, angle: angle, lift: marked ? 1 : 0, width: width))
        .animation(.rift(0.7), value: angle)
        .animation(.rift(0.3), value: marked)
        .accessibilityLabel((card?.name ?? "Card") + (marked ? ", marked for mulligan" : ""))
        .onAppear {
            // Slow off the pile, then a long settle: the card is seen leaving the deck.
            withAnimation(.timingCurve(0.2, 0, 0, 1, duration: 0.64).delay(Double(order) * 0.09)) { away = 1 }
        }
        .onChange(of: returning) { _, back in
            guard back else { return }
            withAnimation(.timingCurve(0.4, 0, 1, 1, duration: collectSeconds).delay(Double(backOrder) * collectStagger)) { away = 0 }
        }
    }
}

/// Between the pile (half size, upright, centred on it, unseen) and the card's place on the arc. The pivot
/// sits 1.2 heights down, so the half-size card's centre is 0.85 heights below its top.
private struct FanSpot: ViewModifier, Animatable {
    var v: Double
    var angle: Double
    var lift: Double
    let width: CGFloat

    nonisolated var animatableData: AnimatablePair<AnimatablePair<Double, Double>, Double> {
        get { AnimatablePair(AnimatablePair(v, angle), lift) }
        set {
            v = newValue.first.first
            angle = newValue.first.second
            lift = newValue.second
        }
    }

    func body(content: Content) -> some View {
        let rad = angle * .pi / 180
        let radius = 300.0
        let fanX = (width - cardSize.width) / 2 + sin(rad) * radius
        let fanY = 96 + (1 - cos(rad)) * radius - 28 * lift
        let pileX = width - pileInset - pileSize.width / 2 - cardSize.width / 2
        let pileY = pileInset + pileSize.height / 2 - 0.85 * cardSize.height
        let pivot = UnitPoint(x: 0.5, y: 1.2)
        content
            .scaleEffect(0.5 + 0.5 * v, anchor: pivot)
            .rotationEffect(.degrees(angle * v), anchor: pivot)
            .offset(x: pileX + (fanX - pileX) * v, y: pileY + (fanY - pileY) * v)
            .opacity(min(v / 0.2, 1))
    }
}
