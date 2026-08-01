import SwiftUI

/// Scouting row for the "Your match" card, ported from iOS: both sides'
/// eloshowdown tier crest and current ELO, mirrored under the two player names,
/// plus the head-to-head line from the signed-in player's perspective. Players
/// resolve from their Riftbound id (display name as fallback); a side without
/// an eloshowdown profile is left out, and the whole row hides when neither
/// side has data.
struct OpponentEloBadge: View {
    let riftboundID: Int?
    /// Per-event display name — fallback resolution when the pairing carries no
    /// usable Riftbound id (eloshowdown mirrors Locator names exactly).
    var opponentName: String? = nil
    var myRiftboundID: Int? = nil
    var myName: String? = nil
    var service: any EloShowdownService = EloCache.shared

    @State var phase: Phase = .idle

    enum Phase { case idle, loading, loaded(Loaded), hidden }

    /// One player's scouting numbers.
    struct Side {
        let elo: Int?
        let tier: String?

        var isEmpty: Bool { elo == nil && tier == nil }
    }

    struct Loaded { let me: Side?; let opponent: Side?; let h2h: EloH2H?; let opponentLabel: String? }

    var body: some View {
        Group {
            if case .loaded(let data) = phase {
                row(data)
            } else {
                // Never let the body collapse to EmptyView: .task/.onAppear
                // don't fire on it, so load() would never run.
                Color.clear.frame(width: 1, height: 1)
            }
        }
        .task { await load() }
    }

    // MARK: - Row

    private func row(_ data: Loaded) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                sideColumn(data.me, mine: true)
                Spacer(minLength: 8)
                sideColumn(data.opponent, mine: false)
            }
            if let h2h = data.h2h, h2h.hasHistory { h2hLine(h2h, opponent: data.opponentLabel) }
        }
        .padding(.top, 8)
    }

    /// Crest + ELO, mirrored so each column hugs its own player's name in the
    /// VS row above.
    @ViewBuilder
    private func sideColumn(_ side: Side?, mine: Bool) -> some View {
        if let side, !side.isEmpty {
            HStack(spacing: 6) {
                if mine {
                    RankCrest(tier: side.tier, size: 20)
                    eloText(side.elo)
                } else {
                    eloText(side.elo)
                    RankCrest(tier: side.tier, size: 20)
                }
            }
        }
    }

    @ViewBuilder
    private func eloText(_ elo: Int?) -> some View {
        if let elo {
            HStack(spacing: 4) {
                Text("\(elo)")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.white)
                Text("ELO")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(EventsTheme.textTertiary)
            }
        }
    }

    private func h2hLine(_ h2h: EloH2H, opponent: String?) -> some View {
        let draws = h2h.draws ?? 0
        let record = "\(h2h.wins ?? 0)–\(h2h.losses ?? 0)" + (draws > 0 ? "–\(draws)" : "")
        return HStack(spacing: 6) {
            // arrow.left.arrow.right isn't in SkipUI's symbol map.
            Text("↔")
            Text("You vs \(opponent ?? "opponent")").lineLimit(1)
            Text(record).foregroundStyle(.white)
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

    // MARK: - Load

    @MainActor
    private func load() async {
        guard case .idle = phase else { return }
        phase = .loading

        async let opponentPlayer = resolve(id: riftboundID, name: opponentName)
        async let mePlayer = resolve(id: myRiftboundID, name: myName)
        let (opponent, me) = await (opponentPlayer, mePlayer)

        guard opponent != nil || me != nil else {
            logger.info("EloBadge: neither side resolved — hiding")
            phase = .hidden
            return
        }

        // One season resolution for both sides.
        let season = try? await service.currentSeason()
        async let opponentSide = side(for: opponent, season: season?.slug)
        async let meSide = side(for: me, season: season?.slug)

        var h2h: EloH2H?
        if let me, let opponent {
            h2h = try? await service.headToHead(playerID: me.id, opponentID: opponent.id)
        }

        let (opp, mine) = await (opponentSide, meSide)
        let label = opponent?.displayName ?? opponentName
        if opp?.isEmpty != false, mine?.isEmpty != false, h2h?.hasHistory != true {
            logger.info("EloBadge: resolved but empty — hiding")
            phase = .hidden
            return
        }
        phase = .loaded(Loaded(me: mine, opponent: opp, h2h: h2h, opponentLabel: label))
    }

    private func side(for player: EloPlayer?, season: String?) async -> Side? {
        guard let player else { return nil }
        async let statsTask = service.stats(playerID: player.id)
        async let rankTask = service.rank(playerID: player.id, season: season)

        let elo = (try? await statsTask)?.seasons.first { $0.seasonSlug == season }?.currentElo
        let tier = (try? await rankTask)?.tier
        return Side(elo: elo, tier: tier)
    }

    /// Primary: Riftbound-id lookup. Fallback: exact display-name match — the
    /// pairing payload doesn't always carry a usable id for every player.
    private func resolve(id: Int?, name: String?) async -> EloPlayer? {
        if let id, let player = try? await service.lookup(riftboundID: String(id)) {
            return player
        }
        guard let name = name?.trimmingCharacters(in: .whitespaces), name.count >= 3,
              let hits = try? await service.search(query: name),
              let hit = hits.first(where: { $0.displayName.caseInsensitiveCompare(name) == .orderedSame }),
              let player = try? await service.player(id: hit.id)
        else { return nil }
        return player
    }
}
