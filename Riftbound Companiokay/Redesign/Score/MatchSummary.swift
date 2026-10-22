//
//  MatchSummary.swift
//  Riftbound Companiokay
//
//  After the last game of a live series (or "End"): who won it, one chip per game on the light rail
//  (Android `Summary.kt`, `ReportRail.kt`). For the series started for the pairing the rail reports it:
//  sliding the knob along the line lights each game in its winner's colour, letting go at the end sends
//  it to PlayRiftbound, and the line flashes once Riot has it.
//

import SwiftUI

typealias SeriesReport = (TableLink, [Int]) async throws -> String

struct MatchSummary: View {
    @ObservedObject var c: ScoreController
    let colors: [Color]
    let centerY: CGFloat
    let link: TableLink?
    /// Asks PlayRiftbound again: the pairing may be reported meanwhile, or a newer round up.
    let onRefresh: () -> Void
    let report: SeriesReport

    var body: some View {
        let s = c.state
        let wins = s.seriesWins()
        let lead = wins[Seat.you] > wins[Seat.opponent] ? Seat.you : wins[Seat.opponent] > wins[Seat.you] ? Seat.opponent : -1
        let accent = lead < 0 ? Color.white : colors[lead]
        // Only the series started for the pairing goes to Riot, never a best of three played for practice.
        let live = link?.tag == s.liveTag ? link : nil
        let reporting = c.reportedSeries != nil || live?.reportable == true
        GeometryReader { geo in
            let railLeft: CGFloat = 28
            let railWidth = geo.size.width - 56
            ZStack(alignment: .topLeading) {
                VStack(spacing: 2) {
                    Text("BEST OF \(s.bestOf)").caps(10, tracking: 0.18).foregroundStyle(.white.opacity(0.72))
                    Text(headline(wins: wins, lead: lead))
                        .font(RiftFont.display(36))
                        .tracking(36 * 0.06)
                        .foregroundStyle(accent)
                        .multilineTextAlignment(.center)
                }
                .frame(width: geo.size.width)
                .offset(y: centerY - 139)
                .softIn(delay: 0.7, duration: 1.2)

                if reporting {
                    ReportRail(c: c, colors: colors, accent: accent, railLeft: railLeft, railWidth: railWidth, centerY: centerY, link: live, report: report)
                        .softIn(delay: 0.9, duration: 0.7)
                } else {
                    RailIn(left: railLeft, centerY: centerY, width: railWidth, color: .white.opacity(0.18), glow: nil, delay: 0.9)
                    RailIn(left: railLeft, centerY: centerY, width: railWidth, color: accent, glow: accent, delay: 1.3)
                    ForEach(Array(s.log.enumerated()), id: \.offset) { i, game in
                        let x = railLeft + railWidth * CGFloat(i + 1) / CGFloat(s.log.count + 1)
                        let color = game.winner < 0 ? Color.white : colors[game.winner]
                        Circle().fill(color).frame(width: 10, height: 10).shadow(color: color, radius: 6).position(x: x, y: centerY)
                        GameChip(text: chipText(i, game), fill: color, ink: .black)
                            .position(x: x, y: centerY - 40)
                            .softIn(delay: 1.3 + Double(i) * 0.22, duration: 0.6)
                    }
                }

                VStack(spacing: 4) {
                    Pill(text: "Return to scoreboard", fill: accent, ink: accent.ink) {
                        onRefresh()
                        c.newMatch()
                    }
                    if c.reportedSeries != nil {
                        Note(text: "Wrong result? Ask the scorekeeper to change it.")
                    } else if live?.reported == true {
                        Note(text: "Already reported on PlayRiftbound. Wrong result? Ask the scorekeeper to change it.")
                    } else {
                        LinkText(text: "Wrong results? Set them yourself") { c.openPicker(ending: false) }
                        // The event says one game, the table plays three: game 1 then no longer ends the match.
                        if s.bestOf == 1 && !s.ended {
                            LinkText(text: "We play best of 3") { c.playBestOfThree() }
                        }
                    }
                }
                .frame(width: geo.size.width)
                .offset(y: centerY + (reporting ? 52 : 37))
                .softIn(delay: 1.7, duration: 0.6)
            }
        }
        .onAppear(perform: onRefresh)
    }

    private func headline(wins: [Int], lead: Int) -> String {
        let series = "\(max(wins[0], wins[1]))–\(min(wins[0], wins[1]))"
        guard lead >= 0 else { return "Match drawn \(series)" }
        let verb = lead == Seat.you && c.shortName(Seat.you) == "You" ? "win" : "wins"
        return "\(c.shortName(lead)) \(verb) \(series)"
    }

    private func chipText(_ i: Int, _ game: PlayedGame) -> String {
        chipLabel(i, game, name: c.shortName)
    }
}

/// "G1 · 8–3", "G2 · Draw", "G3 · Darius" for a game set by hand.
private func chipLabel(_ i: Int, _ game: PlayedGame, name: (Int) -> String) -> String {
    let result: String
    if let scores = game.scores, let high = scores.max(), let low = scores.min() {
        result = "\(high)–\(low)"
    } else {
        result = game.winner < 0 ? "Draw" : name(game.winner)
    }
    return "G\(i + 1) · \(result)"
}

private struct GameChip: View {
    let text: String
    let fill: Color
    let ink: Color

    var body: some View {
        Text(text)
            .font(RiftFont.text(13, .semibold))
            .monospacedDigit()
            .foregroundStyle(ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(fill, in: RoundedRectangle(cornerRadius: 17))
            .fixedSize()
    }
}

/// The line drawing in from the left; grown in width, not scaled, so its glow keeps a soft end.
private struct RailIn: View {
    let left: CGFloat
    let centerY: CGFloat
    let width: CGFloat
    let color: Color
    let glow: Color?
    let delay: Double
    @State private var t: CGFloat = 0

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: width * t, height: 4)
            .shadow(color: glow ?? .clear, radius: glow == nil ? 0 : 8)
            .position(x: left + width * t / 2, y: centerY)
            .onAppear { withAnimation(.rift(0.9).delay(delay)) { t = 1 } }
    }
}

/// Plain words under the summary's buttons where a link would lead nowhere.
private struct Note: View {
    let text: String

    var body: some View {
        Text(text)
            .font(RiftFont.text(13))
            .lineSpacing(3)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.72))
            .padding(.horizontal, 32)
            .padding(.vertical, 6)
    }
}

private struct LinkText: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text).font(RiftFont.text(13, .semibold)).underline().foregroundStyle(.white.opacity(0.82)).padding(6)
        }
        .buttonStyle(PressScale())
    }
}

/// "Slide along the light" (Okay's pick). Short of the end the knob slides back. "Reported" belongs to the
/// series on the board, never to the pairing alone: a new match or a newer round never inherits it.
private struct ReportRail: View {
    @ObservedObject var c: ScoreController
    let colors: [Color]
    let accent: Color
    let railLeft: CGFloat
    let railWidth: CGFloat
    let centerY: CGFloat
    let link: TableLink?
    let report: SeriesReport

    @State private var progress: CGFloat = 0
    @State private var dragStart: CGFloat?
    @State private var sending = false
    @State private var flash = 1.0

    var body: some View {
        let sent = c.reportedSeries
        let shown = sent != nil ? 1 : progress
        let light = accent.opacity(flash)
        let log = c.state.log
        ZStack(alignment: .topLeading) {
            Capsule().fill(.white.opacity(0.18)).frame(width: railWidth, height: 4).position(x: railLeft + railWidth / 2, y: centerY)
            Capsule()
                .fill(light)
                .frame(width: railWidth * shown, height: 4)
                .shadow(color: light, radius: 8)
                .position(x: railLeft + railWidth * shown / 2, y: centerY)
            ForEach(Array(log.enumerated()), id: \.offset) { i, game in
                let at = CGFloat(i + 1) / CGFloat(log.count + 1)
                let lit = shown >= at - 0.001
                let color = game.winner < 0 ? Color.white : colors[game.winner]
                let x = railLeft + railWidth * at
                Circle().fill(lit ? color : .white.opacity(0.14)).frame(width: 10, height: 10).position(x: x, y: centerY)
                GameChip(text: chipLabel(i, game, name: c.shortName), fill: lit ? color : .white.opacity(0.14), ink: lit ? .black : .white.opacity(0.7))
                    .position(x: x, y: centerY - 40)
                    .animation(.easeInOut(duration: 0.26), value: lit)
            }
            if sent == nil {
                knob.position(x: railLeft + railWidth * progress, y: centerY)
            }
            Text(caption(sent))
                .caps(10.5, tracking: 0.16)
                .foregroundStyle(sent != nil ? RiftColor.you : .white.opacity(0.72))
                .frame(width: railWidth + railLeft * 2)
                .position(x: railLeft + railWidth / 2, y: centerY + 20)
        }
        .onAppear { if sent != nil { progress = 1 } }
    }

    private var canSend: Bool { c.reportedSeries == nil && !sending && link?.reportable == true }

    private var knob: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.black)
            .frame(width: 34, height: 34)
            .background(RiftColor.you, in: Circle())
            .shadow(color: RiftColor.you.opacity(0.8), radius: 9)
            .contentShape(Circle().inset(by: -8))
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { drag in
                        guard canSend else { return }
                        let start = dragStart ?? progress
                        dragStart = start
                        progress = min(1, max(0, start + drag.translation.width / railWidth))
                    }
                    .onEnded { _ in
                        dragStart = nil
                        guard canSend else { return }
                        if progress > 0.92 { send() } else { withAnimation(.rift(0.42)) { progress = 0 } }
                    }
            )
            .accessibilityLabel("Report \(link?.tag ?? "") to PlayRiftbound")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { send() }
    }

    private func caption(_ sent: SentReport?) -> String {
        if let sent { return "REPORTED · \(sent.score)" }
        return sending ? "SENDING TO PLAYRIFTBOUND" : "SLIDE TO REPORT · \(link?.tag ?? "")"
    }

    private func send() {
        guard let link, canSend else { return }
        sending = true
        let log = c.state.log
        withAnimation(.rift(0.26)) { progress = 1 }
        // Not tied to the view: once it is on its way it finishes and says so, also when the summary closes.
        Task {
            do {
                let score = try await report(link, log.map(\.winner))
                c.reported(SentReport(tag: link.tag, log: log, score: score))
                Haptics.success()
                c.show("Reported to PlayRiftbound · \(score)")
                sending = false
                for _ in 0..<2 {
                    withAnimation(.linear(duration: 0.16)) { flash = 0.25 }
                    try? await Task.sleep(for: .milliseconds(160))
                    withAnimation(.linear(duration: 0.22)) { flash = 1 }
                    try? await Task.sleep(for: .milliseconds(220))
                }
            } catch {
                sending = false
                Haptics.warning()
                c.show(error.localizedDescription)
                withAnimation(.rift(0.42)) { progress = 0 }
            }
        }
    }
}
