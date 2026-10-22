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
        val won = ScoreState(bestOf = 3).points(OPPONENT, 3).points(YOU, 8)
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
        val over = ScoreState(bestOf = 3).points(YOU, 8).nextGame(t0).points(OPPONENT, 8).nextGame(t0).points(YOU, 8)
        assertTrue(over.matchOver)
        assertEquals(over, over.nextGame(t0))
        assertEquals(ScoreState(), over.newMatch())
    }

    @Test
    fun `casual games stand alone and never end a match`() {
        val won = ScoreState().points(YOU, 8)
        assertTrue(won.gameOver)
        assertFalse(won.matchOver)
        val next = won.nextGame(t0)
        assertEquals(2, next.gameNo)
        assertEquals(emptyList<GameResult>(), next.log)
        assertFalse(next.points(YOU, 8).nextGame(t0).points(YOU, 8).matchOver)
    }

    @Test
    fun `a best of one ends with its game`() {
        val over = ScoreState(bestOf = 1).points(OPPONENT, 8)
        assertTrue(over.matchOver)
        assertEquals(1, over.winsNeeded)
    }

    @Test
    fun `a series exists only for a live match, casual cannot become one`() {
        val playing = ScoreState().points(YOU, 3)
        assertEquals(playing, playing.withBestOf(3))
    }

    @Test
    fun `a live match starts in the event's format and can switch between one and three games`() {
        val rolled = ScoreState().points(YOU, 2).withStarter(OPPONENT, t0)
        val live = rolled.startLive("R3 · T5", bestOf = 1)
        assertEquals(1, live.bestOf)
        assertEquals("R3 · T5", live.liveTag)
        assertEquals(listOf(0, 0), live.players.map { it.score })
        assertEquals(OPPONENT, live.starter) // who goes first was rolled before
        // The table plays best of three although the event says one: game 1 no longer ends the match.
        val wonFirst = live.points(YOU, 8)
        assertTrue(wonFirst.matchOver)
        assertFalse(wonFirst.withBestOf(3).matchOver)
        assertEquals(3, live.startLive("R3 · T5", bestOf = 3).bestOf)
        // After a live match the next one is casual again.
        assertEquals(ScoreState(), wonFirst.newMatch())
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
        // A casual game counts from its own first point: the minute before it (or a day) is not its time.
        val started = next.points(OPPONENT, 1, at = t0 + 660_000)
        assertEquals(0, started.events.single().elapsedSeconds)
        assertEquals(60, started.points(OPPONENT, 7, at = t0 + 720_000).gameSeconds(t0 + 720_000))
        // A live match keeps one clock: its next game counts from the end of the last one.
        val live = ScoreState(bestOf = 3).points(YOU, 8, at = t0 + 60_000).nextGame(t0 + 60_000)
        assertEquals(120, live.points(OPPONENT, 8, at = t0 + 180_000).gameSeconds(t0 + 180_000))
    }

    @Test
    fun `clock text is minutes and seconds`() {
        assertEquals("00:00", clockText(0))
        assertEquals("51:09", clockText(3069))
    }
}
