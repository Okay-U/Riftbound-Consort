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

// MARK: - Bracket and 2v2 self-check
// No Riftbound top cut or 2v2 event exists on PlayRiftbound yet, so this checks the app's reading of
// one built the way the site's client code expects: Swiss in section 0, the top cut in section 1.

func team(_ id: String, _ players: ArraySlice<(String, String)>) -> [String: Any] {
    ["esportsTeamId": id, "players": players.map { ["id": $0.0, "displayName": $0.1] }]
}
func match(_ id: String, _ a: [String: Any], _ b: [String: Any], winner: String) -> [String: Any] {
    let outcomes = [a, b].map { t -> [String: Any] in
        let id = t["esportsTeamId"] as! String
        return ["esportsTeamId": id, "outcome": id == winner ? "WIN" : "LOSS"]
    }
    return ["esportsMatchId": id, "tableNumber": 1, "status": "IN_PROGRESS", "teams": [a, b], "teamOutcomes": outcomes,
            "games": [["esportsGameId": id + "-g1", "number": 1, "teamOutcomes": outcomes]]]
}
func round(_ n: Int, _ status: String, _ matches: [[String: Any]], byes: [String] = [], standings: [String] = []) -> [String: Any] {
    ["roundNumber": n, "status": status, "matches": matches, "byeTeamIds": byes,
     "endOfRoundStandings": standings.enumerated().map { ["esportsTeamId": $0.element, "rank": $0.offset + 1] }]
}

let players = [("p1", "Ann"), ("p2", "Bo"), ("p3", "Cy"), ("p4", "Di"), ("p5", "Eve"),
               ("p6", "Fay"), ("p7", "Gus"), ("p8", "Hal"), ("p9", "Ida"), ("p10", "Jo")]
let teams = (0..<5).map { team("T\($0 + 1)", players[(2 * $0)..<(2 * $0 + 2)]) }
let swiss = [round(1, "FINALIZED", [match("m1", teams[0], teams[1], winner: "T1"), match("m2", teams[2], teams[3], winner: "T3")], byes: ["T5"]),
             round(2, "FINALIZED", [match("m3", teams[0], teams[2], winner: "T1"), match("m4", teams[1], teams[4], winner: "T2")],
                   byes: ["T4"], standings: ["T1", "T2", "T3", "T4", "T5"])]
func cut(final status: String, from n: Int) -> [[String: Any]] {
    [round(n, "FINALIZED", [match("m5", teams[0], teams[3], winner: "T1"), match("m6", teams[1], teams[2], winner: "T3")]),
     round(n + 1, status, [match("m7", teams[0], teams[2], winner: "T3")])]
}
func bracket(_ sections: [[[String: Any]]]) throws -> CompeteTournament {
    let participants = players.enumerated().map { i, p -> [String: Any] in
        ["id": "part-\(p.0)", "esportsTeamId": "T\(i / 2 + 1)", "status": i >= 8 ? "ELIMINATED" : "ACTIVE",
         "player": ["id": p.0, "displayName": p.1]]
    }
    let json: [String: Any] = ["id": "check", "name": "Bracket check",
                               "config": ["structure": "SWISS_PLUS_SINGLE_ELIM", "roundCount": 2, "playerFormat": "TWO_V_TWO"],
                               "stages": [["sections": sections.map { ["rounds": $0] }]],
                               "tournamentParticipants": participants]
    return try decoder.decode(CompeteTournament.self, from: JSONSerialization.data(withJSONObject: json))
}

// The cut as its own section (round numbers start again) and as rounds 3–4 of the Swiss section.
for t in [try bracket([swiss, cut(final: "FINALIZED", from: 1)]), try bracket([swiss + cut(final: "FINALIZED", from: 3)])] {
    precondition(Set(t.rounds.map(\.id)).count == 4, "round ids not unique")
    precondition(t.rounds.map { t.title(of: $0) } == ["Round 1", "Round 2", "Semifinal", "Final"], "titles")
    precondition(t.rounds.map { t.shortTitle(of: $0) } == ["R1", "R2", "SF", "F"], "short titles")
    precondition(t.swissRounds.count == 2 && t.isFinished, "swiss rounds / finished")
    precondition(t.placement(teamID: "T3") == .rank(1) && t.placement(teamID: "T1") == .rank(2), "final placements")
    precondition(t.placement(teamID: "T2") == .top(4) && t.placement(teamID: "T4") == .top(4), "semifinal placements")
    precondition(t.placement(teamID: "T5") == .rank(5), "missed the cut: Swiss rank")
    precondition(t.teamName("T3") == "Eve & Fay", "2v2 team name")
    precondition(t.state(of: "p9") == .eliminated && t.state(of: "p1") == .active, "player state")
    let swissTable = CompeteStandings.compute(t, throughRound: 2)
    precondition(swissTable.rows.count == 5 && swissTable.rows.first { $0.esportsTeamId == "T1" }?.matchPoints == 6,
                 "top-cut wins leaked into the Swiss standings")
    guard let final = CompetePairing.resolve(in: t, playerID: "p1") else { preconditionFailure("no final pairing") }
    precondition(final.roundTitle == "Final" && final.opponentName == "Eve & Fay" && final.teammateName == "Bo", "2v2 pairing names")
    precondition(final.myParticipantID == "part-p1" && final.opponentParticipantID == "part-p5" && final.result == .loss, "2v2 pairing ids")
}
// An unpublished (PENDING) final is hidden, as on the site: the semifinal is the latest round.
let pending = try bracket([swiss, cut(final: "PENDING", from: 1)])
precondition(pending.rounds.count == 3 && !pending.isFinished && pending.placement(teamID: "T3") == nil, "pending round shown")
precondition(CompetePairing.resolve(in: pending, playerID: "p1")?.opponentName == "Gus & Hal", "pending: latest pairing")
print("bracket ok: section and continued numbering, 2v2 names, placements, pending round hidden")
