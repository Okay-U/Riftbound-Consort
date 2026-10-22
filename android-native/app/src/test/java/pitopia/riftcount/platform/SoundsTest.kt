package pitopia.riftcount.platform

import kotlin.math.abs
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SoundsTest {
    @Test
    fun `clicks are short, soft and start silent`() {
        val tick = Sounds.pcm(Haptic.Tick)
        assertEquals(44_100 * 22 / 1000, tick.size)
        assertEquals(0, tick[0].toInt())
        val peak = tick.maxOf { abs(it.toInt()) }
        assertTrue("peak $peak", peak in 1_000..(0.22 * Short.MAX_VALUE).toInt())
        // The win is two notes, the longest sound.
        assertEquals(44_100 * 70 / 1000 + 44_100 * 120 / 1000, Sounds.pcm(Haptic.Success).size)
    }
}
