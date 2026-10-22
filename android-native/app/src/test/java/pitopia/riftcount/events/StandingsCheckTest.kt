package pitopia.riftcount.events

import java.io.File
import kotlin.math.abs
import kotlin.math.max
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test

/**
 * [Standings] against Riot's official end-of-round tables of finished public events, the check iOS runs in
 * `tools/check-standings`. Needs the events on disk, so it only runs when `STANDINGS_DIR` names a folder of
 * `competeTournaments[0]` JSON files (`sh tools/check-standings/run.sh` downloads them and runs both).
 */
class StandingsCheckTest {
    @Test
    fun `computed standings match Riot's end-of-round tables`() {
        val dir = System.getenv("STANDINGS_DIR")?.let(::File)
        assumeTrue("STANDINGS_DIR not set", dir != null)
        val files = dir?.listFiles { f -> f.extension == "json" }.orEmpty()
        assertTrue("no tournaments in $dir", files.isNotEmpty())
        var rows = 0
        var worst = 0.0
        for (file in files) {
            val t = CompeteJson.decodeFromString(Tournament.serializer(), file.readText())
            for (round in t.rounds) {
                val riot = round.endOfRoundStandings.orEmpty()
                if (riot.isEmpty()) continue
                val where = "${file.name} R${round.number}"
                val table = Standings.compute(t, round.number)
                assertEquals("$where rows", riot.size, table.rows.size)
                assertTrue("$where pending", table.pending.isEmpty() && table.reportedMatches == table.totalMatches)
                val ours = table.rows.associateBy { it.esportsTeamId }
                val shared = table.rows.groupingBy { it.rank ?: 0 }.eachCount()
                for (official in riot) {
                    val mine = ours[official.esportsTeamId] ?: error("$where: ${official.esportsTeamId} missing")
                    assertEquals("$where points", official.matchPoints, mine.matchPoints)
                    assertEquals("$where record", official.record, mine.record)
                    listOf(
                        mine.opponentMatchWinPercentage to official.opponentMatchWinPercentage,
                        mine.gameWinPercentage to official.gameWinPercentage,
                        mine.opponentGameWinPercentage to official.opponentGameWinPercentage,
                    ).forEach { (a, b) -> worst = max(worst, abs((a ?: -1.0) - (b ?: -2.0))) }
                    // Outside a shared rank ours must be Riot's; inside, Riot's must fall in the shared block.
                    val r = mine.rank ?: 0
                    val size = shared[r] ?: 1
                    val theirs = official.rank ?: 0
                    if (size == 1) assertEquals("$where rank of ${official.esportsTeamId}", theirs, r)
                    else assertTrue("$where rank $theirs outside $r+$size", theirs in r until r + size)
                    rows++
                }
            }
            t.rounds.lastOrNull()?.let { last ->
                assertEquals("${file.name} last round matches", last.matches.count { it.teams.size == 2 }, Standings.compute(t, last.number).totalMatches)
            }
        }
        assertTrue("tiebreakers differ by $worst", worst < 1e-12)
        println("standings ok: $rows rows, max tiebreak diff $worst")
    }
}
