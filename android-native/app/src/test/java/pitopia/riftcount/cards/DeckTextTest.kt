package pitopia.riftcount.cards

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import pitopia.riftcount.data.DeckText
import pitopia.riftcount.data.Decklist
import pitopia.riftcount.data.DecklistEntry
import pitopia.riftcount.data.LegacyIds

class DeckTextTest {
    private val pool = Fixture.cards
    private val cards = pool.associateBy { it.id }

    private val deck = Decklist(
        name = "Noxus", createdAt = 0, updatedAt = 0,
        legend = DecklistEntry("ogn-253-298", "Darius - Hand of Noxus", 1),
        champion = DecklistEntry("ogn-027-298", "Darius - Trifarian", 1),
        battlefields = listOf(DecklistEntry("ogn-275-298", "Altar to Unity", 1), DecklistEntry("ogn-276-298", "Aspirant's Climb", 1)),
        mainDeck = listOf(
            DecklistEntry("ogn-027-298", "Darius - Trifarian", 1),
            DecklistEntry("ogn-027a-298", "Darius - Trifarian (Alternate Art)", 1),
            DecklistEntry("ogn-004-298", "Cleave", 3),
        ),
        runes = listOf(DecklistEntry("ogn-007-298", "Fury Rune", 6)),
    )

    @Test
    fun `export writes the deckbuilder format, printings in one line`() {
        val text = DeckText.export(deck, cards)
        assertEquals(
            """
            Legend:
            1 Darius, Hand of Noxus

            Champion:
            1 Darius, Trifarian

            MainDeck:
            2 Darius, Trifarian
            3 Cleave

            Battlefields:
            1 Altar to Unity
            1 Aspirant's Climb

            Runes:
            6 Fury Rune
            """.trimIndent(),
            text,
        )
    }

    @Test
    fun `parse reads its own export and the usual variants`() {
        val parsed = DeckText.parse(DeckText.export(deck, cards) + "\n\nSideboard:\n2x Get Excited!\n1 Not A Card\nwhat", pool)
        assertEquals("ogn-253-298", parsed.legend?.id)
        assertEquals("ogn-027-298", parsed.champion?.id)
        assertEquals(listOf("ogn-275-298", "ogn-276-298"), parsed.battlefields.map { it.id })
        assertEquals(listOf("ogn-027-298" to 2, "ogn-004-298" to 3), parsed.mainDeck.map { it.first.id to it.second })
        assertEquals(listOf("ogn-008-298" to 2), parsed.sideDeck.map { it.first.id to it.second })
        assertEquals(mapOf("fury" to 6), parsed.runeCounts)
        assertEquals(listOf("1 Not A Card", "what"), parsed.unresolved)

        val imported = DeckText.toDeck(parsed, "Imported", pool, nowMs = 5)
        assertEquals(2, imported.mainDeck.first { it.cardId == "ogn-027-298" }.count)
        // iOS `runeCard`: the lowest collector number, here the Radiance printing.
        assertEquals("rad-r01", imported.runes.single().cardId)
    }

    @Test
    fun `nothing to read stays empty`() {
        val parsed = DeckText.parse("hello\nworld", pool)
        assertTrue(parsed.isEmpty)
        assertNull(parsed.legend)
    }

    @Test
    fun `riftcodex ids move to the feed by riftbound id, name or set`() {
        val legacyDarius = cards.getValue("ogn-027-298").copy(id = "69c4407c9288b1e85d94de8a")
        val legacyCleave = cards.getValue("ogn-004-298").copy(id = "aaa", riftboundId = null)
        val promoRune = cards.getValue("ogn-007-298").copy(id = "promo", riftboundId = "opp-007b-298", set = Card.CardSet("OPP", "Promo"))
        val old = deck.copy(
            mainDeck = listOf(DecklistEntry("69c4407c9288b1e85d94de8a", "Darius - Trifarian", 2), DecklistEntry("aaa", "Cleave", 3)),
            sideDeck = listOf(DecklistEntry("gone", "No Such Card", 1)),
            runes = listOf(DecklistEntry("promo", "Fury Rune", 6)),
        )
        val result = LegacyIds.remap(listOf(old), pool, listOf(legacyDarius, legacyCleave, promoRune))
        assertTrue(result.changed)
        assertEquals(1, result.unresolved)
        assertEquals(listOf("ogn-027-298" to 2, "ogn-004-298" to 3), result.lists.single().mainDeck.map { it.cardId to it.count })
        assertEquals("gone", result.lists.single().sideDeck.single().cardId)
        assertEquals("rad-r01" to 6, result.lists.single().runes.single().let { it.cardId to it.count })
    }
}
