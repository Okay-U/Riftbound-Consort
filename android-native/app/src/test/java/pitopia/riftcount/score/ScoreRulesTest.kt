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
        assertEquals(listOf(0, 0), next.players.map { it.score })
        assertFalse(next.gameOver)
        assertTrue(next.history.isEmpty())
        assertEquals(ScoreState(), ScoreState().nextGame(t0)) // no next game while playing
    }

    @Test
    fun `won or lost by hand ends the game as it stands`() {
        val playing = ScoreState().points(YOU, 5).points(OPPONENT, 3, PointKind.Conquer)
        val conceded = playing.end(YOU)
        assertEquals(YOU, conceded.winner)
        assertEquals(listOf(3, 5), conceded.players.map { it.score })
        assertEquals(OPPONENT, playing.end(OPPONENT).winner)
        assertEquals(conceded, conceded.end(OPPONENT)) // decided once
        assertEquals(OPPONENT, conceded.nextGame(t0).chooser) // the loser picks who starts next
        val asked = ScoreState().points(YOU, 7).score(YOU, PointKind.Conquer, t0)
        assertEquals(-1, asked.end(YOU).asking)
        val four = ScoreState().withPlayerCount(4)
        assertEquals(four, four.end(2)) // four players have no winner
        assertEquals(playing, playing.end(5))
    }

    @Test
    fun `the last game's loser picks who starts the next one`() {
        val next = ScoreState().points(OPPONENT, 8).nextGame(t0)
        assertEquals(YOU, next.chooser)
        assertEquals(-1, next.withStarter(OPPONENT, t0).chooser)
        assertEquals(-1, next.points(OPPONENT, 1).chooser) // playing on without picking closes the question
        assertEquals(-1, ScoreState().chooser)
        // Asked right after the game, not when the board is opened again much later (or from a state saved before).
        assertEquals(YOU, next.startChooser(t0 + 60_000))
        assertEquals(-1, next.startChooser(t0 + START_CHOICE_MS))
        assertEquals(-1, next.copy(chooserSinceMs = 0).startChooser(t0))
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
    fun `the clock starts on the first point and times each game`() {
        val first = ScoreState().score(YOU, PointKind.Hold, t0)
        assertTrue(first.clock.isRunning)
        val won = first.points(YOU, 7, at = t0 + 190_000)
        assertEquals(190, won.gameSeconds(t0 + 190_000))
        val next = won.nextGame(t0 + 600_000)
        assertTrue(next.clock.isRunning)
        // Every game counts from its own first point: the minute before it (or a day) is not its time.
        val started = next.points(OPPONENT, 1, at = t0 + 660_000)
        assertEquals(0, started.events.single().elapsedSeconds)
        assertEquals(60, started.points(OPPONENT, 7, at = t0 + 720_000).gameSeconds(t0 + 720_000))
        // A game ended by hand before its first point counts from the end of the last one.
        assertEquals(30, next.end(YOU).gameSeconds(t0 + 630_000))
    }

    @Test
    fun `clock text is minutes and seconds`() {
        assertEquals("00:00", clockText(0))
        assertEquals("51:09", clockText(3069))
    }
}
