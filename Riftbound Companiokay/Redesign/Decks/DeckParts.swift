//
//  DeckParts.swift
//  Riftbound Companiokay
//
//  Pieces of the deck screen, its sheets and the builder (Android `DeckParts.kt`, `DeckGallery.kt`, `Stepper.kt`):
//  the small ghost button, card rows, the segmented control with its sliding knob, the rune pool, the
//  pile gallery, the stepper whose count blurs away, notices and the mocks' delayed rise.
//

import SwiftUI

extension Card {
    /// A card the list no longer knows: its name on a blank face.
    static func placeholder(id: String, name: String) -> Card {
        Card(id: id, name: name, riftboundId: nil, publicCode: nil, collectorNumber: nil, attributes: nil, classification: nil,
             text: nil, set: nil, media: nil, tags: nil, orientation: nil, metadata: nil, unreleased: nil)
    }

    /// "Fury · 5 energy · 5 might".
    var unitLine: String {
        [domains.joined(separator: " · "), attributes?.energy.map { "\($0) energy" }, attributes?.might.map { "\($0) might" }]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// "Unit · 1 power · 3 might" (might only for units, like the mock).
    var typeLine: String {
        let power = attributes?.power.flatMap { $0 > 0 ? "\($0) power" : nil }
        let might = typeName.lowercased() == "unit" ? attributes?.might.map { "\($0) might" } : nil
        return [CardStyle.kind(self), power, might].compactMap { $0 }.joined(separator: " · ")
    }

    /// The plain rules text without bracket codes, for one-line summaries ("[Reaction][>] Kill" → "Reaction → Kill").
    var summary: String? {
        guard let plain = text?.plain else { return nil }
        let clean = plain.replacingOccurrences(of: "[>]", with: " →")
            .replacingOccurrences(of: #"\[([^\]]+)\]"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return clean.isEmpty ? nil : clean
    }
}

/// The mock's `.fade` with its delay: up 14pt out of a blur of 8; everything leaves in 200ms.
private struct RiseIn: ViewModifier {
    let shown: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .blur(radius: shown ? 0 : 8)
            .animation(shown ? .rift(0.7).delay(delay) : .linear(duration: 0.2), value: shown)
    }
}

extension View {
    func riseIn(_ shown: Bool, delay: Double) -> some View { modifier(RiseIn(shown: shown, delay: delay)) }
}

/// Thin line under list rows.
struct Hairline: View {
    var opacity = 0.06

    var body: some View { Rectangle().fill(.white.opacity(opacity)).frame(height: 1) }
}

/// Ringed ghost pill (34pt).
struct SmallButton: View {
    let text: String
    var height: CGFloat = 34
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(RiftFont.text(12.5, .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: height)
                .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(PressScale(scale: 0.95))
    }
}

/// The mock's `.btn`: 50pt pill, ghost, green or amber.
struct WideButton: View {
    let text: String
    var fill: Color = .white.opacity(0.1)
    var ink: Color = .white
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(RiftFont.text(14, .semibold))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(fill, in: Capsule())
                .shadow(color: fill == RiftColor.you ? RiftColor.you.opacity(0.35) : .clear, radius: 10)
                .contentShape(Capsule())
        }
        .buttonStyle(PressScale(scale: 0.96))
        .opacity(enabled ? 1 : 0.35)
        .disabled(!enabled)
    }
}

/// The mock's `.crow`: energy in the card's colour, name, type line with SIG / CHAMP tags and the copies.
struct CardRow: View {
    let entry: DecklistEntry
    let card: Card?
    let chosen: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(card?.attributes?.energy.map(String.init) ?? "–")
                .font(RiftFont.display(24))
                .foregroundStyle(CardStyle.domainColor(card?.domains.first))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(card?.name ?? entry.cardName).font(RiftFont.text(15, .semibold)).foregroundStyle(.white).lineLimit(1)
                HStack(spacing: 6) {
                    Text(card?.typeLine ?? "Not in the card list").font(RiftFont.text(11.5)).foregroundStyle(.white.opacity(0.58)).lineLimit(1)
                    if card?.isSignature == true { Tag(text: "SIG", color: Color(hex: "C08BFF")) }
                    if chosen { Tag(text: "CHAMP", color: RiftColor.you) }
                }
            }
            Spacer(minLength: 8)
            Text("×\(entry.count)").font(RiftFont.display(20)).foregroundStyle(.white)
        }
        .frame(height: 56)
        .overlay(alignment: .bottom) { Hairline() }
        .accessibilityElement(children: .combine)
    }
}

private struct Tag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .caps(9, tracking: 0.1, weight: .bold)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.17), in: RoundedRectangle(cornerRadius: 5))
    }
}

/// The mock's segmented control with the sliding white knob (Main / Side / Runes, Gallery / List …).
struct Segmented: View {
    let labels: [String]
    let selected: Int
    var height: CGFloat = 44
    let onPick: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width / CGFloat(max(labels.count, 1))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white)
                    .frame(width: w)
                    .offset(x: CGFloat(selected) * w)
                    .animation(.rift(0.52), value: selected)
                HStack(spacing: 0) {
                    ForEach(labels.indices, id: \.self) { i in
                        Button { onPick(i) } label: {
                            Text(labels[i])
                                .font(RiftFont.text(13.5, .semibold))
                                .monospacedDigit()
                                .foregroundStyle(i == selected ? Color.black : .white.opacity(0.8))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.3), value: selected)
                        .accessibilityAddTraits(i == selected ? .isSelected : [])
                    }
                }
            }
        }
        .padding(3)
        .frame(height: height)
        .background(.white.opacity(0.06), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
    }
}

/// − count + with ghost buttons; the count blurs up and out and the new one rises in.
struct GhostStepper: View {
    let count: Int
    let what: String
    var minus = true
    var plus = true
    var size: CGFloat = 38
    let onMinus: () -> Void
    let onPlus: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            button("−", label: "Remove one \(what)", enabled: minus, action: onMinus)
            ZStack {
                Text("\(count)")
                    .font(RiftFont.display(size * 0.63))
                    .foregroundStyle(.white)
                    .fixedSize()
                    .id(count)
                    .transition(.scoreMorph(height: size, inDuration: 0.62, outDuration: 0.42))
            }
            .frame(width: 30, height: size)
            .animation(.rift(0.62), value: count)
            .accessibilityLabel("\(count) × \(what)")
            button("+", label: "Add one \(what)", enabled: plus, action: onPlus)
        }
    }

    private func button(_ text: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(RiftFont.text(size * 0.47, .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(.white.opacity(0.06), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(PressScale(scale: 0.9))
        .opacity(enabled ? 1 : 0.3)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

/// Rune rows for the legend's domains, the 12 pips and the total; steppers only where `onStep` edits (the builder).
struct RunePool: View {
    let domains: [String]
    let count: (String) -> Int
    let total: Int
    var onStep: ((String, Int) -> Void)? = nil

    var body: some View {
        if domains.isEmpty {
            Text("Pick a legend first: its domains decide the runes.")
                .font(RiftFont.text(13.5, .regular))
                .foregroundStyle(.white.opacity(0.66))
                .padding(.vertical, 18)
        } else {
            VStack(spacing: 0) {
                ForEach(domains, id: \.self) { domain in row(domain) }
                pips.padding(.top, 16).padding(.bottom, 6)
                HStack {
                    Text("Rune pool")
                    Spacer()
                    Text("\(total) / \(DeckRules.runes)")
                }
                .font(RiftFont.text(12, .semibold))
                .foregroundStyle(.white.opacity(0.66))
            }
        }
    }

    private func row(_ domain: String) -> some View {
        let n = count(domain)
        let color = CardStyle.domainColor(domain)
        // A full pool of two domains still trades one rune for the other.
        let canAdd = total < DeckRules.runes || (domains.count == 2 && domains.contains { $0 != domain && count($0) > 0 })
        return HStack(spacing: 0) {
            Image(CardStyle.glyph(domain))
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(.black)
                .frame(width: 40, height: 40)
                .background(color, in: Circle())
                .shadow(color: color.opacity(0.53), radius: 8)
            Text("\(domain) Rune").font(RiftFont.text(15.5, .semibold)).foregroundStyle(.white).padding(.leading, 12)
            Spacer(minLength: 8)
            if let onStep {
                GhostStepper(count: n, what: "\(domain) rune", minus: n > 0, plus: canAdd, size: 32,
                             onMinus: { onStep(domain, -1) }, onPlus: { onStep(domain, 1) })
            } else {
                Text("×\(n)").font(RiftFont.display(20)).foregroundStyle(.white)
            }
        }
        .frame(height: 64)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var pips: some View {
        let lit = domains.flatMap { domain in Array(repeating: domain, count: count(domain)) }
        return HStack(spacing: 5) {
            ForEach(0..<DeckRules.runes, id: \.self) { i in
                let color = i < lit.count ? CardStyle.domainColor(lit[i]) : nil
                RoundedRectangle(cornerRadius: 5)
                    .fill(color ?? .white.opacity(0.1))
                    .frame(height: 10)
                    .shadow(color: (color ?? .clear).opacity(0.6), radius: 5)
                    .animation(.easeInOut(duration: 0.4), value: color)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(total) of \(DeckRules.runes) runes")
    }
}

/// The deck screen's piles: group headers with their counts, then three cards to a row (or list rows), the
/// copies on each.
struct PileGallery: View {
    let entries: [DecklistEntry]
    let cards: [String: Card]
    let byEnergy: Bool
    let championId: String?
    let list: Bool

    var body: some View {
        // A card the list no longer knows still shows, as its name on a blank face.
        let resolved = entries.map { entry in (cards[entry.cardId] ?? Card.placeholder(id: entry.cardId, name: entry.cardName), entry.count) }
        VStack(alignment: .leading, spacing: 0) {
            ForEach(DeckGallery.groups(resolved, byEnergy: byEnergy), id: \.label) { group in
                GroupHeader(label: group.label, count: group.cards.reduce(0) { $0 + $1.1 })
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                if list {
                    ForEach(group.cards, id: \.0.id) { card, count in
                        CardRow(entry: DecklistEntry(cardId: card.id, cardName: card.name, count: count), card: cards[card.id], chosen: card.id == championId)
                    }
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(group.cards, id: \.0.id) { card, count in
                            CardTile(card: card, errata: false, imageWidth: 120)
                                .aspectRatio(cardAspect, contentMode: .fit)
                                .overlay(alignment: .topTrailing) { CountBadge(count: count, filled: false) }
                                .overlay(alignment: .topLeading) { if card.id == championId { ChampTag() } }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(card.name), \(count)\(card.id == championId ? ", chosen champion" : "")")
                        }
                    }
                }
            }
        }
    }
}

struct CountBadge: View {
    let count: Int
    let filled: Bool

    var body: some View {
        Text("\(count)")
            .font(RiftFont.text(13, .bold))
            .monospacedDigit()
            .foregroundStyle(filled ? Color.black : .white)
            .frame(width: 26, height: 26)
            .background(filled ? RiftColor.you : .black.opacity(0.72), in: Circle())
            .overlay(Circle().stroke(filled ? RiftColor.you : .white.opacity(0.3), lineWidth: 1))
            .padding(6)
    }
}

private struct ChampTag: View {
    var body: some View {
        Text("CHAMP")
            .caps(9, tracking: 0.1, weight: .bold)
            .foregroundStyle(.black)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RiftColor.you, in: RoundedRectangle(cornerRadius: 5))
            .padding(6)
    }
}

/// A gold warning or the green all-clear line (builder save page, deck check).
struct Notice: View {
    let text: String
    let color: Color
    let symbol: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14)
        let clear = color == RiftColor.you
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(color)
            Text(text)
                .font(RiftFont.text(13.5, clear ? .semibold : .medium))
                .foregroundStyle(clear ? color : .white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(color.opacity(0.08), in: shape)
        .overlay(shape.stroke(color.opacity(0.32), lineWidth: 1))
        .padding(.top, 8)
    }
}

/// Sheet header text.
struct SheetLead: View {
    let text: String

    var body: some View {
        Text(text).font(RiftFont.text(13, .regular)).lineSpacing(4).foregroundStyle(.white.opacity(0.7))
    }
}

/// Caps label of the sheets and blocks.
struct CapsLabel: View {
    let text: String
    var size: CGFloat = 10.5

    var body: some View {
        Text(text.uppercased()).caps(size).foregroundStyle(.white.opacity(0.6))
    }
}
