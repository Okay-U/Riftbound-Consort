package pitopia.riftcount.score

import androidx.compose.runtime.Composable

/**
 * The player's PlayRiftbound pairing in match mode (iOS match strip), once the round is up and until it is
 * reported: the seam shows its round, table and opponent (the round clock once it runs) and a green Report
 * that opens the Events report dialog (Okay, 2026-10-26: no Start match, no best of 1 / 3 mode).
 */
class TableLink(
    /** "R3 · T5". */
    val tag: String,
    val opponent: String?,
    /** The round clock's end while the round runs, for the seam's countdown. */
    val roundEndsAt: Long?,
    /** The Events report dialog for this pairing; [onDone] closes it. */
    val report: @Composable (onDone: () -> Unit) -> Unit,
)

/** Match mode's PlayRiftbound for the scoreboard (iOS match strip); none with match mode off or four players. */
class MatchInfo(
    /** The pairing to play and report, once the round is up. */
    val link: TableLink?,
    /** What to say when there is nothing to play: the event before round 1, a bye, a reported round. */
    val line: EventLine?,
    /** The event's name while there is one; a tap on the seam's centre asks to open it. */
    val event: String?,
    val openEvent: () -> Unit,
    val checking: Boolean,
    /** Asks PlayRiftbound again (pairings go up between rounds) and says what came back. */
    val check: () -> Unit,
)

/** "18:30 · Summoner Skirmish", "R3 · BYE", "R3 · T5 · Reported". */
class EventLine(val label: String, val text: String)
