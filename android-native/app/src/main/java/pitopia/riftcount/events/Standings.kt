package pitopia.riftcount.events

import kotlin.math.max
import kotlin.math.roundToLong
import pitopia.riftcount.events.Tournament.Standing

/**
 * Swiss standings computed on the device from every reported result (iOS `CompeteStandings`), so a player
 * sees the table during a round. Same rules as PlayRiftbound, verified by iOS against Riot's tables:
 * win 3, draw 1, loss 0; a bye is a 3-point win left out of MW% and GW%; MW% = max(0.33, points from played
 * matches / 3 × played); GW% = max(0.33, game wins / decided games); OMW% / OGW% = mean of the opponents';
 * order points, OMW%, GW%, OGW%.
 */
object Standings {
    /** PlayRiftbound's floor for every percentage (0.33, not one third). */
    const val FLOOR = 0.33

    class Table(
        val roundNumber: Int,
        /** Sorted; `rank` is shared inside exact ties. */
        val rows: List<Standing>,
        /** Teams whose match in [roundNumber] has no result yet. */
        val pending: Set<String>,
        val reportedMatches: Int,
        val totalMatches: Int,
    )

    private enum class Result { Win, Draw, Loss }

    private fun result(outcome: String?): Result {
        val o = outcome?.uppercase().orEmpty()
        return when {
            "WIN" in o -> Result.Win
            "TIE" in o || "DRAW" in o -> Result.Draw
            else -> Result.Loss
        }
    }

    /** After every reported result up to and including Swiss round [round]; top-cut rounds do not count. */
    fun compute(t: Tournament, round: Int): Table {
        val points = HashMap<String, Int>()
        val byePoints = HashMap<String, Int>()
        val wins = HashMap<String, Int>()
        val losses = HashMap<String, Int>()
        val draws = HashMap<String, Int>()
        val played = HashMap<String, Int>()
        val gameWins = HashMap<String, Int>()
        val gameLosses = HashMap<String, Int>()
        val opponents = HashMap<String, MutableList<String>>()
        val teams = LinkedHashSet<String>()
        val pending = HashSet<String>()
        var reported = 0
        var total = 0
        fun add(map: HashMap<String, Int>, id: String, n: Int) { map[id] = (map[id] ?: 0) + n }

        for (r in t.swissRounds.filter { it.number <= round }) {
            for (team in r.byeTeamIds.orEmpty()) {
                teams += team
                add(points, team, 3)
                add(byePoints, team, 3)
                add(wins, team, 1)
            }
            for (match in r.matches) {
                val ids = match.teams.map { it.esportsTeamId }
                teams += ids
                if (ids.size != 2) continue
                val isLive = r.number == round
                if (isLive) total++
                val outcomes = match.teamOutcomes.orEmpty().mapNotNull { o -> o.esportsTeamId?.let { it to o.outcome } }.toMap()
                if (outcomes.isEmpty()) {
                    if (isLive) pending += ids
                    continue
                }
                if (isLive) reported++
                opponents.getOrPut(ids[0]) { mutableListOf() } += ids[1]
                opponents.getOrPut(ids[1]) { mutableListOf() } += ids[0]
                for (id in ids) {
                    add(played, id, 1)
                    when (result(outcomes[id])) {
                        Result.Win -> { add(points, id, 3); add(wins, id, 1) }
                        Result.Draw -> { add(points, id, 1); add(draws, id, 1) }
                        Result.Loss -> add(losses, id, 1)
                    }
                }
                for (game in match.games.orEmpty()) {
                    for (o in game.teamOutcomes.orEmpty()) {
                        val id = o.esportsTeamId?.takeIf { it in ids } ?: continue
                        val value = o.outcome?.uppercase().orEmpty()
                        if ("WIN" in value) add(gameWins, id, 1) else if (value.startsWith("LOS")) add(gameLosses, id, 1)
                    }
                }
            }
        }

        fun matchWin(id: String): Double {
            val n = played[id] ?: 0
            if (n == 0) return FLOOR
            return max(FLOOR, ((points[id] ?: 0) - (byePoints[id] ?: 0)).toDouble() / (3 * n))
        }
        fun gameWin(id: String): Double {
            val w = gameWins[id] ?: 0
            val l = gameLosses[id] ?: 0
            if (w + l == 0) return FLOOR
            return max(FLOOR, w.toDouble() / (w + l))
        }
        fun mean(ids: List<String>, value: (String) -> Double): Double = if (ids.isEmpty()) FLOOR else ids.sumOf(value) / ids.size

        class Entry(val id: String, val pts: Int, val omw: Double, val gw: Double, val ogw: Double) {
            // Tiebreakers to nine decimals: averages carry float noise in the last bit.
            val key = listOf(pts.toLong(), q(omw), q(gw), q(ogw))
            private fun q(v: Double) = (v * 1e9).roundToLong()
        }
        val entries = teams.map { id ->
            val opps = opponents[id].orEmpty()
            Entry(id, points[id] ?: 0, mean(opps, ::matchWin), gameWin(id), mean(opps, ::gameWin))
        }
        // Inside exact ties keep the last official order, so rows do not jump around.
        val previous = t.swissRounds.lastOrNull { it.number < round && !it.endOfRoundStandings.isNullOrEmpty() }
        val previousRank = previous?.endOfRoundStandings.orEmpty().mapNotNull { s -> s.rank?.let { s.esportsTeamId to it } }.toMap()
        val byKey = Comparator<Entry> { a, b ->
            for (i in a.key.indices) if (a.key[i] != b.key[i]) return@Comparator b.key[i].compareTo(a.key[i])
            0
        }
        val sorted = entries.sortedWith(byKey.thenBy { previousRank[it.id] ?: Int.MAX_VALUE }.thenBy { it.id })
        var rank = 0
        val rows = sorted.mapIndexed { i, e ->
            if (i == 0 || sorted[i - 1].key != e.key) rank = i + 1
            Standing(
                esportsTeamId = e.id, rank = rank, matchPoints = e.pts,
                matchWins = wins[e.id] ?: 0, matchLosses = losses[e.id] ?: 0, matchDraws = draws[e.id] ?: 0,
                matchWinPercentage = matchWin(e.id), opponentMatchWinPercentage = e.omw,
                gameWinPercentage = e.gw, opponentGameWinPercentage = e.ogw,
            )
        }
        return Table(round, rows, pending, reported, total)
    }
}

enum class CutChance(val label: String) { Locked("Locked in"), Bubble("Bubble"), Out("Out") }

/** A rival in the top-cut race: points so far and matches still to play (0 once dropped). */
data class Contender(val points: Int, val remaining: Int)

/**
 * "Can I draw into top cut?" (iOS `DrawCalc`). Conservative: it ignores pairing constraints, so "locked"
 * is a true guarantee.
 */
object DrawCalc {
    fun chance(myPoints: Int, myRemaining: Int, others: List<Contender>, cut: Int, perRound: Int): CutChance {
        if (cut <= 0 || myRemaining < 1) return CutChance.Bubble
        val myFinal = myPoints + perRound * myRemaining
        // Always strictly above me, even if they lose every remaining match.
        if (others.count { it.points > myFinal } >= cut) return CutChance.Out
        // Could finish at or above me if they win enough.
        if (others.count { it.points + 3 * it.remaining >= myFinal } < cut) return CutChance.Locked
        return CutChance.Bubble
    }

    /** Win, draw and lose out. */
    fun outlook(myPoints: Int, myRemaining: Int, others: List<Contender>, cut: Int): List<CutChance> =
        listOf(3, 1, 0).map { chance(myPoints, myRemaining, others, cut, it) }
}
