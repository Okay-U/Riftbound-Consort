package pitopia.riftcount.score

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ResultPickerTest {
    private val empty = ResultPicker(ending = true, picks = listOf(null, null, null), need = 2)

    @Test
    fun `games unlock in order and lock again after the deciding game`() {
        assertFalse(empty.locked(0))
        assertTrue(empty.locked(1))
        val twoWins = empty.choose(0, YOU).choose(1, YOU)
        assertEquals(1, twoWins.decidedAt())
        assertTrue(twoWins.locked(2))
        val split = empty.choose(0, YOU).choose(1, OPPONENT)
        assertEquals(-1, split.decidedAt())
        assertFalse(split.locked(2))
    }

    @Test
    fun `changing a game clears the games after it, tapping again clears it`() {
        val full = empty.choose(0, YOU).choose(1, OPPONENT).choose(2, -1)
        assertEquals(listOf(OPPONENT, null, null), full.choose(0, OPPONENT).picks)
        assertEquals(listOf(YOU, YOU, null), full.choose(1, YOU).picks)
        assertEquals(listOf(null, null, null), empty.choose(0, YOU).choose(0, YOU).picks)
    }

    @Test
    fun `one game decides a best of one or a casual game`() {
        val one = ResultPicker(ending = true, picks = listOf(null), need = 1)
        assertEquals(-1, one.decidedAt())
        assertEquals(0, one.choose(0, OPPONENT).decidedAt())
    }
}
