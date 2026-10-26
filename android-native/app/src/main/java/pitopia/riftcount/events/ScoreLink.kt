package pitopia.riftcount.events

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import pitopia.riftcount.score.EventLine
import pitopia.riftcount.score.MatchInfo
import pitopia.riftcount.score.TableLink

/**
 * The scoreboard's view of the player's next event (iOS match strip): the pairing once the round is up, or a
 * line for the event before round 1, a bye or a reported round; [say] tells the result of a manual check and
 * of a report.
 */
fun EventsData.matchInfo(scope: CoroutineScope, say: (String) -> Unit, open: (TournamentEntry) -> Unit): MatchInfo {
    val s = strip
    val p = s?.pairing
    val tag = p?.let { it.roundShort + (it.tableNumber?.let { n -> " · T$n" } ?: "") }
    val round = s?.let { cached(it.entry.tournament.id) }?.rounds?.firstOrNull { it.id == p?.roundId }
    val link = if (s != null && p != null && tag != null && p.isReportable) {
        val id = s.entry.tournament.id
        TableLink(
            tag = tag,
            opponent = p.opponentName,
            roundEndsAt = round?.takeIf { r -> r.matches.any { !it.isComplete } }?.endsAt,
            report = { onDone -> ReportDialog(this, id, p, say, onDone) },
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
