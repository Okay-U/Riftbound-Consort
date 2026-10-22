//
//  MatchLogPanel.swift
//  Riftbound Companiokay
//
//  The match log (Android `LogPanel.kt`): it grows out of the tile that opened it and shrinks back into it,
//  deck chips filter it, a game opens its review: the result, the race to 8 in two lanes, every point with
//  the score after it, sliding in from the right.
//

import SwiftUI

/// The log's ground: grows out of the tile (matched geometry), dissolves back into it.
struct PanelGround: View {
    let id: String
    let space: Namespace.ID
    @State private var corner: CGFloat = 24

    var body: some View {
        RoundedRectangle(cornerRadius: corner)
            .fill(Color(hex: "0B0B0B"))
            .matchedGeometryEffect(id: id, in: space)
            .ignoresSafeArea()
            .onAppear { withAnimation(.rift(0.64)) { corner = 0 } }
            .accessibilityHidden(true)
    }
}

/// Hidden: 12pt down and a blur of 8 (the panel's `faded`).
private struct SoftFade: ViewModifier {
    let shown: Bool

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)
            .blur(radius: shown ? 0 : 8)
    }
}

extension AnyTransition {
    /// The panel's controls rise in once the ground has grown and are gone quickly when it shrinks.
    static var panelContent: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: SoftFade(shown: false), identity: SoftFade(shown: true)).animation(.rift(0.65).delay(0.22)),
            removal: .opacity.animation(.linear(duration: 0.18))
        )
    }
}

/// Round icon of the panels, ringed.
struct PanelIcon: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        RoundIcon(symbol: symbol, label: label, fill: .white.opacity(0.06), action: action)
            .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
    }
}

/// The panels' header: a caps line over a big title, icons either side.
private struct PanelHead<Trailing: View>: View {
    let icon: String
    let iconLabel: String
    let caption: String
    let title: String
    let onIcon: () -> Void
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            PanelIcon(symbol: icon, label: iconLabel, action: onIcon)
            VStack(alignment: .leading, spacing: 2) {
                Text(caption.uppercased()).caps(11, tracking: 0.12).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                Text(title).font(RiftFont.display(30)).foregroundStyle(.white).lineLimit(1)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }
}

struct MatchLogPanel: View {
    @Binding var deckId: UUID?
    let decks: [Decklist]
    let games: [GameRecord]
    let onClose: () -> Void
    let onOpenGame: (GameRecord) -> Void

    var body: some View {
        let filtered = games.filter { deckId == nil || $0.deckId == deckId }
        VStack(spacing: 0) {
            PanelHead(icon: "chevron.down", iconLabel: "Collapse", caption: decks.first { $0.id == deckId }?.name ?? "All decks",
                      title: "Match log", onIcon: onClose) { EmptyView() }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            OnOffChip(label: "All decks", on: deckId == nil, color: RiftColor.you) { deckId = nil }
                            ForEach(decks) { deck in
                                OnOffChip(label: deck.name, on: deck.id == deckId, color: RiftColor.you) { deckId = deck.id }
                            }
                        }
                    }
                    .padding(.bottom, 12)
                    // A filter change replays the list's rise.
                    LogList(games: filtered, decks: decks, showDeck: deckId == nil, onOpenGame: onOpenGame)
                        .softIn(duration: 0.56)
                        .id(deckId)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
        }
    }
}

private struct LogList: View {
    let games: [GameRecord]
    let decks: [Decklist]
    let showDeck: Bool
    let onOpenGame: (GameRecord) -> Void

    var body: some View {
        let tally = Tally.of(games)
        let split = MatchLog.firstSecond(games)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                SumTile(label: "Record", value: tally.text)
                SumTile(label: "Win rate", value: tally.percent, color: RiftColor.you)
            }
            HStack(spacing: 8) {
                SumTile(label: "Avg game", value: MatchLog.averageMinutes(games).map { "\($0) min" } ?? "–")
                SumTile(label: "First · second", value: "\(split.first.text) · \(split.second.text)")
            }
            .padding(.top, 8)
            .padding(.bottom, 6)
            if games.isEmpty {
                Text("No games yet. Finished games on the scoreboard land here.")
                    .font(RiftFont.text(13, .regular))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 18)
            }
            ForEach(games) { game in
                GameRow(game: game, deck: showDeck ? MatchLog.deckName(game, in: decks) : nil) { onOpenGame(game) }
            }
        }
    }
}

private struct SumTile: View {
    let label: String
    let value: String
    var color: Color = .white

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22)
        VStack(alignment: .leading) {
            Text(label.uppercased()).caps(10.5).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            Spacer(minLength: 0)
            Text(value).font(RiftFont.display(30)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 88, maxHeight: 88, alignment: .leading)
        .background(.white.opacity(0.05), in: shape)
        .overlay(shape.stroke(.white.opacity(0.08), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

private struct GameRow: View {
    let game: GameRecord
    let deck: String?
    let onTap: () -> Void

    var body: some View {
        let won = game.result == .won
        let opponent = MatchLog.opponentShort(game.opponent)
        let line = [deck, MatchLog.shortDate(game.date), "\(minutes(game.durationSeconds)) min"].compactMap { $0 }.joined(separator: " · ")
        Button(action: onTap) {
            HStack(spacing: 12) {
                ResultDot(won: won, size: 34, fontSize: 17)
                VStack(alignment: .leading, spacing: 2) {
                    Text("vs \(opponent)").font(RiftFont.text(15, .semibold)).foregroundStyle(.white).lineLimit(1)
                    Text(line).font(RiftFont.text(12)).foregroundStyle(.white.opacity(0.58)).lineLimit(1)
                }
                Spacer(minLength: 8)
                if let score = MatchLog.score(game) {
                    Text("\(score.you)–\(score.them)").font(RiftFont.display(22)).foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 2)
            .frame(height: 66)
            .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.07)).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale(scale: 0.98))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(won ? "Won" : "Lost") against \(opponent), \(line)")
        .accessibilityAddTraits(.isButton)
    }
}

private func minutes(_ seconds: Int) -> Int { Int((Double(seconds) / 60).rounded()) }

/// One game in full. Slides in from the right over the log.
struct RiftGameReview: View {
    let game: GameRecord
    let decks: [Decklist]
    let onBack: () -> Void
    let onEdit: () -> Void

    var body: some View {
        let opponent = MatchLog.opponentShort(game.opponent)
        let won = game.result == .won
        let score = MatchLog.score(game)
        let points = MatchLog.points(game)
        let lanes = MatchLog.race(game)
        let deck = MatchLog.deckName(game, in: decks)
        VStack(spacing: 0) {
            PanelHead(icon: "chevron.left", iconLabel: "Back", caption: MatchLog.longDate(game.date), title: "vs \(opponent)", onIcon: onBack) {
                PanelIcon(symbol: "pencil", label: "Edit game", action: onEdit)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        SumTile(label: "Result", value: (won ? "Won" : "Lost") + (score.map { " \($0.you)–\($0.them)" } ?? ""),
                                color: won ? RiftColor.you : RiftColor.opponent)
                        SumTile(label: orderLabel, value: "\(minutes(game.durationSeconds)) min")
                    }
                    Caps(text: ["Race to 8", deck].compactMap { $0 }.joined(separator: " · "))
                    VStack(spacing: 6) {
                        Lane(name: "You", points: lanes[Seat.you] ?? [], color: RiftColor.you)
                        Lane(name: opponent, points: lanes[Seat.opponent] ?? [], color: RiftColor.opponent)
                    }
                    .padding(.top, 8)
                    Caps(text: "Point by point")
                    if points.isEmpty {
                        Text("This game was saved without a point log, so only the result is known.")
                            .font(RiftFont.text(14, .regular))
                            .lineSpacing(5)
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.top, 6)
                    }
                    ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                        PointRow(point: point, opponent: opponent)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
        }
        .background(Color(hex: "050505").ignoresSafeArea())
    }

    private var orderLabel: String {
        switch game.startedFirst {
        case true?: return "Went first"
        case false?: return "Went second"
        case nil: return "Duration"
        }
    }
}

private struct Caps: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .caps(11, tracking: 0.12)
            .foregroundStyle(.white.opacity(0.6))
            .padding(.top, 16)
            .padding(.bottom, 8)
    }
}

private struct PointRow: View {
    let point: ScorePoint
    let opponent: String

    var body: some View {
        let you = point.slot == Seat.you
        HStack(spacing: 0) {
            Text(MatchLog.clock(point.seconds))
                .font(RiftFont.display(14, weight: 800))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 46, alignment: .leading)
            Text(you ? "You" : opponent)
                .font(RiftFont.text(11, .bold))
                .foregroundStyle(.black)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(you ? RiftColor.you : RiftColor.opponent, in: RoundedRectangle(cornerRadius: 12))
            Text(kindLabel)
                .font(RiftFont.text(13.5, .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.leading, 10)
            Spacer(minLength: 8)
            Text("\(point.you)–\(point.them)").font(RiftFont.display(18)).foregroundStyle(.white)
        }
        .frame(height: 42)
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.06)).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }

    private var kindLabel: String {
        switch point.kind {
        case .conquer: return "Conquer"
        case .hold: return "Hold"
        case .manual: return point.delta < 0 ? "Fix \(point.delta)" : "Effect +\(point.delta)"
        }
    }
}

/// Eight steps per player popping in one after another; a conquer lights fully, a hold softer (the mock).
private struct Lane: View {
    let name: String
    let points: [ScoreEventType]
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(name)
                .font(RiftFont.text(12, .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .frame(width: 62, alignment: .leading)
            HStack(spacing: 4) {
                ForEach(0..<8, id: \.self) { i in
                    LaneStep(index: i, fill: fill(i < points.count ? points[i] : nil))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name): \(min(points.count, 8)) of 8")
    }

    private func fill(_ kind: ScoreEventType?) -> Color {
        switch kind {
        case nil: return .white.opacity(0.06)
        case .conquer?: return color
        default: return color.opacity(0.6)
        }
    }
}

private struct LaneStep: View {
    let index: Int
    let fill: Color
    @State private var shown = false

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(fill)
            .frame(height: 22)
            .frame(maxWidth: .infinity)
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.6)
            .onAppear { withAnimation(.rift(0.52).delay(0.2 + Double(index) * 0.07)) { shown = true } }
    }
}
