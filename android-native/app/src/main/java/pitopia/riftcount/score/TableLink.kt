package pitopia.riftcount.score

/**
 * The player's PlayRiftbound pairing in match mode (iOS match strip). Until its match is started the seam
 * shows the table and opponent with Start match; then the round and table instead of the game, End becomes
 * Report, and the match summary sends the series to Riot.
 */
class TableLink(
    /** "R3 · T5". */
    val tag: String,
    val table: Int?,
    val opponent: String?,
    /** The event's format, 1 or 3 games. */
    val bestOf: Int,
    val reportable: Boolean,
    /** Riot has a result for the match (from this phone or another). */
    val reported: Boolean,
    /** The round clock's end while the round runs, for the seam's countdown. */
    val roundEndsAt: Long?,
    /** Asks Riot again (the end of a series, a new match): the pairing may be reported meanwhile or newer. */
    val refresh: () -> Unit,
    /** Winner of each game ([YOU], [OPPONENT], -1 for a draw); returns the score sent, throws with Riot's answer. */
    val report: suspend (List<Int>) -> String,
)

/** A series the scoreboard reported: its pairing, its games and the score sent ("2–1"). */
data class SentReport(val tag: String, val log: List<GameResult>, val score: String)

/** Match mode's PlayRiftbound for the scoreboard (iOS match strip); none with match mode off or four players. */
class MatchInfo(
    /** The pairing to play and report, once the round is up. */
    val link: TableLink?,
    /** What to say when there is nothing to play: the event before round 1, a bye, a reported round. */
    val line: EventLine?,
    val checking: Boolean,
    /** Asks PlayRiftbound again (pairings go up between rounds) and says what came back. */
    val check: () -> Unit,
)

/** "18:30 · Summoner Skirmish", "R3 · BYE", "R3 · T5 · Reported"; a tap asks, then opens [event]. */
class EventLine(val label: String, val text: String, val event: String, val open: () -> Unit)
