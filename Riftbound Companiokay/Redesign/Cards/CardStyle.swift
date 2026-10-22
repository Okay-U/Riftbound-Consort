//
//  CardStyle.swift
//  Riftbound Companiokay
//
//  The redesign's card look (Android `CardStyle.kt`): a card's kind, domain hues, rarity gems, Riot's rune
//  glyphs, and card art sized by Riot's image CDN.
//

import SwiftUI

enum CardStyle {
    /// The domain filter's order, as the mock lays out its discs.
    static let domainsInOrder = ["Fury", "Calm", "Mind", "Body", "Chaos", "Order"]
    static let colorless = Color(hex: "C9CDD2")

    static func domainColor(_ domain: String?) -> Color {
        switch domain?.lowercased() {
        case "fury": return Color(hex: "F2554D")
        case "calm": return Color(hex: "4FD18B")
        case "mind": return Color(hex: "4D8EF7")
        case "body": return Color(hex: "F4933B")
        case "chaos": return Color(hex: "B06BF2")
        case "order": return Color(hex: "F2C94C")
        default: return colorless
        }
    }

    static func rarityColor(_ rarity: String) -> Color {
        switch rarity.lowercased() {
        case "uncommon": return Color(hex: "5FD3C6")
        case "rare": return Color(hex: "6FA8FF")
        case "epic": return Color(hex: "C08BFF")
        case "showcase": return Color(hex: "F2C94C")
        default: return Color(hex: "9AA0A6")
        }
    }

    /// Riot's rune shape for a domain as a template image; colourless gets the colourless mark.
    static func glyph(_ domain: String?) -> String {
        guard let domain, domainsInOrder.contains(where: { $0.caseInsensitiveCompare(domain) == .orderedSame }) else { return "rb_colorless" }
        return "RuneGlyph" + domain.lowercased().capitalized
    }

    /// "Champion" for champion units, else the card type ("Token" when the feed has none).
    static func kind(_ card: Card) -> String {
        if card.isChampionUnit { return "Champion" }
        if !card.typeName.isEmpty { return card.typeName }
        return card.classification?.supertype ?? "Card"
    }

    /// Riot's CDN resizes on request: tiles get a WebP at their width (about 20 KB instead of the PNG).
    /// Widths are bucketed so tiles of similar size share one file.
    static func imageURL(_ card: Card, widthPoints: CGFloat, scale: CGFloat) -> URL? {
        guard let raw = card.media?.imageUrl else { return nil }
        guard raw.contains("rgpub.io") else { return URL(string: raw) }
        let pixels = Int(widthPoints * scale)
        let width = min(800, max(160, (pixels + 79) / 80 * 80))
        return URL(string: raw + (raw.contains("?") ? "&" : "?") + "w=\(width)&fm=webp")
    }
}

/// The rarity mark: a small square on its corner.
struct Gem: View {
    let color: Color
    var size: CGFloat = 6

    var body: some View {
        Rectangle().fill(color).frame(width: size, height: size).rotationEffect(.degrees(45))
    }
}
