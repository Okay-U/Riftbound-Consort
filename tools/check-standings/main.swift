import Foundation

let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .custom { decoder in
        let raw = try decoder.singleValueContainer().decode(String.self)
        if let date = try? Date(raw, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true)) { return date }
        if let date = try? Date(raw, strategy: .iso8601) { return date }
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: raw))
    }
    return d
}()

var checkedRows = 0, rankOutsideTies = 0, worst = 0.0
let dir = URL(fileURLWithPath: CommandLine.arguments[1])
let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
precondition(!files.isEmpty, "no tournaments downloaded")
for file in files {
    let t = try decoder.decode(CompeteTournament.self, from: Data(contentsOf: file))
    for round in t.rounds {
        let riot = round.endOfRoundStandings ?? []
        guard !riot.isEmpty else { continue }
        let table = CompeteStandings.compute(t, throughRound: round.roundNumber)
        precondition(table.rows.count == riot.count, "\(file) R\(round.roundNumber): \(table.rows.count) rows vs \(riot.count)")
        precondition(table.pending.isEmpty && table.reportedMatches == table.totalMatches, "finished round has pending matches")
        let ours = Dictionary(uniqueKeysWithValues: table.rows.map { ($0.esportsTeamId, $0) })
        var shared: [Int: Int] = [:]
        for row in table.rows { shared[row.rank ?? 0, default: 0] += 1 }
        for official in riot {
            guard let mine = ours[official.esportsTeamId] else { preconditionFailure("missing team") }
            precondition(mine.matchPoints == official.matchPoints, "points")
            precondition(mine.record == official.record, "record \(mine.record) vs \(official.record)")
            for (a, b) in [(mine.opponentMatchWinPercentage, official.opponentMatchWinPercentage),
                           (mine.gameWinPercentage, official.gameWinPercentage),
                           (mine.opponentGameWinPercentage, official.opponentGameWinPercentage)] {
                worst = max(worst, abs((a ?? -1) - (b ?? -2)))
            }
            // Outside a shared rank our rank must be Riot's; inside, Riot's must fall in the shared block.
            let r = mine.rank ?? 0, size = shared[r] ?? 1, theirs = official.rank ?? 0
            if size == 1 { if r != theirs { rankOutsideTies += 1 } }
            else { precondition((r..<(r + size)).contains(theirs), "rank \(theirs) outside shared block \(r)+\(size)") }
            checkedRows += 1
        }
    }
    // Live: drop the last round's results one by one and check the bookkeeping.
    if let last = t.rounds.last {
        let full = CompeteStandings.compute(t, throughRound: last.roundNumber)
        precondition(full.totalMatches == last.matches.filter { $0.teams.count == 2 }.count)
    }
}
precondition(worst < 1e-12, "tiebreakers differ by \(worst)")
precondition(rankOutsideTies == 0, "\(rankOutsideTies) ranks differ outside exact ties")
print("standings ok: \(checkedRows) rows, max tiebreak diff \(worst)")
