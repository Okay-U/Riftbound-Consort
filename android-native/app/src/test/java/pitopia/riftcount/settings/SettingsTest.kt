package pitopia.riftcount.settings

import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import pitopia.riftcount.score.PlayerColors

class PlayRiftboundLogTest {
    // As iOS `PlayRiftboundDiagnostics` writes it: oldest first, Date as seconds since 2001, nil detail left out.
    private val swiftJson = """[{"id":"A","date":782659200,"operation":"PlayerEvents","method":"GET","outcome":"ok","durationMs":231},""" +
        """{"id":"B","date":782659260.5,"operation":"ReportMatchResult","method":"POST","outcome":"http 409",""" +
        """"detail":"Round already finalised","durationMs":812}]"""

    @Test
    fun `reads the iOS log newest first`() {
        val file = Files.createTempFile("log", ".json").toFile().apply { writeText(swiftJson) }
        val entries = PlayRiftboundLog(file).entries()
        assertEquals(listOf("B", "A"), entries.map { it.id })
        assertEquals((782_659_260.5 + 978_307_200) * 1000, entries[0].date.toDouble(), 1.0)
        assertFalse(entries[0].ok)
        assertTrue(entries[1].ok)
    }

    @Test
    fun `a missing or broken file is an empty log`() {
        val dir = Files.createTempDirectory("docs").toFile()
        assertTrue(PlayRiftboundLog(dir.resolve(PlayRiftboundLog.FILE)).entries().isEmpty())
        val broken = dir.resolve("broken.json").apply { writeText("{") }
        assertTrue(PlayRiftboundLog(broken).entries().isEmpty())
    }

    @Test
    fun `export has the iOS header and one line per call with its detail`() {
        val file = Files.createTempFile("log", ".json").toFile().apply { writeText(swiftJson) }
        val text = PlayRiftboundLog.export(PlayRiftboundLog(file).entries(), "3.5.0 (10)")
        val lines = text.lines()
        assertEquals("Riftcount PlayRiftbound log · 2 entries · app 3.5.0 (10)", lines[0])
        assertTrue(lines[1], lines[1].endsWith("POST ReportMatchResult → http 409 (812 ms)"))
        assertEquals("    Round already finalised", lines[2])
        assertTrue(lines[3], lines[3].endsWith("GET PlayerEvents → ok (231 ms)"))
    }
}

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
