//
//  RiftDecksView.swift
//  Riftbound Companiokay
//
//  The redesign's Decks tab (Android `DecksScreen.kt`, `DecksHome.kt`, mock `DecksMix`): the table of piles
//  rising in, the new-deck spot and the shortlist, then the all-decks win rate and the last games, both
//  growing into the match log; a game opens its review and its edit sheet.
//

import SwiftUI

struct RiftDecksView: View {
    @EnvironmentObject private var decks: DecklistStore
    @EnvironmentObject private var games: GameRecordStore
    @EnvironmentObject private var cards: CardStore
    @EnvironmentObject private var shortlist: ShortlistStore

    @State private var opened: OpenDeck?
    @State private var closingDeck = false
    @State private var tool: DeckTool?
    @State private var log: LogOpen?
    @State private var logDeck: UUID?
    @State private var review: GameRecord?
    @State private var editing: GameRecord?
    @State private var importing = false
    @State private var shortlistShown = false
    @State private var toast: BoardToast?
    /// Until the redesign's builder lands: the classic one.
    @State private var classicBuilder = false
    @Namespace private var space

    struct OpenDeck: Equatable {
        let id: UUID
        /// The pile's frame in `decksSpace`, where the deck grows from and goes back to.
        let pile: CGRect
    }

    struct LogOpen: Equatable {
        /// "win", "last" or "tool" (the deck screen's History): what it grew out of.
        let tile: String
    }

    var body: some View {
        let index = Dictionary(cards.allCards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let openDeck = opened.flatMap { o in decks.lists.first { $0.id == o.id } }
        let away = opened != nil && !closingDeck
        NavigationStack {
            ZStack {
                home(index)
                    .opacity(away ? 0 : log == nil ? 1 : 0.12)
                    .scaleEffect(away ? 0.94 : 1)
                    .animation(.rift(0.6), value: away)
                    .allowsHitTesting(log == nil && review == nil && opened == nil)
                if let opened, let deck = openDeck {
                    RiftDeckDetail(
                        deck: deck, cards: index, record: Tally.of(games.records.filter { $0.deckId == deck.id }), pile: opened.pile,
                        closing: closingDeck, space: space, logOpen: log?.tile == "tool",
                        onClose: closeDeck, onClosed: { self.opened = nil; closingDeck = false },
                        onTool: { tool = $0 }, onLog: { openLog("tool", deck: deck.id) }
                    )
                    .zIndex(0.5)
                }
                if let log {
                    PanelGround(id: "log:\(log.tile)", space: space)
                        .transition(.asymmetric(insertion: .identity, removal: .opacity))
                        .zIndex(1)
                    MatchLogPanel(
                        deckId: $logDeck, decks: decks.lists, games: games.records,
                        onClose: closeLog, onOpenGame: { game in withAnimation(.rift(0.62)) { review = game } }
                    )
                    .transition(.panelContent)
                    .zIndex(1.1)
                }
                if let shown = review, let game = games.records.first(where: { $0.id == shown.id }) {
                    RiftGameReview(game: game, decks: decks.lists, onBack: { withAnimation(.rift(0.62)) { review = nil } }, onEdit: { editing = game })
                        .transition(.move(edge: .trailing))
                        .zIndex(2)
                }
                if let toast {
                    HalfToast(text: toast.text)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 24)
                        .id(toast.id)
                        .task(id: toast.id) {
                            try? await Task.sleep(for: .seconds(2.2))
                            if self.toast?.id == toast.id { self.toast = nil }
                        }
                        .zIndex(3)
                }
            }
            .coordinateSpace(.named(decksSpace))
            .background(Color.black.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(opened == nil && log == nil && review == nil ? .visible : .hidden, for: .tabBar)
        }
        .onAppear { cards.loadIfNeeded() }
        .sheet(item: $tool) { tool in
            if let deck = openDeck { toolSheet(tool, deck: deck, index: index) }
        }
        .sheet(item: $editing) { game in
            EditGameSheet(game: game, decks: decks.lists, legends: cards.legendNames, onSave: { updated in
                games.update(updated)
                editing = nil
                toast = BoardToast(text: "Game updated")
            }, onDelete: {
                games.delete(game)
                editing = nil
                withAnimation(.rift(0.62)) { review = nil }
                toast = BoardToast(text: "Game deleted")
            })
        }
        .sheet(isPresented: $importing) {
            ImportDeckSheet { parsed in
                var named = parsed
                named.name = parsed.legend.map { "Imported · \($0.title)" } ?? "Imported deck"
                let deck = decks.createFromImport(named, runePool: cards.allCards)
                toast = BoardToast(text: "Imported \(DeckRules.total(deck.mainDeck)) cards, open the pile to finish it")
            }
        }
        .sheet(isPresented: $shortlistShown) { RiftShortlistSheet() }
        .sheet(isPresented: $classicBuilder) { DeckBuilderSheet() }
    }

    @ViewBuilder
    private func toolSheet(_ tool: DeckTool, deck: Decklist, index: [String: Card]) -> some View {
        switch tool {
        case .hand: HandSheet(deck: deck, cards: index)
        case .odds: OddsSheet(deck: deck, cards: index)
        case .stats: StatsSheet(deck: deck, cards: index)
        case .issues: IssuesSheet(deck: deck, cards: index)
        case .export: ExportSheet(deck: deck, pool: cards.allCards) { toast = BoardToast(text: "Deck list copied") }
        case .champion:
            ChampionSheet(deck: deck, cards: index, pool: cards.allCards) { champion in
                decks.replace(DeckEdits.champion(deck, champion, at: Date()))
                Haptics.success()
                toast = BoardToast(text: "\(champion.title) is your champion")
            }
        case .fields:
            FieldsSheet(deck: deck, pool: cards.allCards) { field in
                // The sheet reads the stored deck, so a second tap sees the first.
                guard let live = decks.lists.first(where: { $0.id == deck.id }), let next = DeckEdits.toggleBattlefield(live, field, at: Date()) else { return false }
                decks.replace(next)
                return true
            }
        case .menu:
            DeckMenuSheet(deck: deck, onRename: { decks.rename(deck, to: $0) }, onEdit: nil, onDelete: {
                opened = nil
                closingDeck = false
                decks.delete(deck)
                toast = BoardToast(text: "Deleted \(deck.name)")
            })
        }
    }

    private func home(_ index: [String: Card]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Decks").font(RiftFont.display(46)).tracking(0.9).foregroundStyle(.white)
                        Text("TAP A PILE TO OPEN IT").caps(11.5).foregroundStyle(.white.opacity(0.62))
                    }
                    Spacer()
                    RoundIcon(symbol: "square.and.arrow.down", label: "Import a deck from text", fill: .white.opacity(0.06)) { importing = true }
                        .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 4) {
                    ForEach(Array(decks.lists.enumerated()), id: \.element.id) { i, deck in
                        PileCell(deck: deck, legend: deck.legend.flatMap { index[$0.cardId] }, record: Tally.of(games.records.filter { $0.deckId == deck.id }),
                                 status: DeckRules.status(deck, cards: index), index: i, hidden: opened?.id == deck.id) { pile in openDeck(deck, from: pile) }
                    }
                    NewDeckCell(index: decks.lists.count) { classicBuilder = true }
                    ShortlistCell(index: decks.lists.count + 1, kept: shortlist.ids.compactMap { index[$0] }) { shortlistShown = true }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                let all = Tally.of(games.records)
                HStack {
                    Text("ALL DECKS")
                    Spacer()
                    Text("\(all.games) \(all.games == 1 ? "GAME" : "GAMES")")
                }
                .caps(11, tracking: 0.16)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 10)
                VStack(spacing: 10) {
                    WinRateTile(games: games.records, open: log?.tile == "win", space: space) { openLog("win") }
                    LastGamesTile(games: games.records, decks: decks.lists, open: log?.tile == "last", space: space) { openLog("last") }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
    }

    private func openDeck(_ deck: Decklist, from pile: CGRect) {
        guard opened == nil, pile.width > 0 else { return }
        closingDeck = false
        opened = OpenDeck(id: deck.id, pile: pile)
        Haptics.light()
    }

    private func closeDeck() {
        guard opened != nil, !closingDeck else { return }
        tool = nil
        closingDeck = true
    }

    private func openLog(_ tile: String, deck: UUID? = nil) {
        logDeck = deck
        withAnimation(.rift(0.64)) { log = LogOpen(tile: tile) }
    }

    private func closeLog() {
        withAnimation(.timingCurve(0.2, 0, 0, 1, duration: 0.5)) { log = nil }
    }
}

/// The mock's cellIn: up 16pt out of a blur of 8, 70ms apart.
private struct CellIn: ViewModifier {
    let index: Int
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .blur(radius: shown ? 0 : 8)
            .onAppear { withAnimation(.rift(0.76).delay(Double(index) * 0.07)) { shown = true } }
    }
}

/// The pile lifts and tilts a little under the finger.
private struct Lift: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? -4 : 0)
            .rotationEffect(.degrees(configuration.isPressed ? -1.5 : 0))
            .animation(.rift(0.32), value: configuration.isPressed)
    }
}

private struct PileCell: View {
    let deck: Decklist
    let legend: Card?
    let record: Tally
    let status: String
    let index: Int
    /// Its deck is open: the pile is up there as the banner.
    let hidden: Bool
    let onOpen: (CGRect) -> Void
    @State private var pile: CGRect = .zero

    var body: some View {
        Button { onOpen(pile) } label: {
            VStack(spacing: 0) {
                PileStack(deck: deck, legend: legend)
                    .frame(width: 120, height: 168)
                    .opacity(hidden ? 0 : 1)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(decksSpace)) } action: { pile = $0 }
                Text(deck.name).font(RiftFont.display(21)).foregroundStyle(.white).lineLimit(1).padding(.top, 10)
                Text(record.games > 0 ? "\(record.text) · \(record.percent)" : "No games yet")
                    .font(RiftFont.text(11, .semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.top, 4)
                LegalChip(status: status).padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 262, alignment: .top)
            .padding(.top, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(Lift())
        .modifier(CellIn(index: index))
        .accessibilityLabel("\(deck.name), \(legend?.title ?? "no legend")")
    }
}

private struct NewDeckCell: View {
    let index: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 24, weight: .semibold)).foregroundStyle(.white.opacity(0.75))
                    Text("New deck").font(RiftFont.text(12.5, .semibold)).foregroundStyle(.white.opacity(0.75))
                }
                .frame(width: 120, height: 168)
                .background(DashedFrame())
                Text("Build").font(RiftFont.display(21)).foregroundStyle(.white).padding(.top, 10)
                Text("Seven steps on a light rail").font(RiftFont.text(11, .semibold)).foregroundStyle(.white.opacity(0.62)).padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 262, alignment: .top)
            .padding(.top, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale(scale: 0.97))
        .modifier(CellIn(index: index))
        .accessibilityLabel("Build a new deck")
    }
}

/// After New deck: the cards kept in mind, the latest three fanned like a hand; a tap lists them all.
private struct ShortlistCell: View {
    let index: Int
    let kept: [Card]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    if kept.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "star").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white.opacity(0.75))
                            Text("No cards yet").font(RiftFont.text(12.5, .semibold)).foregroundStyle(.white.opacity(0.75))
                        }
                        .frame(width: 120, height: 168)
                        .background(DashedFrame())
                    } else {
                        let fan = Array(kept.suffix(3))
                        ZStack {
                            ForEach(Array(fan.enumerated()), id: \.element.id) { k, card in
                                let off = CGFloat(k) - CGFloat(fan.count - 1) / 2
                                CardTile(card: card, errata: false, imageWidth: 84)
                                    .frame(width: 84, height: 84 / cardAspect)
                                    .shadow(color: .black.opacity(0.6), radius: 7)
                                    .rotationEffect(.degrees(9 * off), anchor: .bottom)
                                    .offset(x: 18 * off)
                            }
                        }
                        .frame(width: 120, height: 168)
                        Image(systemName: "star.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 28, height: 28)
                            .background(RiftColor.you, in: Circle())
                    }
                }
                Text("Shortlist").font(RiftFont.display(21)).foregroundStyle(.white).padding(.top, 10)
                Text(kept.isEmpty ? "Save cards in the Cards tab" : "\(kept.count) kept in mind")
                    .font(RiftFont.text(11, .semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 262, alignment: .top)
            .padding(.top, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale(scale: 0.97))
        .modifier(CellIn(index: index))
        .accessibilityLabel("Shortlist, \(kept.count) cards kept in mind")
    }
}

/// A home tile that grows into the match log: its background is the panel's start.
private struct HomeTile<Content: View>: View {
    let id: String
    let open: Bool
    let space: Namespace.ID
    let delay: Double
    let label: String
    let onTap: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var shown = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) { content() }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    if !open {
                        RoundedRectangle(cornerRadius: 24).fill(Color(hex: "0D0D0D"))
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.09), lineWidth: 1))
                            .matchedGeometryEffect(id: "log:\(id)", in: space)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(PressScale(scale: 0.97))
        .opacity(shown ? (open ? 0 : 1) : 0)
        .offset(y: shown ? 0 : 16)
        .blur(radius: shown ? 0 : 8)
        .onAppear { withAnimation(.rift(0.76).delay(delay)) { shown = true } }
        .accessibilityLabel(label)
    }
}

private struct TileHead: View {
    let left: String
    let right: String

    var body: some View {
        HStack {
            Text(left)
            Spacer()
            Text(right)
        }
        .caps(10.5)
        .foregroundStyle(.white.opacity(0.6))
    }
}

/// Win rate across all decks: green arc over a violet ring, record, first / second split and the last five.
private struct WinRateTile: View {
    let games: [GameRecord]
    let open: Bool
    let space: Namespace.ID
    let onTap: () -> Void

    var body: some View {
        let all = Tally.of(games)
        let split = MatchLog.firstSecond(games)
        HomeTile(id: "win", open: open, space: space, delay: 0.26, label: "Win rate across all decks, open the match log", onTap: onTap) {
            TileHead(left: "WIN RATE", right: "\(all.games) \(all.games == 1 ? "GAME" : "GAMES")")
            HStack(spacing: 16) {
                WinRing(rate: all.rate, text: all.percent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(all.text).font(RiftFont.display(32)).tracking(1).foregroundStyle(.white)
                    Text(all.games > 0 ? "Going first \(split.first.text) · second \(split.second.text)" : "Games from the scoreboard show up here.")
                        .font(RiftFont.text(12.5))
                        .foregroundStyle(.white.opacity(0.66))
                    HStack(spacing: 5) {
                        ForEach(games.prefix(5)) { game in ResultDot(won: game.result == .won, size: 18, fontSize: 10) }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.top, 8)
        }
    }
}

private struct WinRing: View {
    let rate: Double
    let text: String
    @State private var shown: Double = 0

    var body: some View {
        ZStack {
            Circle().stroke(RiftColor.opponent.opacity(0.35), lineWidth: 8).padding(7)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(RiftColor.you, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(7)
            Text(text).font(RiftFont.display(26)).foregroundStyle(.white)
        }
        .frame(width: 84, height: 84)
        .onAppear { withAnimation(.rift(1)) { shown = rate } }
        .onChange(of: rate) { _, next in withAnimation(.rift(1)) { shown = next } }
    }
}

private struct LastGamesTile: View {
    let games: [GameRecord]
    let decks: [Decklist]
    let open: Bool
    let space: Namespace.ID
    let onTap: () -> Void

    var body: some View {
        HomeTile(id: "last", open: open, space: space, delay: 0.32, label: "Last games, open the match log", onTap: onTap) {
            TileHead(left: "MATCH LOG", right: "ALL \(games.count) ›")
            if games.isEmpty {
                Text("No games yet.").font(RiftFont.text(13)).foregroundStyle(.white.opacity(0.6)).padding(.top, 10)
            }
            ForEach(games.prefix(3)) { game in
                HStack(spacing: 10) {
                    ResultDot(won: game.result == .won, size: 22, fontSize: 11)
                    Text("\(Text("vs \(MatchLog.opponentShort(game.opponent))"))\(Text(([MatchLog.deckName(game, in: decks), MatchLog.shortDate(game.date)].compactMap { $0 }).map { " · \($0)" }.joined()).font(RiftFont.text(13, .medium)).foregroundStyle(.white.opacity(0.55)))")
                        .font(RiftFont.text(13, .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if let score = MatchLog.score(game) {
                        Text("\(score.you)–\(score.them)").font(RiftFont.display(17)).foregroundStyle(.white)
                    }
                }
                .frame(height: 38)
            }
        }
    }
}
