package pitopia.riftcount.decks

import pitopia.riftcount.data.GameRecord
import pitopia.riftcount.score.OPPONENT
import pitopia.riftcount.score.YOU

/** Wins and losses of a set of games. */
data class Tally(val wins: Int, val losses: Int) {
    val games: Int get() = wins + losses
    val rate: Double get() = if (games == 0) 0.0 else wins.toDouble() / games
    val text: String get() = "$wins–$losses"

    companion object {
        fun of(games: List<GameRecord>) = Tally(games.count { it.won }, games.count { !it.won })
    }
}

val GameRecord.won: Boolean get() = result == "won"

/** One scoring step of a game for the review: who, what, and the score after it. */
data class Point(val seconds: Int, val slot: Int, val kind: String, val delta: Int, val you: Int, val them: Int)

/** The match log's numbers, iOS `GameHistoryView` summary plus the mock's race to 8. */
object MatchLog {
    fun firstSecond(games: List<GameRecord>) =
        Tally.of(games.filter { it.startedFirst == true }) to Tally.of(games.filter { it.startedFirst == false })

    fun averageMinutes(games: List<GameRecord>): Int? =
        games.takeIf { it.isNotEmpty() }?.let { g -> Math.round(g.sumOf { it.durationSeconds } / 60.0 / g.size).toInt() }

    /** The 2-player events in order with the running score (never below 0, like iOS); empty for 4 players. */
    fun points(g: GameRecord): List<Point> {
        if (g.events.any { it.slot > YOU }) return emptyList()
        var you = 0
        var them = 0
        return g.events.sortedBy { it.elapsedSeconds }.map { e ->
            if (e.slot == YOU) you = (you + e.delta).coerceAtLeast(0) else them = (them + e.delta).coerceAtLeast(0)
            Point(e.elapsedSeconds, e.slot, e.type, e.delta, you, them)
        }
    }

    /** Final score "8–5", null when the game was saved without a point log. */
    fun score(g: GameRecord): Pair<Int, Int>? = points(g).lastOrNull()?.let { it.you to it.them }

    /** Each lane's points in the order they were scored; a Fix −1 takes the last one back. */
    fun race(g: GameRecord): Map<Int, List<String>> {
        val lanes = mutableMapOf(YOU to mutableListOf<String>(), OPPONENT to mutableListOf())
        points(g).forEach { p ->
            val lane = lanes.getValue(p.slot)
            repeat(kotlin.math.abs(p.delta)) { if (p.delta > 0) lane += p.kind else lane.removeLastOrNull() }
        }
        return lanes
    }

    fun clock(seconds: Int) = "%d:%02d".format(seconds / 60, seconds % 60)
}
