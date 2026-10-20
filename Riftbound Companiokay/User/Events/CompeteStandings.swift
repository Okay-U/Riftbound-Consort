//
//  CompeteStandings.swift
//  Riftbound Companiokay
//
//  Swiss standings computed on the device from every reported result, so a player
//  sees the table during a round instead of only after Riot finalises it.
//
//  Same rules as PlayRiftbound, verified against Riot's own end-of-round standings
//  (three events, ten rounds, 192 rows, 2026-10-20): points and records identical,
//  OMW%, GW% and OGW% identical to float precision, ranks identical except inside
//  exact ties, whose order Riot does not expose (shown here as a shared rank).
//
//  - win 3, draw 1, loss 0; a bye is a win worth 3 points but is left out of MW% and GW%
//  - MW%  = max(0.33, points from played matches / (3 × played matches))
//  - GW%  = max(0.33, game wins / (game wins + game losses)); drawn games are ignored
//  - OMW% / OGW% = mean of the opponents' MW% / GW%
//  - order: points, OMW%, GW%, OGW%
//

import Foundation

nonisolated enum CompeteStandings {
    /// The floor PlayRiftbound applies to every percentage (0.33, not one third).
    static let floor = 0.33

    struct Table: Sendable {
        let roundNumber: Int
        /// Sorted; `rank` is shared within exact ties.
        let rows: [CompeteTournament.Standing]
        /// Teams whose match in `roundNumber` has no result yet.
        let pending: Set<String>
        let reportedMatches: Int
        let totalMatches: Int
    }

    private enum Result { case win, draw, loss }

    private static func result(_ outcome: String?) -> Result {
        let o = outcome?.uppercased() ?? ""
        if o.contains("WIN") { return .win }
        if o.contains("TIE") || o.contains("DRAW") { return .draw }
        return .loss
    }

    /// Swiss standings after every reported result up to and including Swiss round `round`;
    /// top-cut rounds do not count.
    static func compute(_ tournament: CompeteTournament, throughRound round: Int) -> Table {
        var points: [String: Int] = [:], byePoints: [String: Int] = [:]
        var wins: [String: Int] = [:], losses: [String: Int] = [:], draws: [String: Int] = [:]
        var played: [String: Int] = [:], gameWins: [String: Int] = [:], gameLosses: [String: Int] = [:]
        var opponents: [String: [String]] = [:]
        var teams: [String] = []
        var seen: Set<String> = []
        var pending: Set<String> = []
        var reported = 0, total = 0

        func note(_ team: String) { if seen.insert(team).inserted { teams.append(team) } }

        for r in tournament.swissRounds where r.roundNumber <= round {
            for team in r.byeTeamIds ?? [] {
                note(team)
                points[team, default: 0] += 3
                byePoints[team, default: 0] += 3
                wins[team, default: 0] += 1
            }
            for match in r.matches {
                let ids = match.teams.map(\.esportsTeamId)
                ids.forEach(note)
                guard ids.count == 2 else { continue }
                let isLive = r.roundNumber == round
                if isLive { total += 1 }
                var outcomes: [String: String?] = [:]
                for o in match.teamOutcomes ?? [] { if let id = o.esportsTeamId { outcomes[id] = o.outcome } }
                guard !outcomes.isEmpty else {
                    if isLive { pending.formUnion(ids) }
                    continue
                }
                if isLive { reported += 1 }
                opponents[ids[0], default: []].append(ids[1])
                opponents[ids[1], default: []].append(ids[0])
                for id in ids {
                    played[id, default: 0] += 1
                    switch result(outcomes[id] ?? nil) {
                    case .win:  points[id, default: 0] += 3; wins[id, default: 0] += 1
                    case .draw: points[id, default: 0] += 1; draws[id, default: 0] += 1
                    case .loss: losses[id, default: 0] += 1
                    }
                }
                for game in match.games ?? [] {
                    for o in game.teamOutcomes ?? [] {
                        guard let id = o.esportsTeamId, ids.contains(id) else { continue }
                        let value = o.outcome?.uppercased() ?? ""
                        if value.contains("WIN") { gameWins[id, default: 0] += 1 }
                        else if value.hasPrefix("LOS") { gameLosses[id, default: 0] += 1 }
                    }
                }
            }
        }

        func matchWin(_ id: String) -> Double {
            let n = played[id] ?? 0
            guard n > 0 else { return floor }
            return max(floor, Double((points[id] ?? 0) - (byePoints[id] ?? 0)) / Double(3 * n))
        }
        func gameWin(_ id: String) -> Double {
            let w = gameWins[id] ?? 0, l = gameLosses[id] ?? 0
            guard w + l > 0 else { return floor }
            return max(floor, Double(w) / Double(w + l))
        }
        func mean(_ ids: [String], _ value: (String) -> Double) -> Double {
            ids.isEmpty ? floor : ids.map(value).reduce(0, +) / Double(ids.count)
        }

        struct Entry {
            let id: String, points: Int, omw: Double, gw: Double, ogw: Double
            /// Tiebreakers compared to nine decimals: averages carry float noise in the last bit.
            var key: [Int64] { [Int64(points), q(omw), q(gw), q(ogw)] }
            private func q(_ v: Double) -> Int64 { Int64((v * 1e9).rounded()) }
        }
        let entries = teams.map { id in
            Entry(id: id, points: points[id] ?? 0,
                  omw: mean(opponents[id] ?? [], matchWin), gw: gameWin(id), ogw: mean(opponents[id] ?? [], gameWin))
        }
        // Inside exact ties keep the last official order, so rows do not jump around.
        let previous = tournament.swissRounds.last { $0.roundNumber < round && !($0.endOfRoundStandings ?? []).isEmpty }
        var previousRank: [String: Int] = [:]
        for s in previous?.endOfRoundStandings ?? [] { if let rank = s.rank { previousRank[s.esportsTeamId] = rank } }

        let sorted = entries.sorted { a, b in
            if a.key != b.key { return a.key.lexicographicallyPrecedes(b.key, by: >) }
            let pa = previousRank[a.id] ?? Int.max, pb = previousRank[b.id] ?? Int.max
            return pa != pb ? pa < pb : a.id < b.id
        }
        var rows: [CompeteTournament.Standing] = []
        var rank = 0
        for (index, entry) in sorted.enumerated() {
            if index == 0 || sorted[index - 1].key != entry.key { rank = index + 1 }
            rows.append(.init(esportsTeamId: entry.id, rank: rank, matchPoints: entry.points,
                              matchWins: wins[entry.id] ?? 0, matchLosses: losses[entry.id] ?? 0, matchDraws: draws[entry.id] ?? 0,
                              matchWinPercentage: matchWin(entry.id), opponentMatchWinPercentage: entry.omw,
                              gameWinPercentage: entry.gw, opponentGameWinPercentage: entry.ogw))
        }
        return Table(roundNumber: round, rows: rows, pending: pending, reportedMatches: reported, totalMatches: total)
    }
}
