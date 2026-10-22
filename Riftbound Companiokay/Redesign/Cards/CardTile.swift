//
//  CardTile.swift
//  Riftbound Companiokay
//
//  A card as the grid shows it (Android `CardFace.kt`): Riot's art in the mock's frame, a shade with the
//  name and a type line (rarity gem, kind, ERRATA / PREVIEW stamps). Battlefields turn -90° to fill the
//  portrait frame. While the art loads, the mock's two glows in the card's colours stand in. The tile
//  fills the size it is given, so it can grow from the grid into the detail.
//

import SwiftUI

/// Card proportions of the grid tile (120 × 168 in the mock).
let cardAspect: CGFloat = 120 / 168

struct CardTile: View {
    let card: Card
    let errata: Bool
    /// The width the art is fetched for (Riot's CDN sends it at that size).
    let imageWidth: CGFloat
    /// The frame and labels over the art; the detail's hero shows the bare card.
    var labels = true
    @Environment(\.displayScale) private var scale

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10)
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .bottomLeading) {
                CachedRemoteImage(url: CardStyle.imageURL(card, widthPoints: card.isLandscape ? imageWidth / cardAspect : imageWidth, scale: scale)) { image in
                    if card.isLandscape {
                        image.resizable().scaledToFill().frame(width: h, height: w).rotationEffect(.degrees(-90)).frame(width: w, height: h)
                    } else {
                        image.resizable().scaledToFill().frame(width: w, height: h)
                    }
                } placeholder: {
                    PlaceholderArt(card: card)
                }
                if labels {
                    LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black.opacity(0.62), location: 0.54), .init(color: .black.opacity(0.94), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: h * 0.64)
                    nameplate
                }
            }
            .frame(width: w, height: h)
        }
        .background(Color(hex: "0B0B0B"))
        .clipShape(shape)
        .overlay(shape.stroke(.white.opacity(0.14), lineWidth: 1))
    }

    private var nameplate: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.name)
                .font(RiftFont.text(12, .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
            HStack(spacing: 5) {
                Gem(color: CardStyle.rarityColor(card.rarityName))
                Text(CardStyle.kind(card).uppercased())
                    .caps(8.5, tracking: 0.12)
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if errata { Stamp(text: "ERRATA", ink: RiftColor.gold) }
                if card.isPreview { Stamp(text: "PREVIEW", ink: .white) }
            }
        }
        .padding(8)
    }
}

private struct Stamp: View {
    let text: String
    let ink: Color

    var body: some View {
        Text(text)
            .font(RiftFont.text(7.5, .bold))
            .tracking(0.75)
            .foregroundStyle(ink)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(ink.opacity(0.2), in: RoundedRectangle(cornerRadius: 3))
            .fixedSize()
    }
}

/// The mock's stand-in art: two glows in the card's colours on near black, and the domain's rune.
private struct PlaceholderArt: View {
    let card: Card

    var body: some View {
        let domains = card.shownDomains
        let a = CardStyle.domainColor(domains.first)
        let b = CardStyle.domainColor(domains.count > 1 ? domains[1] : domains.first)
        // A stable spread per card name, so each placeholder looks like itself.
        let h = card.name.unicodeScalars.reduce(UInt64(7)) { ($0 &* 31 &+ UInt64($1.value)) & 0xFFFF_FFFF }
        let x = Double(18 + h % 64) / 100
        let y = Double(12 + (h >> 6) % 40) / 100
        let x2 = Double(85 - (h >> 11) % 60) / 100
        GeometryReader { geo in
            let reach = max(geo.size.width, geo.size.height)
            ZStack {
                LinearGradient(colors: [Color(hex: "1B1B1B"), Color(hex: "050505")], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(stops: [.init(color: a.opacity(0.65), location: 0), .init(color: a.opacity(0.15), location: 0.46), .init(color: .clear, location: 0.72)],
                               center: UnitPoint(x: x, y: y), startRadius: 0, endRadius: reach * 0.8)
                RadialGradient(stops: [.init(color: b.opacity(0.4), location: 0), .init(color: .clear, location: 0.68)],
                               center: UnitPoint(x: x2, y: 0.88), startRadius: 0, endRadius: reach * 0.62)
                Image(CardStyle.glyph(domains.first))
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(a)
                    .opacity(0.38)
                    .frame(width: geo.size.width * 0.53)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.395)
            }
        }
    }
}
