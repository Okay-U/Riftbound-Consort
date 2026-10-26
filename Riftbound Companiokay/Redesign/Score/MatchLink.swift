//
//  MatchLink.swift
//  Riftbound Companiokay
//
//  Match mode for the redesign's scoreboard (Android `TableLink.kt`, `ScoreLink.kt`): what the seam shows
//  of the player's next PlayRiftbound event. Its Report opens the Events report sheet for the pairing.
//

import Foundation

/// The pairing to play and report, once the round is up and until it is reported.
struct TableLink: Equatable {
    /// "R3 · T5".
    let tag: String
    let opponent: String?
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
    /// The event's id: "Open the event?" shows its native screen in Events.
    let tournamentID: String?

    init(strip: PlayRiftboundStrip?) {
        let pairing = strip?.pairing
        let tag = pairing.map { p in (strip?.roundShort ?? p.roundTitle) + (p.tableNumber.map { " · T\($0)" } ?? "") }
        if let strip, let pairing, let tag, pairing.isReportable {
            link = TableLink(tag: tag, opponent: pairing.opponentName, roundEndsAt: strip.roundEndsAt, tournamentID: strip.tournamentID, pairing: pairing)
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
        tournamentID = strip?.tournamentID
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
