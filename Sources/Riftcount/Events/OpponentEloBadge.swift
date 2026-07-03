import SwiftUI

/// Compact opponent scouting line for the live "Your match" card, ported from
/// iOS: the opponent's eloshowdown tier crest + current ELO + their last 3
/// results + H2H vs you. Resolved from the opponent's Riftbound id (the
/// Locator user id on the pairing) via eloshowdown lookup. Renders nothing
/// until data loads, and nothing at all without an eloshowdown profile.
struct OpponentEloBadge: View {
    let riftboundID: Int?
    var myRiftboundID: Int? = nil
    var service: any EloShowdownService = EloShowdownAPI()

    @State var phase: Phase = .idle

    enum Phase { case idle, loading, loaded(Loaded), hidden }
    struct Loaded { let elo: Int?; let tier: String?; let form: [String]; let h2h: EloH2H? }

    var body: some View {
        Group {
            if case .loaded(let data) = phase { row(data) }
        }
        .task { await load() }
    }

    private func row(_ data: Loaded) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                RankCrest(tier: data.tier, size: 22)
                if let elo = data.elo {
                    Text("\(elo)")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("ELO")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(EventsTheme.textTertiary)
                }
                Spacer(minLength: 8)
                if !data.form.isEmpty {
                    Text("last 3")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(EventsTheme.textTertiary)
                    HStack(spacing: 3) {
                        ForEach(Array(data.form.enumerated()), id: \.offset) { _, result in
                            miniPill(result)
                        }
                    }
                }
            }
            if let h2h = data.h2h, h2h.hasHistory { h2hLine(h2h) }
        }
        .padding(.top, 6)
    }

    private func h2hLine(_ h2h: EloH2H) -> some View {
        let draws = h2h.draws ?? 0
        let record = "\(h2h.wins ?? 0)–\(h2h.losses ?? 0)" + (draws > 0 ? "–\(draws)" : "")
        return HStack(spacing: 6) {
            // arrow.left.arrow.right isn't in SkipUI's symbol map.
            Text("↔")
            Text("H2H vs you \(record)")
            if let swing = h2h.eloSwingTotal, swing != 0 {
                Text(swing > 0 ? "+\(swing)" : "\(swing)")
                    .foregroundStyle(swing > 0 ? EventsTheme.green : .red)
            }
            if let last = h2h.lastMeeting?.result {
                Text("· last \(last.lowercased())").foregroundStyle(EventsTheme.textTertiary)
            }
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(EventsTheme.textSecondary)
    }

    private func miniPill(_ result: String) -> some View {
        let colors = pillColors(result)
        return Text(result.uppercased())
            .font(.system(size: 9, weight: .bold))
            .frame(width: 16, height: 16)
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

    @MainActor
    private func load() async {
        guard case .idle = phase else { return }
        guard let rid = riftboundID else { phase = .hidden; return }
        phase = .loading
        guard let player = try? await service.lookup(riftboundID: String(rid)) else {
            phase = .hidden
            return
        }
        async let seasonTask = service.currentSeason()
        async let statsTask = service.stats(playerID: player.id)
        async let rankTask = service.rank(playerID: player.id)
        async let formTask = service.form(playerID: player.id)
        async let meTask = lookupMe()

        let season = try? await seasonTask
        let stats = try? await statsTask
        let elo = stats?.seasons.first { $0.seasonSlug == season?.slug }?.currentElo
        let tier = (try? await rankTask)?.tier
        let form = Array(((try? await formTask)?.lastN ?? []).suffix(3))

        var h2h: EloH2H?
        if let me = await meTask {
            h2h = try? await service.headToHead(playerID: me.id, opponentID: player.id)
        }

        if elo == nil, tier == nil, form.isEmpty, h2h?.hasHistory != true { phase = .hidden; return }
        phase = .loaded(Loaded(elo: elo, tier: tier, form: form, h2h: h2h))
    }

    /// Resolve the signed-in user to their eloshowdown player (for the H2H lookup).
    private func lookupMe() async -> EloPlayer? {
        guard let mine = myRiftboundID else { return nil }
        return try? await service.lookup(riftboundID: String(mine))
    }
}
