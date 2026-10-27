package pitopia.riftcount.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import pitopia.riftcount.score.PlayerColors

class ReflowTest {
    @Test
    fun `joins wrapped lines, keeps paragraphs and headings, drops rules of dashes`() {
        val license = "Copyright 2017 The Authors\n(https://example.org)\n\n-----\nSIL OPEN FONT LICENSE Version 1.1\n-----\n\n" +
            "PREAMBLE\nThe goals of the\nlicense are\n\nDEFINITIONS\n\"Font\" means this.\n"
        assertEquals(
            "Copyright 2017 The Authors (https://example.org)\n\nSIL OPEN FONT LICENSE Version 1.1\n\n" +
                "PREAMBLE\n\nThe goals of the license are\n\nDEFINITIONS\n\n\"Font\" means this.",
            reflow(license),
        )
    }

    @Test
    fun `every licence the acknowledgments open is bundled and reads as paragraphs`() {
        listOf("OFL_big_shoulders_display.txt", "OFL_barlow.txt", "Apache-2.0.txt").forEach { name ->
            val text = reflow(java.io.File("src/main/assets/licenses/$name").readText())
            assertTrue(name, text.split("\n\n").size > 5)
        }
        val apache = reflow(java.io.File("src/main/assets/licenses/Apache-2.0.txt").readText())
        assertTrue(apache.startsWith("Apache License Version 2.0, January 2004 http://www.apache.org/licenses/"))
    }
}

class PickColorTest {
    private val green = PlayerColors.RiftGreen
    private val violet = PlayerColors.RiftViolet
    private val red = PlayerColors.offered.first { it.name == "Pastel Red" }

    @Test
    fun `a free colour only changes that seat`() {
        assertEquals(listOf(violet, red), pickColor(listOf(violet, green), 1, red))
    }

    @Test
    fun `a colour another seat has swaps the two`() {
        assertEquals(listOf(green, violet), pickColor(listOf(violet, green), 1, violet))
        val four = listOf(violet, red, green, PlayerColors.offered[4])
        assertEquals(listOf(violet, green, red, PlayerColors.offered[4]), pickColor(four, 1, green))
    }
}

class SeatColorsTest {
    @Test
    fun `defaults never repeat a colour a seat picked`() {
        val green = PlayerColors.RiftGreen
        val seats = PlayerColors.resolve(listOf(null, green, null, null), 4)
        assertEquals(listOf("Rift Violet", "Rift Green", "Pastel Blue", "Pastel Yellow"), seats.map { it.name })
        assertEquals(listOf("Rift Violet", "Rift Green"), PlayerColors.resolve(listOf(null, null), 2).map { it.name })
    }
}
