//
//  MatchLink.swift
//  Riftbound Companiokay
//
//  Match mode for the redesign's scoreboard (Android `TableLink.kt`, `ScoreLink.kt`): what the seam shows
//  of the player's next PlayRiftbound event, and the report of a played series with the report sheet's
//  rules (the pairing is fetched again first; a re-paired or already reported match is refused).
//

import Foundation

/// The pairing to play and report, once the round is up.
struct TableLink: Equatable {
    /// "R3 · T5".
    let tag: String
    let table: Int?
    let opponent: String?
    /// The event's format, 1 or 3 games.
    let bestOf: Int
    let reportable: Bool
    /// Riot has a result for the match (from this phone or another).
    let reported: Bool
    /// The round clock's end while the round runs.
    let roundEndsAt: Date?
    let tournamentID: String
    let pairing: CompetePairing
}

/// "18:30 · Summoner Skirmish", "R3 · BYE", "R3 · T5 · Reported".
struct EventLine: Equatable {
    let label: String
    let text: String
}

/// Match mode's view of the next event; there is one whenever match mode is on with two players.
struct MatchInfo: Equatable {
    let link: TableLink?
    /// What to say when there is nothing to play: the event before round 1, a bye, a reported round.
    let line: EventLine?
    /// The event's name while there is one; the seam's centre offers to open it.
    let event: String?
    let webURL: URL?

    init(strip: PlayRiftboundStrip?) {
        let pairing = strip?.pairing
        let tag = pairing.map { p in (strip?.roundShort ?? p.roundTitle) + (p.tableNumber.map { " · T\($0)" } ?? "") }
        if let strip, let pairing, let tag, !pairing.isBye {
            link = TableLink(
                tag: tag, table: pairing.tableNumber, opponent: pairing.opponentName, bestOf: pairing.bestOf,
                reportable: pairing.isReportable, reported: pairing.isComplete, roundEndsAt: strip.roundEndsAt,
                tournamentID: strip.tournamentID, pairing: pairing
            )
        } else {
            link = nil
        }
        if let strip {
            if let pairing {
                if pairing.isBye {
                    line = EventLine(label: "\(strip.roundShort ?? pairing.roundTitle) · BYE", text: "Bye this round")
                } else if pairing.isComplete {
                    line = EventLine(label: tag ?? "", text: "Reported")
                } else {
                    line = nil
                }
            } else {
                let start = strip.startsAt.map { $0.formatted(date: .omitted, time: .shortened) } ?? "TODAY"
                line = EventLine(label: start, text: strip.eventName)
            }
        } else {
            line = nil
        }
        event = strip?.eventName
        webURL = strip?.webURL
    }

    /// A manual check's answer, short enough for the board's toast.
    static func checked(_ store: PlayRiftboundMatchStore) -> String {
        if store.lastError != nil { return "Couldn't reach PlayRiftbound" }
        guard let strip = store.current else { return "No live event · shows up to 3 h before yours" }
        guard let p = strip.pairing else { return "No pairing yet" }
        if p.isBye { return "Bye this round" }
        if p.isComplete { return "\(strip.roundShort ?? p.roundTitle) reported · next round not paired yet" }
        return "Table \(p.tableNumber.map(String.init) ?? "?") · vs \(p.opponentName ?? "?")"
    }
}

/// A series the scoreboard reported: its pairing, its games and the score sent ("2–1").
struct SentReport: Equatable {
    let tag: String
    let log: [PlayedGame]
    let score: String
}

struct ReportError: LocalizedError {
    let errorDescription: String?
    init(_ text: String) { errorDescription = text }
}

@MainActor
enum MatchReport {
    /// Sends the games' winners (`Seat.you`, `Seat.opponent`, `Seat.draw`) as the player's result and
    /// returns the score sent; throws with Riot's answer or why nothing was sent.
    static func send(_ link: TableLink, winners: [Int], browser: PlayRiftboundBrowser, store: PlayRiftboundMatchStore) async throws -> String {
        let api = PlayRiftboundAPI()
        guard let credentials = try await PlayRiftboundSession.validCredentials(refreshingVia: browser) else {
            throw PlayRiftboundError.notSignedIn
        }
        let notFound = ReportError("Couldn't find your match in the current round.")
        guard let gameName = credentials.gameName,
              let tournament = try await api.tournament(id: link.tournamentID, credentials: credentials),
              let playerID = tournament.playerID(gameName: gameName, tagLine: credentials.tagLine),
              let fresh = CompetePairing.resolve(in: tournament, playerID: playerID) else { throw notFound }
        if fresh.matchID != link.pairing.matchID || fresh.gameIDs != link.pairing.gameIDs {
            await store.refresh(browser: browser, force: true)
            throw ReportError("Your pairing changed. Open the event and check the games.")
        }
        if fresh.isComplete {
            await store.refresh(browser: browser, force: true)
            throw ReportError("Already reported on PlayRiftbound" + (fresh.scoreText.map { ": \($0)" } ?? "."))
        }
        guard let mine = fresh.myParticipantID, let theirs = fresh.opponentParticipantID else { throw notFound }
        let games = zip(fresh.gameIDs, winners).map { id, winner in
            switch winner {
            case Seat.you: return PlayRiftboundAPI.GameResult(gameId: id, draw: false, winnerParticipantId: mine)
            case Seat.opponent: return PlayRiftboundAPI.GameResult(gameId: id, draw: false, winnerParticipantId: theirs)
            default: return PlayRiftboundAPI.GameResult(gameId: id, draw: true, winnerParticipantId: nil)
            }
        }
        guard !games.isEmpty else { throw ReportError("No game to report yet.") }
        do {
            try await api.submitGameResults(tournamentID: link.tournamentID, games: games, credentials: credentials)
        } catch PlayRiftboundError.sessionExpired {
            // The site renews its token on a page load; once, then again.
            let renewed = try await PlayRiftboundSession.renewed(via: browser)
            try await api.submitGameResults(tournamentID: link.tournamentID, games: games, credentials: renewed)
        }
        await store.refresh(browser: browser, force: true)
        let sent = winners.prefix(games.count)
        return "\(sent.filter { $0 == Seat.you }.count)–\(sent.filter { $0 == Seat.opponent }.count)"
    }
}
