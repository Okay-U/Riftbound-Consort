package pitopia.riftcount.events

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import pitopia.riftcount.score.EventLine
import pitopia.riftcount.score.MatchInfo
import pitopia.riftcount.score.OPPONENT
import pitopia.riftcount.score.TableLink
import pitopia.riftcount.score.YOU

/**
 * The scoreboard's view of the player's next event (iOS match strip): the pairing once the round is up, or a
 * line for the event before round 1, a bye or a reported round; [say] tells the result of a manual check.
 */
fun EventsData.matchInfo(scope: CoroutineScope, say: (String) -> Unit, open: (TournamentEntry) -> Unit): MatchInfo {
    val s = strip
    val p = s?.pairing
    val tag = p?.let { it.roundShort + (it.tableNumber?.let { n -> " · T$n" } ?: "") }
    val round = s?.let { cached(it.entry.tournament.id) }?.rounds?.firstOrNull { it.id == p?.roundId }
    val link = if (s != null && p != null && tag != null && !p.isBye) {
        TableLink(
            tag = tag,
            table = p.tableNumber,
            opponent = p.opponentName,
            bestOf = p.bestOf,
            reportable = p.isReportable,
            reported = p.isComplete,
            roundEndsAt = round?.takeIf { r -> r.matches.any { !it.isComplete } }?.endsAt,
            refresh = { scope.launch { refreshStrip(force = true) } },
            report = { winners -> reportSeries(s.entry.tournament.id, p, winners) },
        )
    } else {
        null
    }
    val line = s?.let {
        when {
            p == null -> EventLine(it.entry.tournament.startsAt?.let(Fmt::time) ?: "TODAY", it.entry.tournament.name)
            p.isBye -> EventLine("${p.roundShort} · BYE", "Bye this round")
            p.isComplete -> EventLine(tag.orEmpty(), "Reported")
            else -> null
        }
    }
    return MatchInfo(link, line, s?.entry?.tournament?.name, { s?.let { open(it.entry) } }, stripRefreshing) {
        scope.launch {
            refreshStrip(force = true)
            say(checked())
        }
    }
}

/** A manual check's answer, short enough for the board's toast. */
private fun EventsData.checked(): String {
    if (stripError != null) return "Couldn't reach PlayRiftbound"
    val s = strip ?: return "No live event · shows up to 3 h before yours"
    val p = s.pairing ?: return "No pairing yet"
    return when {
        p.isBye -> "Bye this round"
        p.isComplete -> "${p.roundShort} reported · next round not paired yet"
        else -> "Table ${p.tableNumber ?: "?"} · vs ${p.opponentName ?: "?"}"
    }
}

/**
 * Sends the scoreboard's games as the player's result (the report dialog's rules): the pairing is fetched again
 * first, so a re-paired match is never reported; only the games played go, the series' own order.
 */
private suspend fun EventsData.reportSeries(tournamentId: String, shown: Pairing, winners: List<Int>): String {
    val t = tournament(tournamentId, force = true) ?: throw RiftError.BadResponse()
    val fresh = playerId(t)?.let { Pairing.latest(t, it) } ?: throw IllegalStateException("Couldn't find your match in the current round.")
    if (fresh.matchId != shown.matchId) {
        refreshStrip(force = true)
        throw IllegalStateException("Your pairing changed. Open the event and check the games.")
    }
    if (fresh.isComplete) {
        refreshStrip(force = true)
        throw IllegalStateException("Already reported on PlayRiftbound" + (fresh.scoreText?.let { ": $it" } ?: "."))
    }
    val mine = fresh.myParticipantId
    val theirs = fresh.opponentParticipantId
    if (mine == null || theirs == null) throw IllegalStateException("Couldn't find your match in the current round.")
    val games = fresh.gameIds.zip(winners).map { (id, w) ->
        when (w) {
            YOU -> RiftApi.GameResult(id, false, mine)
            OPPONENT -> RiftApi.GameResult(id, false, theirs)
            else -> RiftApi.GameResult(id, true, null)
        }
    }
    if (games.isEmpty()) throw IllegalStateException("No game to report yet.")
    val credentials = RiotSession.valid(browser) ?: throw RiftError.NotSignedIn()
    try {
        api.submitGameResults(tournamentId, games, credentials)
    } catch (_: RiftError.SessionExpired) {
        api.submitGameResults(tournamentId, games, RiotSession.renewed(browser))
    }
    refreshStrip(force = true)
    val me = winners.take(games.size).count { it == YOU }
    val them = winners.take(games.size).count { it == OPPONENT }
    return "$me–$them"
}
