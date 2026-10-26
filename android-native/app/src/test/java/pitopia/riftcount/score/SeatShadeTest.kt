package pitopia.riftcount.score

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import kotlin.math.abs
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import pitopia.riftcount.ui.theme.RiftColors

/** Colour model C on every player colour (iOS tools/check-scoreboard), as WCAG contrast. */
class SeatShadeTest {
    private fun contrast(a: Color, b: Color): Float {
        val x = a.luminance() + 0.05f
        val y = b.luminance() + 0.05f
        return maxOf(x, y) / minOf(x, y)
    }

    @Test
    fun `every player colour reads on the board`() {
        for (sw in PlayerColors.offered) {
            val field = SeatShade.deep(sw.color)
            val drawn = SeatShade.lift(sw.color)
            assertTrue("white on the ${sw.name} field", contrast(field, Color.White) >= 7f)
            assertTrue("white on a leading ${sw.name} seat", contrast(SeatShade.deep(sw.color, 1.125f), Color.White) >= 4.5f)
            assertTrue("${sw.name} on its field", contrast(drawn, field) >= 3.3f)
            assertTrue("Conquer's ink in ${sw.name}", contrast(SeatShade.deep(drawn, 0.75f), Color.White) >= 4.5f)
        }
    }

    @Test
    fun `the default colours stay and the shades match the plan`() {
        assertEquals(RiftColors.You, SeatShade.lift(RiftColors.You))
        assertEquals(RiftColors.Opponent, SeatShade.lift(RiftColors.Opponent))
        // The sheet the plan was checked with: Rift Green's field 0D6339, Pastel Blue lifted 9C9FFF.
        assertClose(Color(0xFF0D6339), SeatShade.deep(RiftColors.You))
        assertClose(Color(0xFF9C9FFF), SeatShade.lift(Color(0xFF4250FF)))
    }

    private fun assertClose(expected: Color, actual: Color) {
        val off = maxOf(abs(expected.red - actual.red), abs(expected.green - actual.green), abs(expected.blue - actual.blue))
        assertTrue("expected $expected, got $actual", off <= 1.5f / 255)
    }
}
