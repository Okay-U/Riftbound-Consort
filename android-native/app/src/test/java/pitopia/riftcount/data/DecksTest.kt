package pitopia.riftcount.data

import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DecksTest {
    // A deck as iOS/Skip writes it: camelCase deck keys, snake_case entries, Date as seconds since 2001, nil left out.
    private val swiftJson = """[{"id":"A1B2C3D4-0000-4000-8000-000000000001","name":"Noxus Legion","createdAt":782659200.25,""" +
        """"updatedAt":782660000,"legend":{"card_id":"ogn-253-298","card_name":"Darius - Hand of Noxus","count":1},""" +
        """"battlefields":[{"card_id":"ogn-275-298","card_name":"Altar to Unity","count":1}],""" +
        """"mainDeck":[{"card_id":"ogn-027-298","card_name":"Darius - Trifarian","count":2}],"sideDeck":[],""" +
        """"runes":[{"card_id":"ogn-007-298","card_name":"Fury Rune","count":6}]}]"""

    @Test
    fun `reads iOS decks and writes the same shape back`() {
        val dir = Files.createTempDirectory("docs").toFile()
        dir.resolve(DecklistStore.FILE).writeText(swiftJson)
        val store = DecklistStore(Documents(dir))
        val deck = store.lists.single()
        assertEquals("Noxus Legion", deck.name)
        assertEquals((782_659_200.25 + 978_307_200) * 1000, deck.createdAt.toDouble(), 1.0)
        assertNull(deck.champion)
        assertEquals("ogn-253-298", deck.legend?.cardId)
        assertEquals(6, deck.runes.single().count)

        store.replace(deck.copy(name = "Renamed"))
        val text = dir.resolve(DecklistStore.FILE).readText()
        assertTrue(text, text.contains("\"mainDeck\":[{\"card_id\":\"ogn-027-298\",\"card_name\":\"Darius - Trifarian\",\"count\":2}]"))
        assertTrue("nil champion stays out", !text.contains("champion"))
        assertEquals("Renamed", DecklistStore(Documents(dir)).lists.single().name)
    }

    @Test
    fun `create and delete save at once`() {
        val dir = Files.createTempDirectory("docs").toFile()
        val store = DecklistStore(Documents(dir))
        val deck = store.create("Void Tempo", nowMs = 1_000_000)
        assertEquals(deck.id.uppercase(), deck.id)
        assertEquals(listOf("Void Tempo"), DecklistStore(Documents(dir)).lists.map { it.name })
        store.delete(deck.id)
        assertTrue(DecklistStore(Documents(dir)).lists.isEmpty())
    }
}
