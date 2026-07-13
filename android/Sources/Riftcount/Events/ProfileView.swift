import SwiftUI

/// "Profile" segment of the Events tab, ported from iOS. Resolves the
/// signed-in player's eloshowdown.com profile from their Locator identity and
/// shows their stats. Swift Charts isn't bridged, so the ELO history chart is
/// drawn (line shape + drag scrubber). Attribution shown; keyless public API.
struct ProfileView: View {
    @Environment(AuthSession.self) var session
    var service: any EloShowdownService = EloCache.shared

    @State var state: LoadState = .idle
    @State var scrubIndex: Int?
    @State var matchPageNum = 1

    enum LoadState {
        case idle, loading
        case loaded(Loaded)
        case noProfile
        case failed(String)
    }

    struct Loaded {
        let player: EloPlayer
        let season: EloSeason
        let current: EloSeasonStats?
        let rank: EloRank?
        let dna: EloDNA?
        let form: EloForm?
        let history: EloHistory?
    }

    var body: some View {
        ScrollView {
            switch state {
            case .idle, .loading:
                ProgressView("Loading your profile…")
                    .frame(maxWidth: .infinity, minHeight: 360)
            case .noProfile:
                noProfileState
            case .failed(let message):
                failed(message)
            case .loaded(let data):
                content(data)
            }
        }
        .background(EventsTheme.bg)
        .refreshable {
            // Explicit refresh skips the TTL cache and refetches everything.
            await EloCache.shared.invalidateAll()
            await load()
        }
        .task { if case .idle = state { await load() } }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ data: Loaded) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            attribution(data)
            header(data)
            if let current = data.current {
                seasonCard(current, seasonName: data.season.name ?? data.season.slug)
            } else {
                noSeasonCard(data.season.name ?? "this season")
            }
            if let elo = data.current?.currentElo {
                EloPercentileView(currentElo: elo)
            }
            if let dna = data.dna, !dna.dimensions.ordered.isEmpty {
                dnaCard(dna, profileURL: eloProfileURL(data))
            }
            if let history = data.history, history.points.count >= 2 { eloChartCard(history) }
            matchHistoryCard(data.history?.points ?? [])
            profileFooter(data)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 24)
    }

    private func profileFooter(_ data: Loaded) -> some View {
        Link(destination: eloProfileURL(data)) {
            HStack(spacing: 6) {
                MiniBarsGlyph()
                Text("See more stats")
                Image(systemName: "arrow.forward")
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(EventsTheme.green)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func header(_ data: Loaded) -> some View {
        let tier = data.rank?.tier
        let color = rankTierColor(tier)
        VStack(spacing: 14) {
            // Row 1: emblem + name (left) · ELO (right)
            HStack(alignment: .center, spacing: 12) {
                if let tier, !tier.isEmpty { emblem(tier: tier, color: color) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(data.player.displayName)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    if let rank = data.rank, let tier, !tier.isEmpty {
                        writtenRank(rank, color: color)
                    }
                }
                Spacer(minLength: 8)
                if let elo = data.current?.currentElo {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(elo)")
                            .font(.system(size: 40, weight: .heavy))
                            .foregroundStyle(EventsTheme.gold)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Text(eloLabel(data.season))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(EventsTheme.textTertiary)
                    }
                    .fixedSize()
                }
            }

            if let c = data.current {
                Rectangle().fill(EventsTheme.hairline).frame(height: 1)
                statRow(c)
                if let form = data.form, !form.lastN.isEmpty {
                    Rectangle().fill(EventsTheme.hairline).frame(height: 1)
                    formRow(form)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(alignment: .topTrailing) {
            RadialGradient(colors: [color.opacity(0.22), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 240)
                .allowsHitTesting(false)
        }
        .background(
            LinearGradient(colors: [EventsTheme.overviewFillTop, EventsTheme.overviewFillBottom],
                           startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(EventsTheme.hairline, lineWidth: 1))
    }

    private func emblem(tier: String, color: Color) -> some View {
        // Shared crest (asset or shield fallback) with the profile's glow behind it.
        ZStack {
            Circle().fill(RadialGradient(colors: [color.opacity(0.40), .clear],
                                         center: .center, startRadius: 0, endRadius: 28))
            RankCrest(tier: tier, size: 46)
                .shadow(color: color.opacity(0.45), radius: 5)
        }
        .frame(width: 46, height: 46)
    }

    private func writtenRank(_ rank: EloRank, color: Color) -> some View {
        HStack(spacing: 6) {
            Text((rank.tier ?? "").uppercased())
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(color)
            if let pos = rank.rankInCommunity, let total = rank.totalRanked {
                Text("#\(pos)/\(total)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(EventsTheme.textSecondary)
            }
        }
        .lineLimit(1)
    }

    private func statRow(_ s: EloSeasonStats) -> some View {
        HStack(spacing: 0) {
            statCell("Wins", "\(s.wins ?? 0)", EventsTheme.green)
            statDivider
            statCell("Draws", "\(s.draws ?? 0)", EventsTheme.textSecondary)
            statDivider
            statCell("Losses", "\(s.losses ?? 0)", .red)
            statDivider
            statCell("Win rate", String(format: "%.1f%%", s.winRate ?? 0), EventsTheme.green)
        }
    }

    private func statCell(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(EventsTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle().fill(EventsTheme.hairline).frame(width: 1, height: 30)
    }

    private func formRow(_ form: EloForm) -> some View {
        HStack(spacing: 8) {
            Text("FORM")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(EventsTheme.textTertiary)
            HStack(spacing: 5) {
                ForEach(Array(form.lastN.suffix(8).enumerated()), id: \.offset) { _, result in
                    resultPill(result)
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// "Season 3 - Unleashed" → "S3 ELO". Falls back to "ELO" when no number found.
    private func eloLabel(_ season: EloSeason) -> String {
        if let n = firstInt(season.name) ?? firstInt(season.slug) { return "S\(n) ELO" }
        return "ELO"
    }

    private func firstInt(_ string: String?) -> Int? {
        guard let string else { return nil }
        var digits = ""
        for ch in string {
            if ch.isNumber { digits.append(ch) }
            else if !digits.isEmpty { break }
        }
        return Int(digits)
    }

    @ViewBuilder
    private func seasonCard(_ s: EloSeasonStats, seasonName: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            EventsSectionHeader(seasonName) { MiniBarsGlyph() }

            HStack(spacing: 12) {
                statBox(title: "ELO", value: "\(s.currentElo ?? 0)",
                        sub: "peak \(s.peakElo ?? 0)")
                statBox(title: "Win rate", value: "\(Int((s.winRate ?? 0).rounded()))%",
                        sub: s.record)
            }
            HStack(spacing: 12) {
                statBox(title: "Matches", value: "\(s.matches ?? 0)", sub: nil)
                statBox(title: "Events", value: "\(s.tournaments ?? 0)", sub: nil)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .greenGradientBorder(radius: 18)
    }

    private func statBox(title: String, value: String, sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(EventsTheme.textTertiary)
            Text(value)
                .font(.system(size: 26, weight: .heavy)).foregroundStyle(.white)
            if let sub {
                Text(sub).font(.system(size: 12)).foregroundStyle(EventsTheme.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(EventsTheme.cardInset)
        )
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(EventsTheme.hairline, lineWidth: 1))
    }

    private func noSeasonCard(_ seasonName: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            EventsSectionHeader(seasonName) { MiniBarsGlyph() }
            Text("No ranked matches yet this season.")
                .font(.system(size: 14)).foregroundStyle(EventsTheme.textSecondary)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .eventsCard(radius: 18)
    }

    // MARK: - Summoner's DNA

    private func dnaCard(_ dna: EloDNA, profileURL: URL) -> some View {
        let dims = dna.dimensions.ordered
        let metas = dims.map { dnaMeta($0.label) }
        // Overall "Summoner Score" = mean of the six dimensions.
        let score = Int((dims.map(\.value).reduce(0, +) / Double(max(dims.count, 1))).rounded())
        return VStack(alignment: .leading, spacing: 14) {
            EventsSectionHeader("Summoner's DNA") {
                HexGlyph()
            } trailing: {
                summonerScoreBadge(score)
            }
            Text("Six dimensions that define your competitive style.")
                .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)

            DNARadar(dims: dims, colors: metas.map(\.color))
                .frame(height: 250)
                .padding(.top, 4)

            Link(destination: profileURL) {
                HStack(spacing: 6) {
                    Text("See more on eloshowdown")
                    Image(systemName: "arrow.forward")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(EventsTheme.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(EventsTheme.green.opacity(0.10))
                )
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .eventsCard(radius: 18)
    }

    private func summonerScoreBadge(_ score: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "star.fill")
            Text("Score \(score)/100")
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(EventsTheme.gold)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Capsule().fill(EventsTheme.gold.opacity(0.15)))
    }

    /// Per-dimension accent color used to tint the radar vertices and axis labels.
    struct DNAMeta { let color: Color; let blurb: String }

    private func dnaMeta(_ label: String) -> DNAMeta {
        switch label {
        case "Dominance":
            return DNAMeta(color: EventsTheme.green, blurb: "Overall win rate")
        case "Consistency":
            return DNAMeta(color: Color(red: 0.95, green: 0.62, blue: 0.22),
                           blurb: "Win rate as the favourite")
        case "Composure":
            return DNAMeta(color: Color(red: 0.26, green: 0.73, blue: 0.71),
                           blurb: "Final-round win rate")
        case "Sweep Power":
            return DNAMeta(color: Color(red: 0.93, green: 0.74, blue: 0.30),
                           blurb: "2-0 clean sweeps among wins")
        case "Event Mastery":
            return DNAMeta(color: Color(red: 0.72, green: 0.42, blue: 0.92),
                           blurb: "Events with a 60%+ win rate")
        case "Clutch Closer":
            return DNAMeta(color: Color(red: 0.42, green: 0.62, blue: 0.96),
                           blurb: "Game 3 win rate when tied")
        default:
            return DNAMeta(color: EventsTheme.green, blurb: "")
        }
    }

    // MARK: - ELO history chart (drawn; Swift Charts is not bridged)

    private static let chartHeight: CGFloat = 160
    private static let bubbleSpace: CGFloat = 44

    private func eloChartCard(_ history: EloHistory) -> some View {
        // Plottable points (skip nil ELO); x spread by match offset so the
        // scrubber lands on real matches.
        let pts: [ScrubPoint] = history.points.enumerated().compactMap { o, p in
            p.eloAfter.map { ScrubPoint(offset: o, elo: $0, date: p.date) }
        }
        return VStack(alignment: .leading, spacing: 12) {
            EventsSectionHeader("ELO this season") { MiniBarsGlyph() }
            eloChart(pts)
                .frame(height: Self.chartHeight + Self.bubbleSpace)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .eventsCard(radius: 18)
    }

    private func eloChart(_ pts: [ScrubPoint]) -> some View {
        let elos = pts.map(\.elo)
        let minE = (elos.min() ?? 1000) - 20
        let maxE = (elos.max() ?? 1000) + 20
        let firstOffset = pts.first?.offset ?? 0
        let lastOffset = max(pts.last?.offset ?? 1, firstOffset + 1)

        // Normalized 0…1 chart coordinates (y flipped: bigger ELO = higher).
        let normalized: [CGPoint] = pts.map { p in
            CGPoint(x: CGFloat(p.offset - firstOffset) / CGFloat(lastOffset - firstOffset),
                    y: 1 - CGFloat(p.elo - minE) / CGFloat(max(maxE - minE, 1)))
        }

        return GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .topLeading) {
                // Near-invisible fill so drags on empty chart area register
                // (contentShape is not bridged).
                Rectangle().fill(Color.white.opacity(0.001))
                    .frame(width: width, height: Self.chartHeight + Self.bubbleSpace)

                PolylineShape(points: normalized)
                    .stroke(EventsTheme.green, lineWidth: 2)
                    .frame(height: Self.chartHeight)
                    .offset(y: Self.bubbleSpace)

                if let i = scrubIndex, pts.indices.contains(i) {
                    let px = normalized[i].x * width
                    let py = normalized[i].y * Self.chartHeight + Self.bubbleSpace

                    VerticalDashedLine()
                        .stroke(EventsTheme.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .frame(width: 1, height: Self.chartHeight)
                        .offset(x: px, y: Self.bubbleSpace)

                    Circle()
                        .fill(EventsTheme.green)
                        .frame(width: 10, height: 10)
                        .offset(x: px - 5, y: py - 5)

                    scrubBubble(pts[i])
                        .frame(width: 90)
                        .offset(x: min(max(px - 45, 0), width - 90), y: 0)
                }
            }
            .frame(width: width, height: Self.chartHeight + Self.bubbleSpace, alignment: .topLeading)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in updateScrub(v.location.x, width: width, pts) }
                    .onEnded { _ in scrubIndex = nil }
            )
        }
    }

    private func scrubBubble(_ p: ScrubPoint) -> some View {
        VStack(spacing: 1) {
            Text("\(p.elo)")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.white)
            if let date = p.date {
                Text(date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 10)).foregroundStyle(EventsTheme.textSecondary)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(EventsTheme.cardInset)
        )
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(EventsTheme.hairline, lineWidth: 1))
    }

    /// Map a horizontal touch to the nearest match by ELO-history offset. Light
    /// haptic tick only when the selected point actually changes.
    private func updateScrub(_ x: CGFloat, width: CGFloat, _ pts: [ScrubPoint]) {
        guard let first = pts.first, let last = pts.last, width > 0 else { return }
        let frac = max(0, min(1, x / width))
        let span = Double(last.offset - first.offset)
        let rawOffset = Double(first.offset) + Double(frac) * span
        var best = 0
        var bestDist = Double.infinity
        for (i, p) in pts.enumerated() {
            let d = abs(Double(p.offset) - rawOffset)
            if d < bestDist { bestDist = d; best = i }
        }
        if scrubIndex != best {
            scrubIndex = best
            Haptics.selection()
        }
    }

    // MARK: - Result pills (used by the header form row)

    private func resultPill(_ result: String) -> some View {
        let colors = pillColors(result)
        return Text(result.uppercased())
            .font(.system(size: 12, weight: .bold))
            .frame(width: 24, height: 24)
            .background(Circle().fill(colors.bg))
            .foregroundStyle(colors.fg)
    }

    private func pillColors(_ result: String) -> (bg: Color, fg: Color) {
        switch result.uppercased() {
        case "W": return (EventsTheme.green, EventsTheme.matchFillBottom)
        case "L": return (Color.red.opacity(0.85), .white)
        default:  return (EventsTheme.textTertiary.opacity(0.45), .white)
        }
    }

    // MARK: - Match history (paged locally, newest first)

    // Built from the elo-history points we already fetch for the ELO chart —
    // the dev added opponent_id/opponent_name/result to them (2026-07) at our
    // request, so the old unofficial player-matches endpoint (and its extra
    // request per page) is gone. Paging is a local slice.
    private var matchesPerPage: Int { 5 }

    private func matchHistoryCard(_ points: [EloHistoryPoint]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            EventsSectionHeader("Match History") { Image(systemName: "list.bullet") }
            matchColumnHeader
            Rectangle().fill(EventsTheme.hairline).frame(height: 1)
            if points.isEmpty {
                Text("No matches this season yet.")
                    .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                // The API's `date` is the import time (identical within an event),
                // so sort newest-first by match id (== eloshowdown's own order).
                let ordered = points.sorted { $0.matchId > $1.matchId }
                let totalPages = max((ordered.count + matchesPerPage - 1) / matchesPerPage, 1)
                let current = min(max(matchPageNum, 1), totalPages)
                let start = (current - 1) * matchesPerPage
                let visible = Array(ordered[start ..< min(start + matchesPerPage, ordered.count)])
                VStack(spacing: 0) {
                    ForEach(visible) { point in
                        matchRow(point)
                        Rectangle().fill(EventsTheme.hairline).frame(height: 1)
                    }
                }
                matchPaginationBar(current: current, totalPages: totalPages)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .eventsCard(radius: 18)
    }

    private var matchColumnHeader: some View {
        HStack(spacing: 8) {
            Text("OPPONENT").frame(maxWidth: .infinity, alignment: .leading)
            Text("RESULT").frame(width: 56, alignment: .center)
            Text("±ELO").frame(width: 52, alignment: .trailing)
            Text("DATE").frame(width: 52, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(EventsTheme.textTertiary)
    }

    private func matchRow(_ point: EloHistoryPoint) -> some View {
        let style = matchResultStyle(point.result)
        let delta = point.eloChange ?? 0
        return HStack(spacing: 8) {
            Text(point.opponentName ?? "—")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(style.label)
                .font(.system(size: 13, weight: .bold)).foregroundStyle(style.color)
                .frame(width: 56, alignment: .center)
            Text(delta > 0 ? "+\(delta)" : "\(delta)")
                .font(.system(size: 13, weight: .heavy)).foregroundStyle(style.color)
                .frame(width: 52, alignment: .trailing)
            Text(point.date?.formatted(.dateTime.month(.abbreviated).day()) ?? "—")
                .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
                .frame(width: 52, alignment: .trailing)
        }
        .padding(.vertical, 11)
    }

    private func matchResultStyle(_ result: String?) -> (label: String, color: Color) {
        switch (result ?? "").lowercased() {
        case "win":  return ("Win", EventsTheme.green)
        case "loss": return ("Loss", .red)
        default:     return ("Draw", EventsTheme.textSecondary)
        }
    }

    private func matchPaginationBar(current: Int, totalPages: Int) -> some View {
        HStack {
            Button { matchPageNum = current - 1 } label: {
                Text("‹ Newer")
            }
            .disabled(current <= 1)

            Spacer()
            Text("Page \(current) of \(totalPages)")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(EventsTheme.textSecondary)
            Spacer()

            Button { matchPageNum = current + 1 } label: {
                Text("Older ›")
            }
            .disabled(current >= totalPages)
        }
        .font(.system(size: 13, weight: .bold))
        .tint(EventsTheme.green)
        .padding(.top, 10)
    }

    // MARK: - Attribution (required)

    /// Public eloshowdown player page. Keyed by the eloshowdown internal id
    /// (EloPlayer.id) — NOT the Riftbound id, which maps to a different player.
    private func eloProfileURL(_ data: Loaded) -> URL {
        URL(string: "https://eloshowdown.com/riftbound/player/\(data.player.id)/\(data.season.slug)/")
            ?? URL(string: "https://eloshowdown.com")!
    }

    private func attribution(_ data: Loaded) -> some View {
        Link(destination: eloProfileURL(data)) {
            HStack(spacing: 6) {
                MiniBarsGlyph()
                Text("Stats powered by eloshowdown.com")
                Image(systemName: "arrow.forward")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(EventsTheme.textSecondary)
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 4)
    }

    // MARK: - Empty / failed

    private var noProfileState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 34)).foregroundStyle(EventsTheme.textTertiary)
            Text("No eloshowdown profile yet")
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
            Text("Play in tracked tournaments and your stats will show up here.")
                .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 360).padding(.horizontal, 24)
    }

    private func failed(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("Couldn't load your profile").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
            Text(message).font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary).multilineTextAlignment(.center)
            Button("Retry") { Task { await load() } }.tint(EventsTheme.green)
        }
        .frame(maxWidth: .infinity, minHeight: 360).padding(.horizontal, 24)
    }

    // MARK: - Load

    @MainActor
    private func load() async {
        guard let userID = session.userID else { state = .failed("Sign in to see your profile."); return }
        state = .loading
        matchPageNum = 1         // back to page 1 of match history for the new load
        do {
            guard let player = try await resolvePlayer(userID: userID) else {
                state = .noProfile
                return
            }
            async let season = service.currentSeason()
            async let stats = service.stats(playerID: player.id)
            // Optional extras — a missing one shouldn't fail the whole screen.
            async let dnaTask = service.dna(playerID: player.id)
            async let formTask = service.form(playerID: player.id)
            async let historyTask = service.eloHistory(playerID: player.id)
            async let rankTask = service.rank(playerID: player.id)

            let s = try await season
            let st = try await stats
            let current = st.seasons.first { $0.seasonSlug == s.slug }
            state = .loaded(Loaded(player: player, season: s, current: current,
                                   rank: try? await rankTask,
                                   dna: try? await dnaTask,
                                   form: try? await formTask,
                                   history: try? await historyTask))
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    /// Primary: resolve by Riftbound id (== Locator userID). Fallback: exact name search.
    private func resolvePlayer(userID: Int) async throws -> EloPlayer? {
        if let byID = try await service.lookup(riftboundID: String(userID)) {
            return byID
        }
        guard let name = session.currentUser?.displayName, name.count >= 3 else { return nil }
        let hits = try await service.search(query: name)
        guard let hit = hits.first(where: { $0.displayName == name }) ?? hits.first else { return nil }
        return try await service.player(id: hit.id)
    }
}

/// A scrubbed/plotted point on the ELO history chart.
struct ScrubPoint {
    let offset: Int
    let elo: Int
    let date: Date?
}

/// Straight-line path through normalized (0…1) points, scaled to the rect.
struct PolylineShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        Path { p in
            for (i, pt) in points.enumerated() {
                let scaled = CGPoint(x: rect.minX + pt.x * rect.width,
                                     y: rect.minY + pt.y * rect.height)
                if i == 0 { p.move(to: scaled) } else { p.addLine(to: scaled) }
            }
        }
    }
}

/// Small drawn hexagon glyph (hexagon.fill is not in SkipUI's symbol map).
struct HexGlyph: View {
    var body: some View {
        RadarPolygonShape(count: 6, fractions: [1, 1, 1, 1, 1, 1])
            .fill(EventsTheme.green)
            .frame(width: 13, height: 13)
    }
}

// MARK: - DNA radar (hexagonal chart, eloshowdown's signature visual)

/// Radar polygon: vertex i sits at angle -π/2 + i·2π/count, at `fractions[i]`
/// of the radius. fractions of all 1s = the outer grid ring.
struct RadarPolygonShape: Shape {
    let count: Int
    let fractions: [CGFloat]
    var radiusScale: CGFloat = 1

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 * radiusScale
        return Path { p in
            for i in 0..<count {
                let a = -CGFloat.pi / 2 + CGFloat(i) * (2 * .pi / CGFloat(max(count, 1)))
                let frac = i < fractions.count ? fractions[i] : 0
                let pt = CGPoint(x: center.x + cos(a) * radius * frac,
                                 y: center.y + sin(a) * radius * frac)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
    }
}

struct DNARadar: View {
    let dims: [(label: String, value: Double)]   // each value 0...100
    let colors: [Color]                          // per-dimension accent, parallel to dims

    private func color(_ i: Int) -> Color { i < colors.count ? colors[i] : EventsTheme.green }

    var body: some View {
        GeometryReader { geo in
            let radius = min(geo.size.width, geo.size.height) / 2 * 0.66
            let scale = radius / (min(geo.size.width, geo.size.height) / 2)

            ZStack {
                // Grid rings.
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { frac in
                    RadarPolygonShape(count: dims.count,
                                      fractions: Array(repeating: CGFloat(frac), count: dims.count),
                                      radiusScale: scale)
                        .stroke(EventsTheme.hairline, lineWidth: 1)
                }
                // Filled value polygon.
                RadarPolygonShape(count: dims.count, fractions: fractions, radiusScale: scale)
                    .fill(EventsTheme.green.opacity(0.25))
                RadarPolygonShape(count: dims.count, fractions: fractions, radiusScale: scale)
                    .stroke(EventsTheme.green, lineWidth: 2)
                // Vertex dots, tinted per dimension. Offset from the ZStack
                // center (.position mismeasures on Compose).
                ForEach(dims.indices, id: \.self) { i in
                    let pt = delta(i, frac: fractions[i], radius: radius)
                    Circle().fill(color(i))
                        .frame(width: 7, height: 7)
                        .offset(x: pt.x, y: pt.y)
                }
                // Labels + values just outside each axis.
                ForEach(dims.indices, id: \.self) { i in
                    let pt = delta(i, frac: 1.32, radius: radius)
                    VStack(spacing: 1) {
                        Text(dims[i].label)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(color(i))
                        Text("\(Int(dims[i].value.rounded()))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .offset(x: pt.x, y: pt.y)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var fractions: [CGFloat] {
        dims.map { CGFloat(max(0, min(100, $0.value)) / 100) }
    }

    private func angle(_ i: Int) -> CGFloat {
        -.pi / 2 + CGFloat(i) * (2 * .pi / CGFloat(max(dims.count, 1)))
    }

    /// Offset of vertex i from the chart center.
    private func delta(_ i: Int, frac: CGFloat, radius: CGFloat) -> CGPoint {
        let a = angle(i)
        return CGPoint(x: cos(a) * radius * frac, y: sin(a) * radius * frac)
    }
}
