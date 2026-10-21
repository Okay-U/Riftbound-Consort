package pitopia.riftcount.score

import kotlin.random.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DuelTest {
    @Test
    fun `the higher roll wins once both dice have landed`() {
        val d = DuelState.start(2).rolling(0).rolling(1).shown(0, 4, done = false)
        assertTrue(d.busy)
        val landed = d.shown(0, 7, done = true).shown(1, 15, done = true)
        assertEquals(YOU, landed.winner)
        assertFalse(landed.tie)
    }

    @Test
    fun `a tie rolls again and the winner may let the other start`() {
        val tie = DuelState.start(2).shown(0, 9, true).shown(1, 9, true)
        assertTrue(tie.tie)
        assertEquals(listOf(null, null), tie.rerolled().dice.map { it.value })
        val won = DuelState.start(2).shown(0, 12, true).shown(1, 3, true)
        assertEquals(OPPONENT, won.copy(choice = DuelState.Choice.First).starter())
        assertEquals(YOU, won.copy(choice = DuelState.Choice.Second).starter())
    }

    @Test
    fun `with four players the single highest starts`() {
        val d = (0..3).fold(DuelState.start(4, DieType.D6)) { acc, i -> acc.shown(i, listOf(2, 6, 5, 1)[i], true) }
        assertEquals(1, d.starter())
        val tied = (0..3).fold(DuelState.start(4, DieType.D6)) { acc, i -> acc.shown(i, listOf(6, 6, 5, 1)[i], true) }
        assertTrue(tied.tie)
    }

    @Test
    fun `tumbling faces slow down and never repeat the face before`() {
        val w = DuelState.tumbleWaits
        assertEquals(11, w.size)
        assertEquals(38L, w.first())
        assertTrue(w.zipWithNext().all { (a, b) -> b > a })
        val r = Random(7)
        repeat(200) { assertNotEquals(5, DuelState.face(6, 5, r)) }
    }
}
