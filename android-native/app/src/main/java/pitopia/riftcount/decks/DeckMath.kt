package pitopia.riftcount.decks

import kotlin.random.Random
import pitopia.riftcount.cards.Card
import pitopia.riftcount.data.Decklist

/** Draw odds, iOS `DrawProbabilityView`: hypergeometric P(at least k of K copies in n cards of N). */
object Odds {
    fun binomial(n: Int, k: Int): Double {
        if (k < 0 || k > n) return 0.0
        var r = 1.0
        for (i in 0 until minOf(k, n - k)) r = r * (n - i) / (i + 1)
        return r
    }

    fun atLeast(deck: Int, copies: Int, drawn: Int, k: Int): Double {
        if (deck <= 0 || copies < 0 || drawn < 0 || k < 0 || drawn > deck || copies > deck) return 0.0
        val top = minOf(copies, drawn)
        if (k > top) return 0.0
        val all = binomial(deck, drawn)
        return (k..top).sumOf { i -> binomial(copies, i) * binomial(deck - copies, drawn - i) } / all
    }
}

/** The stats sheet: energy curve 0…7+, power per domain, card types, average energy. */
data class DeckStats(val curve: List<Int>, val power: List<Pair<String, Int>>, val types: List<Pair<String, Int>>, val averageEnergy: Double?) {
    companion object {
        private val domainOrder = listOf("fury", "calm", "mind", "body", "chaos", "order")

        /** Curve, types and average count the main deck and the chosen champion; power also the sideboard (iOS). */
        fun of(deck: Decklist, cards: Map<String, Card>): DeckStats {
            val champion = listOfNotNull(deck.champion?.let { cards[it.cardId] }?.let { it to 1 })
            val main = deck.mainDeck.mapNotNull { e -> cards[e.cardId]?.let { it to e.count } } + champion
            val withSide = main + deck.sideDeck.mapNotNull { e -> cards[e.cardId]?.let { it to e.count } }
            val curve = IntArray(8)
            var energy = 0
            var costed = 0
            main.forEach { (c, n) ->
                c.attributes?.energy?.let { e ->
                    curve[e.coerceIn(0, 7)] += n
                    energy += e * n
                    costed += n
                }
            }
            val power = HashMap<String, Int>()
            withSide.forEach { (c, n) ->
                val p = c.attributes?.power ?: 0
                if (p > 0) c.domains.map { it.lowercase() }.forEach { d -> power[d] = (power[d] ?: 0) + p * n }
            }
            val types = listOf("Unit", "Spell", "Gear").map { t -> t to main.filter { it.first.type.equals(t, true) }.sumOf { it.second } }
            return DeckStats(
                curve = curve.toList(),
                power = domainOrder.mapNotNull { d -> power[d]?.let { d.replaceFirstChar(Char::uppercase) to it } },
                types = types,
                averageEnergy = if (costed > 0) energy.toDouble() / costed else null,
            )
        }
    }
}

/**
 * A test hand (iOS `DrawHandView` with the mock's rules): four cards, one mulligan of up to two cards that go to
 * the bottom of the deck, draw one at a time up to eight.
 */
data class Hand(val pile: List<String>, val cards: List<HandCard>, val marked: Set<Int> = emptySet(), val mulliganUsed: Boolean = false, val nextId: Int) {
    data class HandCard(val id: Int, val cardId: String)

    val canDraw: Boolean get() = pile.isNotEmpty() && cards.size < MAX
    val canMulligan: Boolean get() = !mulliganUsed && marked.isNotEmpty()

    /** null when the card cannot be marked, with the reason. */
    fun toggle(id: Int): Pair<Hand, String?> = when {
        mulliganUsed -> this to "One mulligan per game"
        cards.size > OPENING -> this to "Only the opening hand can be mulliganed"
        id in marked -> copy(marked = marked - id) to null
        marked.size >= MULLIGAN -> this to "Mulligan up to 2 cards"
        else -> copy(marked = marked + id) to null
    }

    fun mulligan(): Hand {
        if (!canMulligan) return this
        var next = nextId
        var top = pile
        val back = mutableListOf<String>()
        val kept = cards.map { c ->
            if (c.id !in marked || top.isEmpty()) return@map c
            back += c.cardId
            HandCard(next++, top.first()).also { top = top.drop(1) }
        }
        return Hand(top + back, kept, emptySet(), true, next)
    }

    fun draw(): Hand = if (!canDraw) this else copy(pile = pile.drop(1), cards = cards + HandCard(nextId, pile.first()), marked = emptySet(), nextId = nextId + 1)

    companion object {
        const val OPENING = 4
        const val MULLIGAN = 2
        const val MAX = 8

        /** A fresh shuffle; ids go on from [firstId], so a new hand's cards are new cards to the screen. */
        fun deal(deck: Decklist, random: Random = Random.Default, firstId: Int = 0): Hand {
            val all = deck.mainDeck.flatMap { e -> List(e.count) { e.cardId } }.shuffled(random)
            val first = all.take(OPENING)
            return Hand(all.drop(first.size), first.mapIndexed { i, id -> HandCard(firstId + i, id) }, nextId = firstId + first.size)
        }
    }
}
