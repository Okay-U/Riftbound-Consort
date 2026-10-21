package pitopia.riftcount.data

import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class GamesTest {
    // A record as the iOS/Skip app writes it: Date as seconds since 2001, optional fields left out.
    private val swiftJson = """[{"id":"6C2D0F4E-1B7A-4C1F-9E2A-0D3B5A7C9E11","date":782659200.5,""" +
        """"deck_id":"A1B2C3D4-0000-4000-8000-000000000001","deck_name":"Noxus Legion","opponent":"Darius",""" +
        """"result":"won","duration_seconds":1846,"events":[{"id":"E1","elapsed_seconds":12,"slot":1,""" +
        """"type":"conquer","delta":1}]},{"id":"OLD","date":700000000,"opponent":"","result":"lost",""" +
        """"duration_seconds":600}]"""

    @Test
    fun `reads iOS records including old ones without events or deck`() {
        val dir = Files.createTempDirectory("docs").toFile()
        dir.resolve(GameRecordStore.FILE).writeText(swiftJson)
        val store = GameRecordStore(Documents(dir))
        assertEquals(2, store.records.size)
        val first = store.records[0]
        assertEquals((782_659_200.5 + 978_307_200) * 1000, first.date.toDouble(), 1.0)
        assertEquals("Noxus Legion", first.deckName)
        assertEquals(listOf("conquer"), first.events.map { it.type })
        assertTrue(store.records[1].events.isEmpty())
        assertEquals(null, store.records[1].startedFirst)
    }

    @Test
    fun `writes the Swift shape back`() {
        val dir = Files.createTempDirectory("docs").toFile()
        val store = GameRecordStore(Documents(dir))
        store.record(GameRecord(id = "X", date = (700_000_000L + 978_307_200L) * 1000, opponent = "Lee Sin", result = "lost", durationSeconds = 5))
        val text = dir.resolve(GameRecordStore.FILE).readText()
        assertTrue(text, text.contains("\"date\":7.0E8") || text.contains("\"date\":700000000"))
        assertTrue(text.contains("\"duration_seconds\":5"))
        assertTrue(text.contains("\"events\":[]"))
        assertTrue("nil fields stay out", !text.contains("deck_id"))
    }

    @Test
    fun `an unreadable file is kept aside instead of being overwritten`() {
        val dir = Files.createTempDirectory("docs").toFile()
        dir.resolve(GameRecordStore.FILE).writeText("{broken")
        val store = GameRecordStore(Documents(dir))
        assertTrue(store.records.isEmpty())
        assertEquals(1, dir.listFiles { f -> f.name.startsWith("games.unreadable-") }?.size)
    }
}
