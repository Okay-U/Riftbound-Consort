package pitopia.riftcount.events

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import pitopia.riftcount.score.OPPONENT
import pitopia.riftcount.score.TableLink
import pitopia.riftcount.score.YOU

/** The scoreboard's view of the player's current pairing, or nil without one (no event, a bye, signed out). */
fun EventsData.tableLink(scope: CoroutineScope): TableLink? {
    val s = strip ?: return null
    val p = s.pairing?.takeIf { !it.isBye } ?: return null
    return TableLink(
        tag = p.roundShort + (p.tableNumber?.let { " · T$it" } ?: ""),
        reportable = p.isReportable,
        refresh = { scope.launch { refreshStrip(force = true) } },
        report = { winners -> reportSeries(s.entry.tournament.id, p, winners) },
    )
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
