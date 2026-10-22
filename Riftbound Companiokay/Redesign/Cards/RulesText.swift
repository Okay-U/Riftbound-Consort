//
//  RulesText.swift
//  Riftbound Companiokay
//
//  Card text as the mock sets it (Android `RulesText.kt`): one paragraph per line, [Keywords] as soft chips,
//  reminder text in parentheses in italics, Riot's symbols inline at text size. Parsing is the classic
//  `CardTextBlock`; chips and symbols are drawn once into images that flow with the text.
//

import SwiftUI
import UIKit

struct RulesText: View {
    let blocks: [CardTextBlock]
    var size: CGFloat = 15.5
    var color: Color = .white
    var gap: CGFloat = 10
    /// The printed text under an erratum.
    var struck = false

    var body: some View {
        VStack(alignment: .leading, spacing: gap) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if line.bullet { Text("•") }
                    text(line.runs)
                        .strikethrough(struck)
                        .lineSpacing(size * 0.32)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(RiftFont.text(size, .regular))
        .foregroundStyle(color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    /// A block's runs split at its line breaks; only the first line of a list item carries the bullet.
    private var lines: [(bullet: Bool, runs: [CardTextBlock.Run])] {
        var out: [(Bool, [CardTextBlock.Run])] = []
        for block in blocks {
            var current: [CardTextBlock.Run] = []
            var first = true
            func flush() {
                let trimmed = Self.trim(current)
                if !trimmed.isEmpty {
                    out.append((block.isBullet && first, trimmed))
                    first = false
                }
                current = []
            }
            for run in block.runs {
                if case .text(let s) = run, s.contains("\n") {
                    for (i, part) in s.components(separatedBy: "\n").enumerated() {
                        if i > 0 { flush() }
                        if !part.isEmpty { current.append(.text(part)) }
                    }
                } else {
                    current.append(run)
                }
            }
            flush()
        }
        return out
    }

    private static func trim(_ runs: [CardTextBlock.Run]) -> [CardTextBlock.Run] {
        var out = runs
        if case .text(let s)? = out.first { out[0] = .text(String(s.drop { $0 == " " })) }
        if case .text(let s)? = out.last {
            var t = s
            while t.hasSuffix(" ") { t.removeLast() }
            out[out.count - 1] = .text(t)
        }
        return out.filter { if case .text(let s) = $0 { return !s.isEmpty } else { return true } }
    }

    private func text(_ runs: [CardTextBlock.Run]) -> Text {
        var result = Text("")
        // Inside reminder text a keyword is just a word, as on the printed card.
        var depth = 0
        func plain(_ s: String) {
            guard !s.isEmpty else { return }
            if depth > 0 {
                result = Text("\(result)\(Text(s).italic().foregroundStyle(color.opacity(0.62)))")
            } else {
                result = Text("\(result)\(s)")
            }
        }
        for run in runs {
            switch run {
            case .text(let s):
                var part = ""
                for ch in s {
                    switch ch {
                    case "(":
                        plain(part)
                        part = "("
                        depth += 1
                    case ")":
                        part.append(ch)
                        plain(part)
                        part = ""
                        depth = max(0, depth - 1)
                    default:
                        part.append(ch)
                    }
                }
                plain(part)
            case .keyword(let word):
                if depth > 0 {
                    plain(word)
                } else {
                    let chip = InlineArt.chip(word, size: size)
                    result = Text("\(result)\(Text(Image(uiImage: chip.image)).baselineOffset(chip.offset))")
                }
            case .symbol(let asset):
                if let glyph = InlineArt.symbol(asset, size: size) {
                    result = Text("\(result)\(Text(Image(uiImage: glyph.image)).baselineOffset(glyph.offset))")
                } else {
                    plain(asset)
                }
            case .arrow:
                result = Text("\(result)\(Text(" → ").bold())")
            }
        }
        return result
    }

    /// What VoiceOver reads: the words, with symbols named.
    private var spoken: String {
        lines.map { line in
            line.runs.map { run in
                switch run {
                case .text(let s): return s
                case .keyword(let k): return k
                case .symbol(let asset): return " \(InlineArt.label(asset)) "
                case .arrow: return ": "
                }
            }.joined()
        }.joined(separator: "\n")
    }
}

/// Keyword chips and Riot's symbols, drawn once per size into images that sit on the text's line.
@MainActor
private enum InlineArt {
    struct Piece {
        let image: UIImage
        let offset: CGFloat
    }

    private static var chips: [String: Piece] = [:]
    private static var symbols: [String: Piece] = [:]

    static func chip(_ word: String, size: CGFloat) -> Piece {
        let key = "\(word)|\(size)"
        if let hit = chips[key] { return hit }
        let font = UIFont(name: "Barlow-Bold", size: size) ?? .boldSystemFont(ofSize: size)
        let text = NSAttributedString(string: word, attributes: [.font: font, .foregroundColor: UIColor.white])
        let textSize = text.size()
        let box = CGSize(width: ceil(textSize.width + 14), height: ceil(size * 1.4))
        let image = UIGraphicsImageRenderer(size: box).image { _ in
            UIColor.white.withAlphaComponent(0.12).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: box), cornerRadius: 7).fill()
            text.draw(at: CGPoint(x: (box.width - textSize.width) / 2, y: (box.height - textSize.height) / 2))
        }
        let piece = Piece(image: image, offset: -(box.height - font.capHeight) / 2)
        chips[key] = piece
        return piece
    }

    /// Template symbols take the text's colour; the coloured runes stay as Riot draws them.
    static func symbol(_ asset: String, size: CGFloat) -> Piece? {
        let key = "\(asset)|\(size)"
        if let hit = symbols[key] { return hit }
        guard let base = UIImage(named: asset) else { return nil }
        let side = ceil(size * 1.15)
        let drawn = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            base.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        let image = drawn.withRenderingMode(base.renderingMode == .alwaysTemplate ? .alwaysTemplate : .alwaysOriginal)
        let font = UIFont(name: "Barlow-Regular", size: size) ?? .systemFont(ofSize: size)
        let piece = Piece(image: image, offset: -(side - font.capHeight) / 2)
        symbols[key] = piece
        return piece
    }

    static func label(_ asset: String) -> String {
        switch asset {
        case "rb_might": return "might"
        case "rb_exhaust": return "exhaust"
        case "rb_rune_rainbow": return "any rune"
        case "rb_colorless": return "colorless"
        default:
            if asset.hasPrefix("rb_energy_") { return "\(asset.dropFirst("rb_energy_".count)) energy" }
            let rune = asset.hasPrefix("Rune") ? String(asset.dropFirst(4)) : asset.replacingOccurrences(of: "rune_", with: "").capitalized
            return "\(rune) rune"
        }
    }
}
