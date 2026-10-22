package pitopia.riftcount.cards

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import pitopia.riftcount.data.DeckRules
import pitopia.riftcount.data.Decklist
import pitopia.riftcount.data.DecklistEntry

class DeckRulesTest {
    private val cards = Fixture.cards.associateBy { it.id }
    private val darius = Fixture.named("Darius - Hand of Noxus")
    private val trifarian = Fixture.named("Darius - Trifarian")
    private val trifarianAlt = Fixture.named("Darius - Trifarian (Alternate Art)")
    private val executioner = Fixture.named("Darius - Executioner")
    private val kinkou = Fixture.named("Kinkou Monk")
    private val furyRune = cards.getValue("ogn-007-298")

    private fun empty() = Decklist(name = "Test", createdAt = 0, updatedAt = 0)
    private fun Decklist.with(card: Card, times: Int = 1, pool: Map<String, Card> = cards) =
        (1..times).fold(this) { d, _ -> DeckRules.add(card, d, pool, nowMs = 1) }

    @Test
    fun `printings of a card share one identity`() {
        assertEquals("name:darius trifarian", DeckRules.identityKey(trifarian))
        assertEquals(DeckRules.identityKey(trifarian), DeckRules.identityKey(trifarianAlt))
    }

    @Test
    fun `a champion fills the chosen slot first, then the main deck, three copies in all`() {
        var d = empty().with(darius).with(trifarian)
        assertEquals(darius.id, d.legend?.cardId)
        assertEquals(trifarian.id, d.champion?.cardId)
        d = d.with(trifarianAlt).with(trifarian)
        assertEquals(2, d.mainDeck.sumOf { it.count })
        assertEquals(3, DeckRules.copies(d, trifarianAlt, cards))
        assertEquals("3 copies already", DeckRules.blocker(trifarianAlt, d, cards))
    }

    @Test
    fun `the legend's domains decide what fits, colourless always does, tokens never`() {
        val d = empty().with(darius)
        assertEquals("Outside the legend's domains", DeckRules.blocker(kinkou, d, cards))
        assertNull(DeckRules.blocker(executioner, d, cards))
        assertNull(DeckRules.blocker(kinkou, empty(), cards))
        val colourless = Fixture.named("Iron Ballista").copy(classification = Card.Classification(type = "Gear", domain = listOf("Colorless")))
        assertTrue(DeckRules.eligible(colourless, setOf("fury", "order")))
        assertFalse(DeckRules.eligible(Fixture.named("Buff"), setOf("fury", "order")))
    }

    @Test
    fun `battlefields, runes, signatures and the main deck have their limits`() {
        val battlefields = Fixture.cards.filter { it.isBattlefield }
        var d = battlefields.fold(empty()) { acc, c -> acc.with(c) }
        assertEquals(3, d.battlefields.size)
        assertEquals("Already a battlefield", DeckRules.blocker(battlefields[0], d, cards))
        d = d.with(furyRune, 12)
        assertEquals(12, d.runes.single().count)
        assertEquals("12 runes already", DeckRules.blocker(furyRune, d, cards))

        // No clean name: "Other" below must be a card of its own, not a copy of this one.
        val signature = Fixture.named("Blazing Scorcher").let { it.copy(id = "sig", metadata = null, classification = it.classification?.copy(supertype = "Signature")) }
        val pool = cards + ("sig" to signature) + ("other" to signature.copy(id = "other", name = "Other"))
        val signed = empty().copy(mainDeck = listOf(DecklistEntry("other", "Other", 3)))
        assertEquals("3 signature cards already", DeckRules.blocker(signature, signed, pool))

        val full = empty().copy(mainDeck = listOf(DecklistEntry("filler", "Filler", 39)))
        assertEquals("Main deck is full", DeckRules.blocker(Fixture.named("Cleave"), full, cards))
    }

    @Test
    fun `the legend's champion tag decides champions and signature cards, not a shared tag`() {
        fun card(name: String, type: String, supertype: String?, vararg tags: String) =
            Card(id = name, name = name, classification = Card.Classification(type = type, supertype = supertype), tags = tags.toList())
        val kennen = card("Kennen - Heart of the Tempest", "Legend", null, "Yordle", "Kennen")
        assertTrue(DeckRules.matchesLegend(card("Kennen - Thunder", "Unit", "Champion", "Yordle", "Kennen"), kennen))
        // Teemo is a Yordle too, but not Kennen.
        assertFalse(DeckRules.matchesLegend(card("Teemo - Scout", "Unit", "Champion", "Yordle", "Teemo"), kennen))
        val own = card("Lightning Rush - Kennen", "Spell", "Signature", "Kennen")
        val jinxs = card("Super Mega Death Rocket! - Jinx", "Spell", "Signature", "Jinx")
        assertTrue(DeckRules.signatureFits(own, kennen))
        assertFalse(DeckRules.signatureFits(jinxs, kennen))
        assertTrue(DeckRules.signatureFits(jinxs, null))
        // The signed printing of a legend is not a Signature card.
        assertFalse(kennen.copy(name = "Kennen - Heart of the Tempest (Signature)", metadata = Card.Metadata(signature = true)).isSignature)
    }

    @Test
    fun `a sideboard holds up to ten cards`() {
        fun side(n: Int) = empty().copy(sideDeck = if (n == 0) emptyList() else listOf(DecklistEntry("s", "S", n)))
        assertTrue(DeckRules.issues(side(8)).none { it.startsWith("Side deck") })
        assertTrue(DeckRules.issues(side(10)).none { it.startsWith("Side deck") })
        assertTrue("Side deck: 11 (max 10)" in DeckRules.issues(side(11)))
    }

    @Test
    fun `remove takes main deck copies before the chosen champion`() {
        var d = empty().with(darius).with(trifarian, 2)
        assertEquals(2, DeckRules.count(trifarian, d))
        d = DeckRules.remove(trifarian, d, nowMs = 2)
        assertTrue(d.mainDeck.isEmpty())
        assertEquals(trifarian.id, d.champion?.cardId)
        assertEquals(2L, d.updatedAt)
        assertEquals(d, DeckRules.remove(kinkou, d, nowMs = 3))
    }

    @Test
    fun `issues use the iOS wording`() {
        assertEquals(
            listOf("Missing champion", "Missing legend", "Battlefields: 0/3", "Main deck: 0/39", "Runes: 0/12"),
            DeckRules.issues(empty()),
        )
        val wrong = empty().with(darius).copy(mainDeck = listOf(DecklistEntry(kinkou.id, kinkou.name, 4)))
        val issues = DeckRules.issues(wrong, cards)
        assertTrue(issues.toString(), "Kinkou Monk: 4 copies (max 3)" in issues && "Kinkou Monk: outside Darius's domains" in issues)
    }
}
