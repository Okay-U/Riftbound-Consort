//
//  CardText.swift
//  Riftbound Companiokay
//
//  Renders a card's ability text with Riot's glyphs inline. The feed keeps the
//  gallery's HTML in `text.rich`: paragraphs, line breaks, bullet lists and
//  symbol tokens such as `:rb_might:` or `:rb_energy_2:`. Keywords in square
//  brackets are set in bold, as on the printed card.
//

import SwiftUI
import UIKit

/// Asset names for the `:rb_*:` symbol tokens Riot uses in card text.
enum CardSymbol {
    /// Asset for a token body (the part between the colons), nil when unknown.
    static func asset(for token: String) -> String? {
        switch token {
        case "might":          return "rb_might"
        case "exhaust":        return "rb_exhaust"
        case "rune_rainbow":   return "rb_rune_rainbow"
        case "rune_fury":      return "RuneFury"
        case "rune_calm":      return "RuneCalm"
        case "rune_mind":      return "RuneMind"
        case "rune_body":      return "RuneBody"
        case "rune_order":     return "RuneOrder"
        case "rune_chaos":     return "RuneChaos"
        case "colorless":      return "rb_colorless"
        default:
            if token.hasPrefix("energy_"), let n = Int(token.dropFirst("energy_".count)), (0...12).contains(n) {
                return "rb_energy_\(n)"
            }
            return nil
        }
    }

    /// Riot's errata articles and alt text write symbols as bracket codes:
    /// `[A]` any rune, `[C]` the card's own domain rune, `[E]` exhaust,
    /// `[M]`/`[S]` might, `[3]` energy. Anything else is a keyword.
    static func asset(forCode code: String, domain: String?) -> String? {
        switch code {
        case "A":      return "rb_rune_rainbow"
        case "E":      return "rb_exhaust"
        case "M", "S": return "rb_might"
        case "C":      return domain.flatMap(CardFilters.runeAssetName(for:)) ?? "rb_rune_rainbow"
        default:
            if let n = Int(code), (0...12).contains(n) { return "rb_energy_\(n)" }
            return nil
        }
    }

    /// Glyph for a card type label ("Unit", "Spell", …), nil for unknown types.
    static func typeAsset(for type: String) -> String? {
        switch type.lowercased() {
        case "unit":        return "rb_type_unit"
        case "spell":       return "rb_type_spell"
        case "gear":        return "rb_type_gear"
        case "legend":      return "rb_type_legend"
        case "battlefield": return "rb_type_battlefield"
        case "rune":        return "rb_type_rune"
        default:            return nil
        }
    }
}

/// One paragraph or bullet of card text, split into runs.
nonisolated struct CardTextBlock: Equatable {
    enum Run: Equatable {
        case text(String)
        case keyword(String)
        case symbol(asset: String)
    }
    let isBullet: Bool
    let runs: [Run]

    /// Splits the gallery HTML into blocks. Unknown tags are dropped, unknown
    /// symbols fall back to their token name so nothing disappears silently.
    static func parse(_ html: String, domain: String? = nil) -> [CardTextBlock] {
        var blocks: [CardTextBlock] = []
        var current: [Run] = []
        var isBullet = false
        func flush() {
            let trimmed = trim(current)
            if !trimmed.isEmpty { blocks.append(CardTextBlock(isBullet: isBullet, runs: trimmed)) }
            current = []
        }
        var rest = Substring(html)
        while let open = rest.firstIndex(of: "<") {
            appendText(String(rest[..<open]), domain: domain, to: &current)
            guard let close = rest[open...].firstIndex(of: ">") else { break }
            let tag = rest[rest.index(after: open)..<close].lowercased()
            rest = rest[rest.index(after: close)...]
            switch tag {
            case "br", "br/", "br /": current.append(.text("\n"))
            case "p", "ul": flush(); isBullet = false
            case "/p", "/ul": flush(); isBullet = false
            case "li": flush(); isBullet = true
            case "/li": flush(); isBullet = false
            default: break
            }
        }
        appendText(String(rest), domain: domain, to: &current)
        flush()
        return blocks
    }

    private static func appendText(_ raw: String, domain: String?, to runs: inout [Run]) {
        guard !raw.isEmpty else { return }
        let text = raw
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        // Symbol tokens and [Keywords] become their own runs.
        let pattern = #":rb_([a-z0-9_]+):|\[([^\]]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { runs.append(.text(text)); return }
        let ns = text as NSString
        var cursor = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            if match.range.location > cursor {
                runs.append(.text(ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))))
            }
            if match.range(at: 1).location != NSNotFound {
                let token = ns.substring(with: match.range(at: 1))
                if let asset = CardSymbol.asset(for: token) { runs.append(.symbol(asset: asset)) }
                else { runs.append(.text(token.replacingOccurrences(of: "_", with: " "))) }
            } else {
                let code = ns.substring(with: match.range(at: 2))
                if let asset = CardSymbol.asset(forCode: code, domain: domain) { runs.append(.symbol(asset: asset)) }
                else { runs.append(.keyword(code)) }
            }
            cursor = match.range.location + match.range.length
        }
        if cursor < ns.length { runs.append(.text(ns.substring(from: cursor))) }
    }

    private static func trim(_ runs: [Run]) -> [Run] {
        var out = runs
        while case .text(let t)? = out.first, t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { out.removeFirst() }
        while case .text(let t)? = out.last, t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { out.removeLast() }
        if case .text(let t)? = out.first { out[0] = .text(String(t.drop(while: { $0 == "\n" }))) }
        if case .text(let t)? = out.last, !out.isEmpty {
            var s = t; while s.hasSuffix("\n") { s.removeLast() }; out[out.count - 1] = .text(s)
        }
        return out
    }
}

/// Card ability text with inline glyphs. Falls back to the plain text when the
/// feed carries no HTML.
struct CardTextView: View {
    let rich: String?
    let plain: String?
    /// The card's first domain, for the `[C]` code in errata text.
    var domain: String? = nil

    /// Point size of an inline glyph. `Text(Image(asset))` draws asset images at
    /// their intrinsic size (the SVGs are 24 pt) and ignores the font, so the
    /// glyph is rasterised at this size first. Template assets keep tinting
    /// with the text colour.
    static let glyphSize: CGFloat = 18
    /// Negative moves the glyph down; the glyph's bottom otherwise sits on the baseline.
    static let glyphBaselineOffset: CGFloat = -3

    private static var glyphCache: [String: UIImage] = [:]

    private static func glyph(_ asset: String) -> Image {
        if let cached = glyphCache[asset] { return Image(uiImage: cached) }
        guard let base = UIImage(named: asset) else { return Image(asset) }
        let size = CGSize(width: glyphSize, height: glyphSize)
        let drawn = UIGraphicsImageRenderer(size: size).image { _ in
            base.draw(in: CGRect(origin: .zero, size: size))
        }
        let mode: UIImage.RenderingMode = base.renderingMode == .alwaysTemplate ? .alwaysTemplate : .alwaysOriginal
        let scaled = drawn.withRenderingMode(mode)
        glyphCache[asset] = scaled
        return Image(uiImage: scaled)
    }

    var body: some View {
        let source = (rich?.isEmpty == false ? rich : plain) ?? ""
        let blocks = CardTextBlock.parse(source, domain: domain)
        if blocks.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if block.isBullet { Text("•") }
                        Self.line(block.runs)
                    }
                }
            }
            .font(.body)
        }
    }

    private static func line(_ runs: [CardTextBlock.Run]) -> Text {
        runs.reduce(Text("")) { acc, run in
            switch run {
            case .text(let s):    return acc + Text(s)
            case .keyword(let k): return acc + Text("[\(k)]").bold()
            case .symbol(let a):  return acc + Text(glyph(a)).baselineOffset(glyphBaselineOffset)
            }
        }
    }
}

#if DEBUG
#Preview {
    CardTextView(rich: "<p>[Equip] :rb_rune_fury: (:rb_rune_fury:: Attach this to a unit you control.)<br />The first time I move each turn, [Add] :rb_energy_1::rb_rune_rainbow:.</p><ul><li>Choose up to 3 cards. Their owners recycle them.</li><li>Draw 1.</li></ul>", plain: nil)
        .padding()
}
#endif
