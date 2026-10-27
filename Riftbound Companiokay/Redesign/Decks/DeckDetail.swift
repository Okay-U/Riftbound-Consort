//
//  DeckDetail.swift
//  Riftbound Companiokay
//
//  An open deck (Android `DeckDetail.kt`): the legend card grows from its pile into the banner, the champion
//  and the three battlefields fly out of the pile into their places, the rest rises in step by step; closing
//  plays it backwards. Main, side and runes are there to look at; changes go through the builder.
//

import SwiftUI
import UIKit

/// What the deck screen's buttons open.
enum DeckTool: String, Identifiable {
    case hand, odds, stats, export, champion, fields, menu, issues
    var id: String { rawValue }
}

/// The Decks tab's coordinate space: the pile and the fly-outs are measured in it.
let decksSpace = "decks"

struct RiftDeckDetail: View {
    let deck: Decklist
    let cards: [String: Card]
    let record: Tally
    /// The pile's frame in `decksSpace`.
    let pile: CGRect
    let closing: Bool
    let space: Namespace.ID
    /// The match log grew out of the History tool.
    let logOpen: Bool
    let onClose: () -> Void
    let onClosed: () -> Void
    let onTool: (DeckTool) -> Void
    let onLog: () -> Void
    @AppStorage("deckByEnergy") private var byEnergy = false
    @AppStorage("deckAsList") private var asList = false
    @Environment(\.riftPage) private var page
    @State private var appeared = false
    @State private var morph: CGFloat = 0
    @State private var atHero = false
    /// Closing began: an opening still under way must not settle on the banner.
    @State private var leaving = false
    @State private var tab = 0
    @State private var tabKey = 0
    @State private var splashes: [URL: UIImage] = [:]

    private var shown: Bool { appeared && !closing }
    private static let heroHeight: CGFloat = 250

    /// The legend's centred splash from Data Dragon, as on the scoreboard: the card's own art crops badly in the
    /// wide banner (Okay 2026-10-27). Nil until it has loaded; the card's art stays where it is missing.
    private var splashURL: URL? { deck.legend.flatMap { LegendArt.url(legend: $0.cardName) } }
    private var splash: UIImage? { splashURL.flatMap { splashes[$0] } }

    var body: some View {
        let legend = deck.legend.flatMap { cards[$0.cardId] }
        // The outer reader keeps the safe area, so it knows the status bar and the home indicator; one that
        // ignores it reads 0 there (the buttons sat under the clock, Okay 2026-10-26). The deck runs under both.
        GeometryReader { outer in
            let safeTop = outer.safeAreaInsets.top
            let safeBottom = outer.safeAreaInsets.bottom
            GeometryReader { geo in
                let own = geo.frame(in: .named(decksSpace))
                ZStack(alignment: .topLeading) {
                    page
                        .opacity(shown ? 1 : 0)
                        .animation(.linear(duration: 0.42), value: shown)
                    if !atHero {
                        morphLayer(legend, from: pile.offsetBy(dx: -own.minX, dy: -own.minY),
                                   to: CGRect(x: 0, y: 0, width: geo.size.width, height: Self.heroHeight + safeTop))
                    }
                    ScrollView {
                        VStack(spacing: 0) {
                            hero(legend, width: geo.size.width, safeTop: safeTop)
                            tools
                            championBlock
                            fieldsBlock
                            pileTabs(legend)
                        }
                        .padding(.bottom, 40 + safeBottom)
                    }
                    .scrollIndicators(.hidden)
                    // The banner runs under the status bar; the hero pads its own controls.
                    .ignoresSafeArea()
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            // A turn later, once the fly-outs know where they land.
            Task {
                appeared = true
                withAnimation(.rift(0.7)) { morph = 1 } completion: { if !leaving { atHero = true } }
            }
        }
        .onChange(of: closing) { _, now in
            guard now else { return }
            leaving = true
            atHero = false
            withAnimation(.timingCurve(0.2, 0, 0, 1, duration: 0.56).delay(0.08)) { morph = 0 } completion: { onClosed() }
        }
        // Decoded before it shows, so the opening runs smooth.
        .task(id: splashURL) {
            guard let url = splashURL, splashes[url] == nil, let image = await ImageCache.shared.image(for: url) else { return }
            let ready = await image.byPreparingForDisplay() ?? image
            if Task.isCancelled { return }
            withAnimation(.easeInOut(duration: 0.6)) { splashes[url] = ready }
        }
    }

    // MARK: - Banner

    /// The card's art with the splash over it at `reveal`.
    private func heroArt(_ legend: Card?, width: CGFloat, reveal: CGFloat = 1) -> some View {
        ArtBox(card: legend, imageWidth: width, initial: String((legend?.title ?? deck.name).prefix(1)), previewWidth: 120)
            .overlay {
                if let splash {
                    Color.clear
                        .overlay { Image(uiImage: splash).resizable().scaledToFill() }
                        .clipped()
                        .opacity(reveal)
                }
            }
            .overlay { BottomShade(from: 0.3) }
    }

    /// The pile's top card becoming the banner; its own frame per step, so the art crops instead of stretching.
    /// The splash fades in as it grows, so the pile's card turns into it (and back on closing).
    private func morphLayer(_ legend: Card?, from: CGRect, to: CGRect) -> some View {
        let p = morph
        let rect = CGRect(
            x: from.minX + (to.minX - from.minX) * p, y: from.minY + (to.minY - from.minY) * p,
            width: from.width + (to.width - from.width) * p, height: from.height + (to.height - from.height) * p
        )
        return heroArt(legend, width: to.width, reveal: p)
            .frame(width: rect.width, height: rect.height)
            .clipShape(RoundedRectangle(cornerRadius: 12 * (1 - p)))
            .offset(x: rect.minX, y: rect.minY)
            .allowsHitTesting(false)
    }

    private func hero(_ legend: Card?, width: CGFloat, safeTop: CGFloat) -> some View {
        ZStack {
            if atHero { heroArt(legend, width: width) }
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    DarkIcon(symbol: "chevron.left", label: "Back to the table", action: onClose)
                    Spacer()
                    DarkIcon(symbol: "pencil", label: "Rename, edit or delete the deck") { onTool(.menu) }
                    DarkIcon(symbol: "square.and.arrow.up", label: "Export as text") { onTool(.export) }
                }
                .riseIn(shown, delay: 0.22)
                Spacer(minLength: 8)
                VStack(alignment: .leading, spacing: 8) {
                    Text(deck.name)
                        .font(RiftFont.display(44))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 10) {
                        Text((legend?.title ?? "No legend").uppercased())
                            .caps(11.5, tracking: 0.12)
                            .foregroundStyle(.white.opacity(0.85))
                        Button { onTool(.issues) } label: {
                            LegalChip(status: DeckRules.status(deck, cards: cards), onDark: true)
                        }
                        .buttonStyle(PressScale(scale: 0.95))
                        .accessibilityLabel("What the deck still needs")
                    }
                }
                .riseIn(shown, delay: 0.32)
            }
            .padding(.horizontal, 16)
            .padding(.top, safeTop + 16)
            .padding(.bottom, 18)
        }
        .frame(width: width, height: Self.heroHeight + safeTop)
        .clipped()
    }

    // MARK: - Tools

    private var tools: some View {
        HStack(alignment: .top, spacing: 8) {
            ToolButton(label: "Draw hand", symbol: "rectangle.on.rectangle.angled") { onTool(.hand) }
            ToolButton(label: "Odds", symbol: "percent") { onTool(.odds) }
            ToolButton(label: "Stats", symbol: "chart.bar") { onTool(.stats) }
            ToolButton(label: record.games > 0 ? record.text : "History", symbol: "clock.arrow.circlepath", grows: (space, logOpen), action: onLog)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 4)
        .riseIn(shown, delay: 0.32)
    }

    // MARK: - Champion and battlefields

    private var championBlock: some View {
        let champion = deck.champion.flatMap { cards[$0.cardId] }
        return DeckBlock(shown: shown) {
            HStack {
                CapsLabel(text: "Chosen champion", size: 11)
                Spacer()
                if let champion {
                    CapsLabel(text: "\(DeckRules.copies(of: champion, in: deck, cards: cards)) of \(DeckRules.copyLimit) copies", size: 11)
                }
            }
            .riseIn(shown, delay: 0.42)
            HStack(spacing: 14) {
                MiniCard(card: champion)
                    .modifier(FlyFromPile(pile: pile, shown: shown, index: 0, rotation: -7))
                VStack(alignment: .leading, spacing: 2) {
                    Text(champion?.name ?? deck.champion?.cardName ?? "No champion yet")
                        .font(RiftFont.text(16, .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    if let champion {
                        Text(champion.unitLine).font(RiftFont.text(12.5)).foregroundStyle(.white.opacity(0.62))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .riseIn(shown, delay: 0.42)
                SmallButton(text: champion == nil ? "Pick" : "Swap") { onTool(.champion) }
                    .riseIn(shown, delay: 0.42)
            }
            .padding(.top, 10)
        }
    }

    private var fieldsBlock: some View {
        DeckBlock(shown: shown) {
            HStack {
                CapsLabel(text: "Battlefields", size: 11)
                Spacer()
                SmallButton(text: "Edit · \(deck.battlefields.count) / \(DeckRules.battlefields)", height: 28) { onTool(.fields) }
            }
            .riseIn(shown, delay: 0.42)
            HStack(spacing: 6) {
                ForEach(0..<DeckRules.battlefields, id: \.self) { i in
                    let entry = i < deck.battlefields.count ? deck.battlefields[i] : nil
                    FieldTile(entry: entry, card: entry.flatMap { cards[$0.cardId] })
                        .modifier(FlyFromPile(pile: pile, shown: shown, index: i + 1, rotation: (i + 1) % 2 == 1 ? 7 : -7))
                }
            }
            .padding(.top, 10)
        }
    }

    // MARK: - Main, side, runes

    private func pileTabs(_ legend: Card?) -> some View {
        let runes = DeckRules.total(deck.runes)
        let labels = ["Main \(DeckRules.total(deck.mainDeck))", "Side \(DeckRules.total(deck.sideDeck))", "Runes \(runes)"]
        return VStack(alignment: .leading, spacing: 0) {
            Segmented(labels: labels, selected: tab) { pick in
                guard pick != tab else { return }
                tab = pick
                tabKey += 1
            }
            .padding(.top, 18)
            .padding(.bottom, 6)
            .riseIn(shown, delay: 0.52)
            Group {
                if tab == 2 {
                    RunePool(domains: legend?.shownDomains ?? [], count: { DeckEdits.runeCount(deck, domain: $0, cards: cards) }, total: runes)
                } else {
                    pileList(tab == 0 ? .main : .side)
                }
            }
            .modifier(TabRise(replay: tabKey > 0))
            .id(tabKey)
            .opacity(shown ? 1 : 0)
            .offset(x: shown ? 0 : -14)
            .animation(shown ? .rift(0.7).delay(0.56) : .linear(duration: 0.16), value: shown)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func pileList(_ pile: Pile) -> some View {
        let rows = DeckEdits.entries(deck, pile).sorted { a, b in
            let (ea, eb) = (cards[a.cardId]?.attributes?.energy ?? 99, cards[b.cardId]?.attributes?.energy ?? 99)
            return ea != eb ? ea < eb : a.cardName.lowercased() < b.cardName.lowercased()
        }
        if rows.isEmpty {
            Text(pile == .main ? "No cards yet. Add them in the builder (pencil above) or from the Cards tab." : "No sideboard. It holds up to 10 cards.")
                .font(RiftFont.text(13.5, .regular))
                .lineSpacing(4)
                .foregroundStyle(.white.opacity(0.66))
                .padding(.vertical, 18)
        } else {
            HStack(spacing: 8) {
                Segmented(labels: ["Gallery", "List"], selected: asList ? 1 : 0, height: 36) { asList = $0 == 1 }
                Segmented(labels: ["Type", "Energy"], selected: byEnergy ? 1 : 0, height: 36) { byEnergy = $0 == 1 }
            }
            .padding(.top, 8)
            PileGallery(entries: rows, cards: cards, byEnergy: byEnergy, championId: deck.champion?.cardId, list: asList)
        }
    }
}

/// Round icon on the banner: dark glass, ringed.
private struct DarkIcon: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        RoundIcon(symbol: symbol, label: label, fill: .black.opacity(0.45), action: action)
            .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
    }
}

private struct ToolButton: View {
    let label: String
    let symbol: String
    /// The match log grows out of this one's circle.
    var grows: (space: Namespace.ID, open: Bool)? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background {
                        if let grows {
                            if !grows.open {
                                Circle().fill(.white.opacity(0.06)).matchedGeometryEffect(id: "log:tool", in: grows.space)
                            }
                        } else {
                            Circle().fill(.white.opacity(0.06))
                        }
                    }
                    .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
                Text(label).font(RiftFont.text(11.5, .semibold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale(scale: 0.95))
        .accessibilityLabel(label)
    }
}

/// The mock's `.blk`: a soft panel that fades in after its content.
private struct DeckBlock<Content: View>: View {
    let shown: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22)
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    shape.fill(.white.opacity(0.04))
                    shape.stroke(.white.opacity(0.08), lineWidth: 1)
                }
                .opacity(shown ? 1 : 0)
                .animation(shown ? .easeInOut(duration: 0.6).delay(0.3) : .easeInOut(duration: 0.6), value: shown)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
    }
}

private struct FieldTile: View {
    let entry: DecklistEntry?
    let card: Card?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12)
        Group {
            if let entry {
                ArtBox(card: card, imageWidth: 240, initial: "", focus: .center)
                    .overlay { BottomShade(from: 0.2) }
                    .overlay(alignment: .bottomLeading) {
                        Text(card?.name ?? entry.cardName)
                            .font(RiftFont.text(11, .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .padding(8)
                    }
                    .clipShape(shape)
                    .overlay(shape.stroke(.white.opacity(0.12), lineWidth: 1))
            } else {
                Text("Empty")
                    .font(RiftFont.text(11, .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(shape.stroke(.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
    }
}

/// The mock's fly-out: from the pile (scaled to its size, turned ±7°, unseen) into place, 780ms, 70ms apart;
/// back into the pile with an ease-in when the deck closes.
private struct FlyFromPile: ViewModifier {
    let pile: CGRect
    let shown: Bool
    let index: Int
    let rotation: Double
    @State private var frame: CGRect = .zero

    func body(content: Content) -> some View {
        let scale = frame.width > 0 ? min(max(pile.width / frame.width, 0.3), 2.4) : 1
        let away = shown ? 0.09 + Double(index) * 0.07 : Double(3 - index) * 0.04
        content
            .scaleEffect(shown ? 1 : scale)
            .rotationEffect(.degrees(shown ? 0 : rotation))
            .offset(x: shown ? 0 : pile.midX - frame.midX, y: shown ? 0 : pile.midY - frame.midY)
            .animation(shown ? .rift(0.78).delay(away) : .timingCurve(0.5, 0, 0.75, 0, duration: 0.52).delay(away), value: shown)
            .opacity(shown ? 1 : 0)
            .animation(shown ? .linear(duration: 0.26).delay(away) : .linear(duration: 0.18).delay(away + 0.34), value: shown)
            // Measured outside the fly's own offset: the place it flies to.
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(decksSpace)) } action: { frame = $0 }
    }
}

/// A tab change replays the list's rise (the mock's rowsA / rowsB).
private struct TabRise: ViewModifier {
    let replay: Bool
    @State private var risen = false

    func body(content: Content) -> some View {
        let up = !replay || risen
        content
            .opacity(up ? 1 : 0)
            .offset(y: up ? 0 : 10)
            .blur(radius: up ? 0 : 6)
            .onAppear { if replay { withAnimation(.rift(0.6)) { risen = true } } }
    }
}
