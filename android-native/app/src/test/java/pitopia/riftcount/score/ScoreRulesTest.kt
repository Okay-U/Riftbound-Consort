package pitopia.riftcount.score

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ScoreRulesTest {
    private val t0 = 1_000_000L

    private fun ScoreState.points(slot: Int, n: Int, kind: PointKind = PointKind.Hold, at: Long = t0): ScoreState =
        (1..n).fold(this) { s, _ -> s.score(slot, kind, at) }

    @Test
    fun `points are recorded as iOS events and never go below zero`() {
        val s = ScoreState().score(YOU, PointKind.Conquer, t0).score(YOU, PointKind.Effect, t0).fix(OPPONENT, t0)
        assertEquals(listOf(0, 2), s.players.map { it.score })
        assertEquals(listOf("conquer" to 1, "manual" to 1), s.events.map { it.type to it.delta })
        assertEquals(2, s.history.size) // the no-op fix on 0 pushed nothing
    }

    @Test
    fun `the eighth point by conquering is asked for, hold wins directly`() {
        val atSeven = ScoreState().points(YOU, 7)
        val asked = atSeven.score(YOU, PointKind.Conquer, t0)
        assertEquals(YOU, asked.asking)
        assertEquals(7, asked.players[YOU].score)
        val declined = asked.confirmFinalPoint(scoreIt = false, nowMs = t0)
        assertEquals(-1, declined.asking)
        assertEquals(7, declined.players[YOU].score)
        val won = asked.confirmFinalPoint(scoreIt = true, nowMs = t0)
        assertEquals(YOU, won.winner)
        assertEquals(listOf(GameResult(YOU, listOf(0, 8))), won.log)
        assertEquals(YOU, atSeven.score(YOU, PointKind.Hold, t0).winner)
    }

    @Test
    fun `a won game blocks points and undo until the next game`() {
        val won = ScoreState().points(OPPONENT, 3).points(YOU, 8)
        assertTrue(won.gameOver)
        assertFalse(won.canUndo)
        assertEquals(won, won.score(OPPONENT, PointKind.Hold, t0))
        assertEquals(won, won.undo())
        assertEquals(won, won.restart())
        val next = won.nextGame(t0)
        assertEquals(2, next.gameNo)
        assertEquals(listOf(0, 0), next.players.map { it.score })
        assertEquals(listOf(0, 1), next.seriesWins())
        assertFalse(next.gameOver)
    }

    @Test
    fun `two won games end the best of three, a new match resets everything`() {
        val over = ScoreState().points(YOU, 8).nextGame(t0).points(OPPONENT, 8).nextGame(t0).points(YOU, 8)
        assertTrue(over.matchOver)
        assertEquals(over, over.nextGame(t0))
        val fresh = over.newMatch()
        assertEquals(ScoreState(), fresh)
    }

    @Test
    fun `undo walks back points and XP, at most fifty steps`() {
        val s = ScoreState().points(YOU, 2).xp(YOU, 1).xp(YOU, 1)
        assertEquals(2, s.players[YOU].xp)
        val back = s.undo().undo()
        assertEquals(0, back.players[YOU].xp)
        assertEquals(2, back.players[YOU].score)
        val many = (1..60).fold(ScoreState()) { acc, _ -> acc.xp(YOU, 1) }
        assertEquals(50, many.history.size)
    }

    @Test
    fun `restart zeroes the game and can be undone`() {
        val s = ScoreState().points(YOU, 5).xp(OPPONENT, 3).restart()
        assertEquals(listOf(0, 0), s.players.map { it.score })
        assertEquals(listOf(0, 0), s.players.map { it.xp })
        assertTrue(s.events.isEmpty())
        val undone = s.undo()
        assertEquals(5, undone.players[YOU].score)
        assertEquals(3, undone.players[OPPONENT].xp)
    }

    @Test
    fun `four players have no target and no conquer question`() {
        val s = ScoreState().withPlayerCount(4).points(2, 9, PointKind.Conquer)
        assertEquals(9, s.players[2].score)
        assertEquals(-1, s.winner)
        assertEquals(-1, s.asking)
    }

    @Test
    fun `the match clock starts on the first point, pauses, and times each game`() {
        val first = ScoreState().score(YOU, PointKind.Hold, t0)
        assertTrue(first.clock.isRunning)
        val paused = first.toggleClock(t0 + 90_000)
        assertEquals(90, paused.clock.elapsedSeconds(t0 + 500_000))
        val resumed = paused.toggleClock(t0 + 500_000)
        assertEquals(100, resumed.clock.elapsedSeconds(t0 + 510_000))
        val won = resumed.points(YOU, 7, at = t0 + 600_000)
        assertEquals(190, won.gameSeconds(t0 + 600_000))
        val next = won.nextGame(t0 + 600_000)
        assertTrue(next.clock.isRunning)
        assertEquals(60, next.points(OPPONENT, 8, at = t0 + 660_000).gameSeconds(t0 + 660_000))
    }

    @Test
    fun `clock text is minutes and seconds`() {
        assertEquals("00:00", clockText(0))
        assertEquals("51:09", clockText(3069))
    }
}
