//
//  DeckArt.swift
//  Riftbound Companiokay
//
//  Pieces the Decks screens share (Android `DeckArt.kt`, `DeckParts.kt`, `DeckGallery.kt`): a card's art
//  cropped into any frame (or the mock's legend glow with a big initial), the pile, the Legal chip, the
//  W / L dot, and the gallery groups Units · Spells · Gear or one per energy.
//

import SwiftUI

/// The illustration sits above the card's middle, below its cost and domain marks: 3/8 of the overflow is
/// cut off the top (Android `ArtTop`).
private enum ArtTopID: AlignmentID {
    static func defaultValue(in d: ViewDimensions) -> CGFloat { d.height * 0.375 }
}

extension Alignment {
    static let artTop = Alignment(horizontal: .center, vertical: VerticalAlignment(ArtTopID.self))
}

/// A card's real art cropped into the frame, or the legend glow with a big initial while it loads or when
/// there is no card (a deck without a legend).
struct ArtBox: View {
    let card: Card?
    let imageWidth: CGFloat
    var initial: String? = nil
    var initialSize: CGFloat = 110
    var focus: Alignment = .artTop
    /// Shown while the full-size art loads: the pile's smaller copy, already fetched.
    var previewWidth: CGFloat? = nil
    @Environment(\.displayScale) private var scale

    var body: some View {
        GeometryReader { geo in
            CachedRemoteImage(url: url(imageWidth)) { image in
                crop(image, geo.size)
            } placeholder: {
                if let previewWidth {
                    CachedRemoteImage(url: url(previewWidth)) { image in crop(image, geo.size) } placeholder: { glow }
                } else {
                    glow
                }
            }
        }
    }

    private func url(_ width: CGFloat) -> URL? { card.flatMap { CardStyle.imageURL($0, widthPoints: width, scale: scale) } }

    private func crop(_ image: Image, _ size: CGSize) -> some View {
        image.resizable().scaledToFill().frame(width: size.width, height: size.height, alignment: focus).clipped()
    }

    private var glow: some View {
        ZStack(alignment: .topTrailing) {
            LegendGlow(domains: card?.domains ?? [])
            let letter = (initial ?? card.map { String($0.title.prefix(1)) } ?? "").uppercased()
            if !letter.isEmpty {
                Text(letter).font(RiftFont.display(initialSize)).foregroundStyle(.black.opacity(0.32)).padding(.trailing, 6).lineLimit(1)
            }
        }
    }
}

/// The mock's legend art: the first domain glows from the top left, the second from the bottom right.
struct LegendGlow: View {
    let domains: [String]

    var body: some View {
        let a = CardStyle.domainColor(domains.first)
        let b = CardStyle.domainColor(domains.count > 1 ? domains[1] : domains.first)
        GeometryReader { geo in
            let r = max(geo.size.width, geo.size.height) * 1.1
            ZStack {
                Color(hex: "111111")
                RadialGradient(stops: [.init(color: a.opacity(0.9), location: 0), .init(color: a.opacity(0.33), location: 0.4), .init(color: .clear, location: 0.7)],
                               center: UnitPoint(x: 0.2, y: 0.1), startRadius: 0, endRadius: r)
                RadialGradient(stops: [.init(color: b.opacity(0.85), location: 0), .init(color: b.opacity(0.25), location: 0.45), .init(color: .clear, location: 0.75)],
                               center: UnitPoint(x: 0.9, y: 1), startRadius: 0, endRadius: r)
            }
        }
    }
}

/// Bottom shade so white text reads on any art.
struct BottomShade: View {
    var from: CGFloat = 0.45

    var body: some View {
        LinearGradient(stops: [.init(color: .clear, location: from), .init(color: .black.opacity(0.88), location: 1)], startPoint: .top, endPoint: .bottom)
    }
}

/// Two card backs under the legend: the pile.
struct PileStack: View {
    let deck: Decklist
    let legend: Card?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12)
        ZStack {
            ForEach([(8.0, 3.0), (4.0, 1.5)], id: \.0) { shift, angle in
                shape.fill(LinearGradient(colors: [Color(hex: "242424"), Color(hex: "0B0B0B")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(shape.stroke(.white.opacity(0.14), lineWidth: 1))
                    .rotationEffect(.degrees(angle))
                    .offset(x: shift, y: shift)
            }
            ZStack(alignment: .topLeading) {
                ArtBox(card: legend, imageWidth: 120, initial: String((legend?.title ?? deck.name).prefix(1)), focus: .center)
                BottomShade(from: 0.55)
                Text("\(DeckRules.total(deck.mainDeck))")
                    .font(RiftFont.display(13, weight: 800))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 11))
                    .padding(8)
                Text(legend?.name ?? "No legend yet")
                    .font(RiftFont.text(12, .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .clipShape(shape)
            .overlay(shape.stroke(.white.opacity(0.2), lineWidth: 1))
            .shadow(color: .black.opacity(0.6), radius: 15, y: 14)
        }
    }
}

/// "Legal" green, issues gold, "Draft" grey: the pile's chip.
struct LegalChip: View {
    let status: String
    var onDark = false

    var body: some View {
        let ink: Color = status == "Legal" ? RiftColor.you : status == "Draft" ? .white.opacity(0.75) : RiftColor.gold
        let border: Color = status == "Legal" ? RiftColor.you.opacity(0.5) : status == "Draft" ? .white.opacity(0.25) : RiftColor.gold.opacity(0.5)
        Text(status.uppercased())
            .caps(10, tracking: 0.08, weight: .bold)
            .foregroundStyle(ink)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .frame(height: 22)
            .background(onDark ? Color.black.opacity(0.35) : .clear, in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(border, lineWidth: 1))
    }
}

/// W in green, L in violet.
struct ResultDot: View {
    let won: Bool
    let size: CGFloat
    let fontSize: CGFloat

    var body: some View {
        Text(won ? "W" : "L")
            .font(RiftFont.display(fontSize))
            .foregroundStyle(.black)
            .frame(width: size, height: size)
            .background(won ? RiftColor.you : RiftColor.opponent, in: Circle())
            .accessibilityLabel(won ? "Won" : "Lost")
    }
}

/// The new-deck and empty-shortlist frame.
struct DashedFrame: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
    }
}

/// Group headers of the galleries: "UNITS", "3 ENERGY", with their count on the right.
struct GroupHeader: View {
    let label: String
    let count: Int

    var body: some View {
        HStack {
            Text(label.uppercased()).caps(11)
            Spacer()
            Text("\(count)").caps(11)
        }
        .foregroundStyle(.white.opacity(0.62))
    }
}

enum DeckGallery {
    private static let typeOrder = ["unit", "spell", "gear"]

    /// Main or side as the Cards tab shows cards, in groups: Units · Spells · Gear, or one group per energy.
    /// Within a group by energy, then name.
    static func groups(_ cards: [(Card, Int)], byEnergy: Bool) -> [(label: String, cards: [(Card, Int)])] {
        let sorted = cards.sorted {
            let (a, b) = ($0.0.attributes?.energy ?? Int.max, $1.0.attributes?.energy ?? Int.max)
            return a != b ? a < b : $0.0.name.lowercased() < $1.0.name.lowercased()
        }
        if byEnergy {
            let grouped = Dictionary(grouping: sorted) { $0.0.attributes?.energy }
            return grouped.keys.sorted { ($0 ?? Int.max) < ($1 ?? Int.max) }.map { energy in
                (energy.map { "\($0) energy" } ?? "No energy", grouped[energy] ?? [])
            }
        }
        let grouped = Dictionary(grouping: sorted) { $0.0.typeName.lowercased() }
        func rank(_ type: String) -> Int { typeOrder.firstIndex(of: type) ?? typeOrder.count }
        return grouped.keys.sorted { (rank($0), $0) < (rank($1), $1) }.map { type in
            (label(type), grouped[type] ?? [])
        }
    }

    private static func label(_ type: String) -> String {
        switch type {
        case "unit": return "Units"
        case "spell": return "Spells"
        case "gear": return "Gear"
        case "": return "Other"
        default: return type.capitalized
        }
    }
}
