package pitopia.riftcount.cards

import kotlin.random.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import pitopia.riftcount.data.Decklist
import pitopia.riftcount.data.DecklistEntry
import pitopia.riftcount.data.GameRecord
import pitopia.riftcount.data.ScoreEvent
import pitopia.riftcount.decks.Builder
import pitopia.riftcount.decks.DeckEdits
import pitopia.riftcount.decks.DeckStats
import pitopia.riftcount.decks.Draft
import pitopia.riftcount.decks.Hand
import pitopia.riftcount.decks.MatchLog
import pitopia.riftcount.decks.Odds
import pitopia.riftcount.decks.Pile
import pitopia.riftcount.decks.Tally

class BuilderTest {
    private val pool = Fixture.cards
    private val cards = pool.associateBy { it.id }
    private val darius = Fixture.named("Darius - Hand of Noxus")
    private val trifarian = Fixture.named("Darius - Trifarian")
    private val trifarianAlt = Fixture.named("Darius - Trifarian (Alternate Art)")

    @Test
    fun `a legend clears its dependants, names the deck and splits the runes`() {
        val d = Builder.pickLegend(Draft(main = listOf(DecklistEntry("x", "X", 3))), darius)
        assertTrue(d.main.isEmpty())
        assertEquals("Darius deck", d.name)
        assertEquals(mapOf("fury" to 6, "order" to 6), d.runes)
        assertEquals(mapOf("a" to 4, "b" to 4, "c" to 4), Builder.evenSplit(listOf("A", "B", "C")))
        assertEquals("Mine", Builder.pickLegend(d.copy(name = "Mine"), darius).name)
    }

    @Test
    fun `pool, champions and legends follow the legend`() {
        val d = Builder.pickLegend(Draft(), darius)
        val inPool = Builder.pool(d, pool)
        assertTrue(inPool.all { c -> c.domains.all { it in listOf("Fury", "Order", "Colorless") } })
        assertFalse("legends, runes, battlefields and tokens stay out", inPool.any { it.isLegend || it.isRune || it.isBattlefield || it.isToken })
        assertEquals("cheapest Fury card first", 0, inPool.indexOfFirst { it.domains == listOf("Fury") })
        assertTrue(Builder.champions(darius, pool).map { it.id }.containsAll(listOf("ogn-027-298", "ogn-243-298")))
        assertTrue(Builder.legends(pool).none { it.name.endsWith("(Signature)") })
    }

    @Test
    fun `copies count across printings and the champion`() {
        var d = Builder.pickChampion(Builder.pickLegend(Draft(), darius), trifarian)
        d = Builder.add(d, Pile.Main, trifarian)
        d = Builder.add(d, Pile.Side, trifarianAlt)
        assertEquals(3, Builder.copies(d, trifarian, cards))
        assertEquals("3 copies already", Builder.blocker(d, Pile.Main, trifarianAlt, cards))
        d = Builder.remove(d, Pile.Side, trifarianAlt)
        assertNull(Builder.blocker(d, Pile.Main, trifarianAlt, cards))
        assertEquals(12, Builder.rune(d, "fury", +1).runeCount)
        assertEquals(5, Builder.rune(d, "fury", -1).runes["fury"])
    }

    @Test
    fun `a saved draft becomes the edited deck again`() {
        var d = Builder.pickChampion(Builder.pickLegend(Draft(), darius), trifarian)
        pool.filter { it.isBattlefield }.forEach { d = Builder.toggleBattlefield(d, it) }
        d = Builder.add(d, Pile.Main, Fixture.named("Cleave"))
        val deck = Builder.toDeck(d, pool, nowMs = 10)
        // The fixture has no Order rune card, so only the Fury half is saved.
        assertEquals(listOf("rad-r01" to 6), deck.runes.map { it.cardId to it.count })
        assertEquals(3, deck.battlefields.size)
        val again = Builder.fromDeck(deck, cards)
        assertEquals(listOf(d.legend, d.champion, d.battlefields, d.main, d.name), listOf(again.legend, again.champion, again.battlefields, again.main, again.name))
        assertEquals(mapOf("fury" to 6, "order" to 0), again.runes)
        assertEquals(deck.id, Builder.toDeck(again, pool, nowMs = 20).id)
        assertEquals(deck.createdAt, Builder.toDeck(again, pool, nowMs = 20).createdAt)
    }

    @Test
    fun `cards the feed lacks are kept as they are`() {
        val deck = Decklist(
            name = "Old", createdAt = 0, updatedAt = 0,
            legend = DecklistEntry("legacy-legend", "Old Legend", 1),
            battlefields = listOf(DecklistEntry("legacy-bf", "Old Field", 1)),
            runes = listOf(DecklistEntry("legacy-rune", "Old Rune", 12)),
        )
        val d = Builder.fromDeck(deck, cards)
        assertTrue(d.keepBattlefields && d.keepRunes)
        val saved = Builder.toDeck(d, pool, nowMs = 1)
        assertEquals(deck.legend, saved.legend)
        assertEquals(deck.battlefields, saved.battlefields)
        assertEquals(deck.runes, saved.runes)
    }
}

class DeckMathTest {
    @Test
    fun `hypergeometric odds match the iOS numbers`() {
        // 1 - C(36,4)/C(39,4)
        assertEquals(0.2838, Odds.atLeast(39, 3, 4, 1), 0.0001)
        assertEquals(1.0, Odds.atLeast(39, 39, 4, 1), 1e-9)
        assertEquals(0.0, Odds.atLeast(39, 1, 4, 2), 1e-9)
        assertEquals(10.0, Odds.binomial(5, 2), 1e-9)
    }

    @Test
    fun `stats count the champion with the main deck and the sideboard for power`() {
        val cards = Fixture.cards.associateBy { it.id }
        val deck = Decklist(
            name = "S", createdAt = 0, updatedAt = 0,
            champion = DecklistEntry("ogn-027-298", "Darius - Trifarian", 1),
            mainDeck = listOf(DecklistEntry("ogn-004-298", "Cleave", 3), DecklistEntry("ogn-011-298", "Magma Wurm", 1)),
            sideDeck = listOf(DecklistEntry("ogn-008-298", "Get Excited!", 2)),
        )
        val s = DeckStats.of(deck, cards)
        assertEquals(3, s.curve[1])
        assertEquals(1, s.curve[5])
        assertEquals(1, s.curve[7])
        assertEquals(listOf("Unit" to 2, "Spell" to 3, "Gear" to 0), s.types)
        assertEquals((3 * 1 + 5 + 8) / 5.0, s.averageEnergy!!, 1e-9)
        assertTrue(s.power.single().first == "Fury")
    }

    @Test
    fun `a hand mulligans its opening cards once, to the bottom`() {
        val deck = Decklist(name = "H", createdAt = 0, updatedAt = 0, mainDeck = (1..10).map { DecklistEntry("c$it", "C$it", 1) })
        var h = Hand.deal(deck, Random(3))
        assertEquals(4, h.cards.size)
        assertEquals(6, h.pile.size)
        val first = h.cards[0]
        h = h.toggle(first.id).first.toggle(h.cards[1].id).first
        assertEquals("Mulligan up to 2 cards", h.toggle(h.cards[2].id).second)
        val before = h.pile
        h = h.mulligan()
        assertTrue(h.mulliganUsed)
        assertEquals(before.drop(2) + listOf(first.cardId), h.pile.dropLast(1))
        assertEquals("One mulligan per game", h.toggle(h.cards[0].id).second)
        repeat(10) { h = h.draw() }
        assertEquals(Hand.MAX, h.cards.size)
    }
}

class MatchLogTest {
    private fun e(t: Int, slot: Int, type: String, d: Int = 1) = ScoreEvent(elapsedSeconds = t, slot = slot, type = type, delta = d)

    @Test
    fun `score, race and tallies come from the point log`() {
        val g = GameRecord(
            date = 0, result = "won", durationSeconds = 1500, startedFirst = true,
            events = listOf(e(10, 1, "conquer"), e(20, 0, "hold"), e(30, 0, "manual", -1), e(40, 1, "hold"), e(50, 0, "conquer")),
        )
        assertEquals(2 to 1, MatchLog.score(g))
        assertEquals(listOf("conquer", "hold"), MatchLog.race(g)[1])
        assertEquals(listOf("conquer"), MatchLog.race(g)[0])
        val lost = GameRecord(date = 1, result = "lost", durationSeconds = 600, startedFirst = false)
        assertNull(MatchLog.score(lost))
        assertEquals(Tally(1, 1), Tally.of(listOf(g, lost)))
        assertEquals(Tally(1, 0) to Tally(0, 1), MatchLog.firstSecond(listOf(g, lost)))
        assertEquals(18, MatchLog.averageMinutes(listOf(g, lost)))
        assertEquals("25:00", MatchLog.clock(1500))
    }
}

class DeckEditsTest {
    private val pool = Fixture.cards
    private val cards = pool.associateBy { it.id }
    private val base = Decklist(
        name = "E", createdAt = 0, updatedAt = 0,
        legend = DecklistEntry("ogn-253-298", "Darius - Hand of Noxus", 1),
        champion = DecklistEntry("ogn-027-298", "Darius - Trifarian", 1),
        mainDeck = listOf(DecklistEntry("ogn-243-298", "Darius - Executioner", 2)),
        runes = listOf(DecklistEntry("ogn-007a-298", "Fury Rune (Alternate Art)", 5)),
    )

    @Test
    fun `swapping in a champion from the main deck keeps the card count`() {
        val d = DeckEdits.champion(base, Fixture.named("Darius - Executioner"), 1)
        assertEquals("ogn-243-298", d.champion?.cardId)
        assertEquals(listOf("ogn-243-298" to 1, "ogn-027-298" to 1), d.mainDeck.map { it.cardId to it.count })
        val fromSide = DeckEdits.champion(base.copy(mainDeck = emptyList(), sideDeck = base.mainDeck), Fixture.named("Darius - Executioner"), 1)
        assertTrue("main stays empty", fromSide.mainDeck.isEmpty())
        assertEquals(2, fromSide.sideDeck.sumOf { it.count })
    }

    @Test
    fun `runes change the printing already in the deck`() {
        val more = DeckEdits.rune(base, "Fury", +1, pool, cards, 1)
        assertEquals(listOf("ogn-007a-298" to 6), more.runes.map { it.cardId to it.count })
        val order = DeckEdits.rune(base, "Order", +1, pool, cards, 1)
        assertEquals("no Order rune card in the fixture", base, order)
        assertEquals(5, DeckEdits.runeCount(base, "Fury", cards))
    }

    @Test
    fun `a full main deck or three copies stop the plus`() {
        val executioner = Fixture.named("Darius - Executioner")
        assertTrue(DeckEdits.canAdd(base, Pile.Main, executioner, cards))
        val three = DeckEdits.step(base, Pile.Main, base.mainDeck[0], +1, 1)
        assertFalse(DeckEdits.canAdd(three, Pile.Main, executioner, cards))
        val battlefields = pool.filter { it.isBattlefield }
        var d: Decklist = base
        battlefields.forEach { b -> d = DeckEdits.toggleBattlefield(d, b, 1) ?: d }
        assertNull(DeckEdits.toggleBattlefield(d.copy(battlefields = d.battlefields.dropLast(1) + DecklistEntry("x", "X", 1)), battlefields.last(), 1))
    }
}
