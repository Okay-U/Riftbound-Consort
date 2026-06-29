//
//  ProfileView.swift
//  Riftbound Companiokay
//
//  "Profile" segment of the Events tab. Resolves the signed-in player's
//  eloshowdown.com profile from their Locator identity and shows their stats.
//  Styled to match the Events "Arena" look; data + "Summoner's DNA" come from
//  eloshowdown (attribution shown). Keyless public API.
//

import SwiftUI
import Charts

struct ProfileView: View {
    @EnvironmentObject private var session: AuthSession
    @AppStorage("batterySaver") private var batterySaver = false
    var service: any EloShowdownService = EloShowdownAPI()

    @State private var state: LoadState = .idle

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
        let dna: EloDNA?
        let form: EloForm?
        let history: EloHistory?
        let opponents: [EloOpponent]
        let achievements: [EloAchievement]
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
        .background(EventsTheme.bg.ignoresSafeArea())
        .refreshable { await load() }
        .task { if case .idle = state { await load() } }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ data: Loaded) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            header(data)
            if let current = data.current {
                seasonCard(current, seasonName: data.season.name ?? data.season.slug)
            } else {
                noSeasonCard(data.season.name ?? "this season")
            }
            if let dna = data.dna, !dna.dimensions.ordered.isEmpty { dnaCard(dna) }
            if let history = data.history, history.points.count >= 2 { eloChartCard(history) }
            if let form = data.form, !form.lastN.isEmpty { formCard(form) }
            if !data.opponents.isEmpty { opponentsCard(data.opponents) }
            if !data.achievements.isEmpty { achievementsCard(data.achievements) }
            attribution(data)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func header(_ data: Loaded) -> some View {
        let player = data.player
        VStack(alignment: .leading, spacing: 10) {
            Text(player.displayName)
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(.white)
            HStack(spacing: 12) {
                if let community = player.primaryCommunity, !community.isEmpty {
                    label("person.3.fill", community)
                }
                if let country = player.country, !country.isEmpty {
                    label("globe.europe.africa.fill", country)
                }
            }
            if let total = player.lifetimeTotalMatches, total > 0 {
                Text("\(total) lifetime matches · \(player.lifetimeWins ?? 0)W \(player.lifetimeLosses ?? 0)L \(player.lifetimeDraws ?? 0)D")
                    .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(alignment: .topTrailing) {
            if !batterySaver {
                RadialGradient(colors: [EventsTheme.green.opacity(0.28), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 220)
                    .allowsHitTesting(false)
            }
        }
        .background(
            LinearGradient(colors: [EventsTheme.overviewFillTop, EventsTheme.overviewFillBottom],
                           startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(EventsTheme.hairline, lineWidth: 1))
    }

    private func label(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
            Text(text)
        }
        .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
    }

    @ViewBuilder
    private func seasonCard(_ s: EloSeasonStats, seasonName: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("chart.line.uptrend.xyaxis", seasonName)

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
                .font(.system(size: 10, weight: .bold)).tracking(0.4)
                .foregroundStyle(EventsTheme.textTertiary)
            Text(value)
                .font(.system(size: 26, weight: .heavy)).foregroundStyle(.white)
            if let sub {
                Text(sub).font(.system(size: 12)).foregroundStyle(EventsTheme.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(EventsTheme.cardInset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(EventsTheme.hairline, lineWidth: 1))
    }

    private func noSeasonCard(_ seasonName: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader("chart.line.uptrend.xyaxis", seasonName)
            Text("No ranked matches yet this season.")
                .font(.system(size: 14)).foregroundStyle(EventsTheme.textSecondary)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .eventsCard(radius: 18)
    }

    // MARK: - Summoner's DNA

    private func dnaCard(_ dna: EloDNA) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("hexagon.fill", "Summoner's DNA")
            DNARadar(dims: dna.dimensions.ordered)
                .frame(height: 250)
                .padding(.top, 4)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .eventsCard(radius: 18)
    }

    // MARK: - ELO history chart

    private func eloChartCard(_ history: EloHistory) -> some View {
        let elos = history.points.compactMap(\.eloAfter)
        let minE = elos.min() ?? 1000
        let maxE = elos.max() ?? 1000
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("waveform.path.ecg", "ELO this season")
            Chart(Array(history.points.enumerated()), id: \.element.id) { item in
                if let elo = item.element.eloAfter {
                    LineMark(x: .value("Match", item.offset), y: .value("ELO", elo))
                        .foregroundStyle(EventsTheme.green)
                        .interpolationMethod(.monotone)
                }
            }
            .chartYScale(domain: (minE - 20)...(maxE + 20))
            .chartXAxis(.hidden)
            .frame(height: 160)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .eventsCard(radius: 18)
    }

    // MARK: - Recent form

    private func formCard(_ form: EloForm) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("flame.fill", "Recent form")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(Array(form.lastN.enumerated()), id: \.offset) { _, result in
                        resultPill(result)
                    }
                }
            }
            HStack(spacing: 14) {
                if let streak = form.currentStreak, let length = streak.length, length > 0 {
                    formStat("Streak", "\(length)\(streakLetter(streak.type))", streakColor(streak.type))
                }
                formStat("Best W", "\(form.longestWinStreak ?? 0)", EventsTheme.green)
                formStat("Worst L", "\(form.longestLossStreak ?? 0)", .red)
                if let change = form.eloChangeLastN {
                    formStat("ELO Δ", (change >= 0 ? "+" : "") + "\(change)",
                             change >= 0 ? EventsTheme.green : .red)
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .eventsCard(radius: 18)
    }

    private func resultPill(_ result: String) -> some View {
        let colors = pillColors(result)
        return Text(result.uppercased())
            .font(.system(size: 12, weight: .bold))
            .frame(width: 24, height: 24)
            .background(colors.bg, in: Circle())
            .foregroundStyle(colors.fg)
    }

    private func pillColors(_ result: String) -> (bg: Color, fg: Color) {
        switch result.uppercased() {
        case "W": return (EventsTheme.green, EventsTheme.matchFillBottom)
        case "L": return (Color.red.opacity(0.85), .white)
        default:  return (EventsTheme.textTertiary.opacity(0.45), .white)
        }
    }

    private func formStat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold)).foregroundStyle(EventsTheme.textTertiary)
            Text(value).font(.system(size: 16, weight: .heavy)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func streakLetter(_ type: String?) -> String {
        switch (type ?? "").lowercased() {
        case "win": return "W"
        case "loss": return "L"
        default: return "D"
        }
    }

    private func streakColor(_ type: String?) -> Color {
        switch (type ?? "").lowercased() {
        case "win": return EventsTheme.green
        case "loss": return .red
        default: return EventsTheme.textSecondary
        }
    }

    // MARK: - Top opponents

    private func opponentsCard(_ opponents: [EloOpponent]) -> some View {
        let top = Array(opponents.prefix(5))
        return VStack(alignment: .leading, spacing: 11) {
            SectionHeader("person.2.fill", "Top opponents")
            VStack(spacing: 0) {
                ForEach(Array(top.enumerated()), id: \.element.id) { index, opp in
                    opponentRow(opp)
                    if index < top.count - 1 {
                        Rectangle().fill(EventsTheme.hairline).frame(height: 1)
                    }
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .eventsCard(radius: 18)
    }

    private func opponentRow(_ opp: EloOpponent) -> some View {
        let color: Color = opp.net > 0 ? EventsTheme.green : (opp.net < 0 ? .red : EventsTheme.textSecondary)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(opp.opponentName)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                Text("\(opp.opponentCommunity ?? "—") · \(opp.opponentCurrentElo ?? 0) ELO")
                    .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
            }
            Spacer(minLength: 8)
            Text(opp.record)
                .font(.system(size: 14, weight: .bold).monospacedDigit())
                .foregroundStyle(color)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Achievements

    private func achievementsCard(_ achievements: [EloAchievement]) -> some View {
        let sorted = achievements.sorted { ($0.earnedAt ?? .distantPast) > ($1.earnedAt ?? .distantPast) }
        return VStack(alignment: .leading, spacing: 11) {
            SectionHeader("rosette", "Achievements") {
                Text("\(achievements.count)")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(EventsTheme.green)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sorted) { achievementChip($0) }
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .eventsCard(radius: 18)
    }

    private func achievementChip(_ ach: EloAchievement) -> some View {
        HStack(spacing: 6) {
            Circle().fill(rarityColor(ach.rarity)).frame(width: 7, height: 7)
            Text(ach.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(EventsTheme.cardInset, in: Capsule())
        .overlay(Capsule().stroke(EventsTheme.hairline, lineWidth: 1))
    }

    private func rarityColor(_ rarity: String?) -> Color {
        switch (rarity ?? "").lowercased() {
        case "legendary": return EventsTheme.gold
        case "epic":      return Color(red: 0.65, green: 0.45, blue: 0.95)
        case "rare":      return Color(red: 0.30, green: 0.65, blue: 0.95)
        case "uncommon":  return EventsTheme.green
        default:          return EventsTheme.textTertiary
        }
    }

    // MARK: - Attribution (required)

    private func attribution(_ data: Loaded) -> some View {
        let url = URL(string: "https://eloshowdown.com/riftbound/player/\(data.player.id)/\(data.season.slug)/")
            ?? URL(string: "https://eloshowdown.com")!
        return Link(destination: url) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.xaxis")
                Text("Stats powered by eloshowdown.com")
                Image(systemName: "arrow.up.right")
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
            Image(systemName: "person.crop.circle.badge.questionmark")
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
            Image(systemName: "wifi.exclamationmark").font(.system(size: 30)).foregroundStyle(EventsTheme.textSecondary)
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
            async let opponentsTask = service.topOpponents(playerID: player.id)
            async let achievementsTask = service.achievements(playerID: player.id)

            let s = try await season
            let st = try await stats
            let current = st.seasons.first { $0.seasonSlug == s.slug }
            state = .loaded(Loaded(player: player, season: s, current: current,
                                   dna: try? await dnaTask,
                                   form: try? await formTask,
                                   history: try? await historyTask,
                                   opponents: (try? await opponentsTask) ?? [],
                                   achievements: (try? await achievementsTask) ?? []))
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

// MARK: - DNA radar (hexagonal chart, eloshowdown's signature visual)

private struct DNARadar: View {
    let dims: [(label: String, value: Double)]   // each value 0...100

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 * 0.66

            ZStack {
                // Grid rings.
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { frac in
                    gridPath(center: center, radius: radius * frac)
                        .stroke(EventsTheme.hairline, lineWidth: 1)
                }
                // Filled value polygon.
                valuePath(center: center, radius: radius)
                    .fill(EventsTheme.green.opacity(0.25))
                valuePath(center: center, radius: radius)
                    .stroke(EventsTheme.green, lineWidth: 2)
                // Vertex dots.
                ForEach(dims.indices, id: \.self) { i in
                    Circle().fill(EventsTheme.green)
                        .frame(width: 5, height: 5)
                        .position(point(i, frac: fraction(i), center: center, radius: radius))
                }
                // Labels + values just outside each axis.
                ForEach(dims.indices, id: \.self) { i in
                    VStack(spacing: 1) {
                        Text(dims[i].label)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(EventsTheme.textSecondary)
                        Text("\(Int(dims[i].value.rounded()))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .position(point(i, frac: 1.32, center: center, radius: radius))
                }
            }
        }
    }

    private func angle(_ i: Int) -> CGFloat {
        -.pi / 2 + CGFloat(i) * (2 * .pi / CGFloat(max(dims.count, 1)))
    }

    private func fraction(_ i: Int) -> CGFloat {
        CGFloat(max(0, min(100, dims[i].value)) / 100)
    }

    private func point(_ i: Int, frac: CGFloat, center: CGPoint, radius: CGFloat) -> CGPoint {
        let a = angle(i)
        return CGPoint(x: center.x + cos(a) * radius * frac,
                       y: center.y + sin(a) * radius * frac)
    }

    private func gridPath(center: CGPoint, radius: CGFloat) -> Path {
        Path { p in
            for i in dims.indices {
                let pt = point(i, frac: 1, center: center, radius: radius)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
    }

    private func valuePath(center: CGPoint, radius: CGFloat) -> Path {
        Path { p in
            for i in dims.indices {
                let pt = point(i, frac: fraction(i), center: center, radius: radius)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
    }
}
