package pitopia.riftcount.cards

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import pitopia.riftcount.data.SwiftJson

/** Real cards from the feed (39 printings, see src/test/resources/cards_fixture.json). */
object Fixture {
    val cards: List<Card> by lazy {
        val text = Fixture::class.java.getResource("/cards_fixture.json")!!.readText()
        SwiftJson.decodeFromString(CardPage.serializer(), text).items
    }
    fun named(name: String) = cards.first { it.name == name }
}

class CardQueryTest {
    private val all = Fixture.cards

    @Test
    fun `the feed decodes with its extra fields`() {
        assertEquals(39, all.size)
        val darius = Fixture.named("Darius - Hand of Noxus")
        assertTrue(darius.isRareLegend)
        assertEquals("Darius", darius.title)
        assertEquals("Hand of Noxus", darius.subtitle)
        assertEquals("Trifarian", Fixture.named("Darius - Trifarian (Alternate Art)").subtitle)
        val allay = Card(id = "a", name = "Allay, Eager Admirer")
        assertEquals("Allay" to "Eager Admirer", allay.title to allay.subtitle)
        val starter = Card(id = "s", name = "Dark Child - Starter", classification = Card.Classification(type = "Legend", supertype = "Champion"))
        assertFalse("a Starter legend is no champion", starter.isChampion)
    }

    @Test
    fun `search finds the rules text too, names first, never the icon tokens`() {
        val text = { plain: String -> Card.Text(plain = plain) }
        val all = listOf(
            Card(id = "1", name = "Sprite Fountain", text = text("When you play this, [Repeat] it.")),
            Card(id = "2", name = "Repeater", text = text("Deal 2.")),
            Card(id = "3", name = "Brambleback", text = text("[Buff] a friendly unit. Costs :rb_might: less.")),
            Card(id = "4", name = "Vi - Kingpin", tags = listOf("Piltover")),
        )
        assertEquals(listOf("2", "1"), CardQuery.filter(all, "repeat", CardFilters(), CardSort.Set).map { it.id })
        assertEquals(listOf("3"), CardQuery.filter(all, "Friendly", CardFilters(), CardSort.Set).map { it.id })
        assertEquals(listOf("4"), CardQuery.filter(all, "piltover", CardFilters(), CardSort.Set).map { it.id })
        assertEquals(emptyList<String>(), CardQuery.filter(all, "rb_might", CardFilters(), CardSort.Set).map { it.id })
        assertEquals(1, CardQuery.count(all, "friendly", CardFilters()))
    }

    @Test
    fun `the shortlist filter keeps only the cards kept in mind`() {
        val all = listOf(Card(id = "1", name = "Sprite Fountain"), Card(id = "2", name = "Repeater"), Card(id = "3", name = "Brambleback"))
        val kept = setOf("3", "1")
        assertEquals(listOf("3", "1").sorted(), CardQuery.filter(all, "", CardFilters(shortlist = true), CardSort.Set, kept).map { it.id }.sorted())
        assertEquals(3, CardQuery.filter(all, "", CardFilters(), CardSort.Set, kept).size)
        assertEquals(1, CardQuery.count(all, "spr", CardFilters(shortlist = true), kept))
        assertEquals(1, CardFilters(shortlist = true).sheetCount)
    }

    @Test
    fun `search, domains and types combine`() {
        val fury = CardQuery.filter(all, "", CardFilters(domains = setOf("Fury")), CardSort.Set)
        assertTrue(fury.isNotEmpty() && fury.all { c -> c.domains.any { it.equals("Fury", true) } })
        val darius = CardQuery.filter(all, "darius", CardFilters(), CardSort.Set)
        assertTrue(darius.isNotEmpty() && darius.all { it.name.contains("Darius") })
        val legends = CardQuery.filter(all, "", CardFilters(types = setOf("Legend")), CardSort.Set)
        assertTrue(legends.all { it.isLegend })
    }

    @Test
    fun `set is release order by number, energy groups each cost by set`() {
        fun card(id: String, set: String, number: Int, energy: Int) =
            Card(id = id, name = id, collectorNumber = number, attributes = Card.Attributes(energy = energy), set = Card.CardSet(label = set))
        val cards = listOf(card("sfd1", "Spiritforged", 1, 0), card("ogn2", "Origins", 2, 0), card("ogn1", "Origins", 1, 5), card("ogn3", "Origins", 3, 1))
        assertEquals(listOf("ogn1", "ogn2", "ogn3", "sfd1"), CardQuery.filter(cards, "", CardFilters(), CardSort.Set).map { it.id })
        assertEquals(listOf("ogn2", "sfd1", "ogn3", "ogn1"), CardQuery.filter(cards, "", CardFilters(), CardSort.Energy).map { it.id })
    }

    @Test
    fun `a slider at its cap has no upper limit`() {
        val anyCost = CardQuery.filter(all, "", CardFilters(energy = 0..CardFilters.ENERGY_CAP), CardSort.Set)
        assertEquals(all.size, anyCost.size)
        val cheap = CardQuery.filter(all, "", CardFilters(energy = 0..2), CardSort.Set)
        assertTrue(cheap.all { (it.attributes?.energy ?: 0) <= 2 })
        assertEquals(1, CardFilters(energy = 0..2).sheetCount)
    }

    @Test
    fun `set order follows release, then energy, then collector number`() {
        val sorted = CardQuery.filter(all, "", CardFilters(), CardSort.Set)
        val ranks = sorted.map { CardFilters.setRank(it.set?.label) }
        assertEquals(ranks.sorted(), ranks)
        val byEnergy = CardQuery.filter(all, "", CardFilters(), CardSort.Energy)
        val energies = byEnergy.map { it.attributes?.energy ?: Int.MAX_VALUE }
        assertEquals(energies.sorted(), energies)
        assertEquals(0, CardFilters.setRank("Origins"))
        assertEquals(2, CardFilters.setRank("Spiritforged"))
    }

    @Test
    fun `duplicates are dropped and legends are named once per printing`() {
        assertEquals(all.size, CardQuery.dedupe(all + all.take(5)).size)
        val names = CardQuery.legendNames(all)
        assertTrue("Darius - Hand of Noxus" in names)
        assertFalse(names.any { it.endsWith(")") })
        assertEquals(names.distinct(), names)
    }

    @Test
    fun `every opponent legend has its picture, the plain printing first`() {
        val art = CardQuery.legendArt(all)
        assertEquals(CardQuery.legendNames(all).toSet(), art.keys)
        assertEquals("Darius - Hand of Noxus", art["Darius - Hand of Noxus"]?.name)
        val annie = Card(id = "ogs-017-024", name = "Annie - Dark Child (Starter)", classification = Card.Classification(type = "Legend", rarity = "Rare"))
        assertEquals("ogs-017-024", CardQuery.legendArt(listOf(annie))["Annie - Dark Child"]?.id)
    }

    @Test
    fun `a broken feed is refused`() {
        assertFalse(CardQuery.plausible(all, emptyList()))
        val big = List(1400) { all[it % all.size] }
        assertTrue(CardQuery.plausible(big, all))
        assertFalse(CardQuery.plausible(big.take(600), List(1400) { all[0] }))
    }

    @Test
    fun `new types in the feed join the filter after the known ones`() {
        assertEquals(listOf("Unit", "Spell", "Gear", "Battlefield", "Legend", "Rune"), CardQuery.options(CardFilters.knownTypes, all.map { it.type }, CardFilters.tokenParent.keys))
    }
}

class CardTextTest {
    @Test
    fun `symbols, keywords, arrows, lists and line breaks`() {
        val html = "<p>[Level 3][&gt;] I have +1 :rb_might:.<br />[Equip] :rb_rune_fury: (:rb_rune_fury:: Attach this.)<br />" +
            "The first time I move each turn, [Add] :rb_energy_1::rb_rune_rainbow:.</p><ul><li>Choose up to 3 cards.</li><li>Draw 1.</li></ul>"
        val blocks = CardText.parse(html)
        assertEquals(3, blocks.size)
        val first = blocks[0].runs
        assertEquals(TextBlock.Run.Keyword("Level 3"), first[0])
        assertEquals(TextBlock.Run.Arrow, first[1])
        assertTrue(TextBlock.Run.Symbol("rb_might") in first)
        assertTrue(TextBlock.Run.Symbol("rune_fury") in first)
        assertTrue(TextBlock.Run.Symbol("rb_energy_1") in first)
        assertTrue(TextBlock.Run.Symbol("rb_rune_rainbow") in first)
        assertTrue(blocks[1].bullet && blocks[2].bullet)
        assertEquals(listOf(TextBlock.Run.Plain("Draw 1.")), blocks[2].runs)
    }

    @Test
    fun `errata bracket codes use the card's own rune, unknown tokens stay readable`() {
        val runs = CardText.parse("Pay [2][C] and [E]: [NO TEXT]:rb_unknown_thing:", domain = "Calm").single().runs
        assertEquals(
            listOf(
                TextBlock.Run.Plain("Pay "), TextBlock.Run.Symbol("rb_energy_2"), TextBlock.Run.Symbol("rune_calm"),
                TextBlock.Run.Plain(" and "), TextBlock.Run.Symbol("rb_exhaust"), TextBlock.Run.Plain(": "), TextBlock.Run.Plain("unknown thing"),
            ),
            runs,
        )
    }

    @Test
    fun `every card in the fixture parses without losing text`() {
        Fixture.cards.forEach { c -> c.text?.rich?.let { CardText.parse(it, c.domains.firstOrNull()) } }
    }
}

class ErrataTest {
    @Test
    fun `names are matched without printing, accents or punctuation`() {
        assertEquals("kinkoumonk", ErrataStore.normalize("Kinkou Monk (Showcase)"))
        assertEquals("kaisadaughterofthevoid", ErrataStore.normalize("Kai'Sa - Daughter of the Void"))
        assertEquals("pokemon", ErrataStore.normalize("Pokémon"))
    }
}
