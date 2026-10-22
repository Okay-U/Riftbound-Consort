//
//  CardDetailOverlay.swift
//  Riftbound Companiokay
//
//  The card opened from the grid (Android `CardDetail.kt`): the tile flies to the top and grows, the frame
//  fades off the art, then the text rises in step by step: name and type line, stats, Riot's errata above
//  the printed text, the rules with their keyword chips, flavour, artist, code and tags. Add to deck below.
//

import SwiftUI

struct CardDetailOverlay: View {
    let card: Card
    let hero: Namespace.ID
    let erratum: CardErratum?
    let inDecks: Int
    let onClose: () -> Void
    let onAdd: () -> Void
    @State private var shown = false

    var body: some View {
        GeometryReader { geo in
            let heroWidth = min(236, geo.size.width * 0.573)
            let heroHeight = heroWidth / cardAspect
            let domain = card.shownDomains.first
            let color = CardStyle.domainColor(domain)
            ZStack(alignment: .top) {
                Color.black.opacity(0.94).ignoresSafeArea().contentShape(Rectangle()).onTapGesture {}
                Ellipse()
                    .fill(RadialGradient(colors: [color.opacity(0.25), .clear], center: .center, startRadius: 0, endRadius: geo.size.width * 0.8))
                    .frame(width: geo.size.width * 1.6, height: geo.size.height * 0.62)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.03)
                    .opacity(shown ? 1 : 0)
                    .allowsHitTesting(false)
                topBar.reveal(shown, step: 0)
                CardTile(card: card, errata: erratum != nil, imageWidth: heroWidth, labels: false)
                    .matchedGeometryEffect(id: card.id, in: hero)
                    .frame(width: heroWidth, height: heroHeight)
                    .offset(y: 58)
                    .accessibilityLabel(card.media?.accessibilityText ?? card.name)
                ScrollView {
                    details(domain: domain, color: color).padding(.horizontal, 22).padding(.top, 4).padding(.bottom, 24)
                }
                .mask {
                    VStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: 12)
                        Rectangle()
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 22)
                    }
                }
                .padding(.top, 58 + heroHeight + 10)
                .padding(.bottom, card.isToken ? 0 : 88)
                // Tokens are made during a game and never go in a deck.
                if !card.isToken {
                    DetailBar(inDecks: inDecks, onAdd: onAdd)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 18)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .reveal(shown, step: 2)
                }
            }
        }
        .onAppear { shown = true }
    }

    private var topBar: some View {
        HStack {
            RoundIcon(symbol: "arrow.left", label: "Back to cards", fill: .white.opacity(0.06), action: onClose)
                .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
            Spacer()
            Text([card.set?.label, card.publicCode?.components(separatedBy: "/").first].compactMap { $0 }.joined(separator: " · ").uppercased())
                .caps(11)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func details(domain: String?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            NameBlock(card: card).reveal(shown, step: 1)
            let stats = Self.stats(card)
            if !stats.isEmpty { StatsRow(stats: stats).reveal(shown, step: 2) }
            if let erratum { ErrataBox(erratum: erratum, domain: domain).reveal(shown, step: 2) }
            let rules = CardTextBlock.parse(card.text?.rich.flatMap { $0.isEmpty ? nil : $0 } ?? card.text?.plain ?? "", domain: domain)
            if !rules.isEmpty { RulesText(blocks: rules).reveal(shown, step: 3) }
            if let flavour = card.text?.flavour, !flavour.isEmpty {
                Text(flavour)
                    .font(RiftFont.text(14.5, .regular))
                    .italic()
                    .lineSpacing(5)
                    .foregroundStyle(.white.opacity(0.74))
                    .padding(.leading, 14)
                    .padding(.vertical, 2)
                    .overlay(alignment: .leading) { Rectangle().fill(color).frame(width: 2) }
                    .reveal(shown, step: 3)
            }
            Meta(card: card).padding(.top, 2).reveal(shown, step: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Energy, power and might; none for legends, battlefields and runes. Gear gives its might as a bonus.
    private static func stats(_ card: Card) -> [(String, String)] {
        guard let a = card.attributes else { return [] }
        var out: [(String, String)] = []
        if let energy = a.energy { out.append(("\(energy)", "Energy")) }
        if let power = a.power { out.append(("\(power)", "Power")) }
        if let might = a.might { out.append((card.typeName.lowercased() == "gear" ? "+\(might)" : "\(might)", "Might")) }
        return out
    }
}

private struct NameBlock: View {
    let card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(Text(card.title).font(RiftFont.display(34)).tracking(0.7))\(card.subtitle.map { Text("  \($0)").font(RiftFont.text(16, .semibold)).foregroundStyle(.white.opacity(0.78)) } ?? Text(""))")
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                ForEach(card.domains, id: \.self) { d in
                    Image(CardStyle.glyph(d)).renderingMode(.template).resizable().scaledToFit().frame(width: 16, height: 16)
                        .foregroundStyle(CardStyle.domainColor(d))
                }
                let type = card.isChampionUnit ? "Champion unit" : CardStyle.kind(card)
                Text(([type] + card.domains).joined(separator: " · ").uppercased()).caps(12, tracking: 0.1).foregroundStyle(.white.opacity(0.76))
                if !card.rarityName.isEmpty {
                    Gem(color: CardStyle.rarityColor(card.rarityName)).padding(.horizontal, 2)
                    Text(card.rarityName.uppercased()).caps(12, tracking: 0.1).foregroundStyle(.white.opacity(0.76))
                }
                if card.isPreview {
                    Text("PREVIEW").caps(10, tracking: 0.1, weight: .bold).foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }
}

private struct StatsRow: View {
    let stats: [(String, String)]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(stats, id: \.1) { value, key in
                VStack(spacing: 2) {
                    Text(value).font(RiftFont.display(30)).foregroundStyle(.white)
                    Text(key.uppercased()).caps(10).foregroundStyle(.white.opacity(0.66))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.1), lineWidth: 1))
            }
            ForEach(stats.count..<3, id: \.self) { _ in Color.clear.frame(maxWidth: .infinity, maxHeight: 64) }
        }
    }
}

/// Riot's corrected wording above the printed one: at a table the correction is what applies.
private struct ErrataBox: View {
    let erratum: CardErratum
    let domain: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text((["Errata · official text"] + [erratum.set].compactMap { $0 }).joined(separator: " · ").uppercased())
                .caps(11, weight: .bold)
                .foregroundStyle(RiftColor.gold)
            RulesText(blocks: CardTextBlock.parse(erratum.newText, domain: domain), size: 15, gap: 6)
                .padding(.top, 8)
                .padding(.bottom, 6)
            if let old = erratum.oldText, !old.isEmpty {
                RulesText(blocks: CardTextBlock.parse("Printed: \(old)", domain: domain), size: 13, color: .white.opacity(0.6), gap: 4, struck: true)
            }
            if let note = erratum.note, !note.isEmpty {
                Text(note).font(RiftFont.text(13)).foregroundStyle(.white.opacity(0.7)).padding(.top, 8)
            }
            // Only Riot's own pages: the link comes from the feed.
            if let url = erratum.sourceURL, url.scheme == "https" {
                Link(destination: url) {
                    Text("Official errata").font(RiftFont.text(14, .semibold)).underline().foregroundStyle(RiftColor.gold)
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RiftColor.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(RiftColor.gold.opacity(0.32), lineWidth: 1))
    }
}

private struct Meta: View {
    let card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Art by \(card.media?.artist ?? "Riot Games")")
                Spacer()
                if let code = card.publicCode { Text(code) }
            }
            .font(RiftFont.text(12.5))
            .foregroundStyle(.white.opacity(0.62))
            if let tags = card.tags, !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(RiftFont.text(11, .semibold))
                            .tracking(0.66)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
                    }
                }
            }
        }
    }
}

private struct DetailBar: View {
    let inDecks: Int
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(inDecks)").font(RiftFont.display(20)).foregroundStyle(.white)
                Text((inDecks == 1 ? "deck" : "decks").uppercased()).caps(11, tracking: 0.1).foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(.white.opacity(0.06), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
            .accessibilityElement(children: .combine)
            Button(action: onAdd) {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 16, weight: .bold))
                    Text("Add to deck").font(RiftFont.text(16, .bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(RiftColor.you, in: Capsule())
                .shadow(color: RiftColor.you.opacity(0.45), radius: 13)
                .contentShape(Capsule())
            }
            .buttonStyle(PressScale(scale: 0.96))
        }
    }
}

private struct Reveal: ViewModifier {
    let shown: Bool
    let step: Int

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .blur(radius: shown ? 0 : 8)
            .animation(.rift(0.7).delay(step == 0 ? 0 : 0.02 + Double(step) * 0.1), value: shown)
    }
}

private extension View {
    /// The mock's `.fade` steps: up 14pt out of a blur of 8, 100ms apart.
    func reveal(_ shown: Bool, step: Int) -> some View { modifier(Reveal(shown: shown, step: step)) }
}
