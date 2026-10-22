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
    /** Asks Riot again (the end of a series, a new match): the pairing may be reported meanwhile or newer. */
    val refresh: () -> Unit,
    /** Winner of each game ([YOU], [OPPONENT], -1 for a draw); returns the score sent, throws with Riot's answer. */
    val report: suspend (List<Int>) -> String,
)

/** A series the scoreboard reported: its pairing, its games and the score sent ("2–1"). */
data class SentReport(val tag: String, val log: List<GameResult>, val score: String)
