package pitopia.riftcount.data

import pitopia.riftcount.cards.Card

/** Riftbound deck rules as the iOS builder applies them (DeckBuilderState, DeckLegality, Card+Classifier). */
object DeckRules {
    const val MAIN = 39
    const val COPY_LIMIT = 3
    const val SIGNATURE_LIMIT = 3
    const val BATTLEFIELDS = 3
    const val RUNES = 12
    /** Tournament Rules 601.1.c.1: a sideboard of 10 or fewer cards. */
    const val SIDE_MAX = 10

    private val variantSuffixes = listOf(" showcase", " promo", " foil", " alt art", " alternate art", " overnumbered", " signature")

    /** One identity per card across printings: "Seal of Insight (Showcase)" counts as "seal of insight". */
    fun identityKey(card: Card): String {
        var t = (card.metadata?.cleanName?.takeIf { it.isNotEmpty() } ?: card.name).lowercase()
        t = t.replace(Regex("\\s*\\([^)]*\\)"), "")
        var changed = true
        while (changed) {
            changed = false
            for (s in variantSuffixes) if (t.endsWith(s)) { t = t.dropLast(s.length); changed = true; break }
        }
        return "name:" + t.split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ")
    }

    /** Main deck cards: no legend, battlefield, rune or token; colourless always, else all domains in the legend's. */
    fun eligible(card: Card, legendDomains: Set<String>): Boolean {
        if (card.isLegend || card.isBattlefield || card.isRune || card.isToken) return false
        // The feed writes "Colorless" as a domain; it is the absence of one (iOS only knew the empty list).
        val mine = card.domains.map { it.lowercase() }.filter { it != "colorless" }.toSet()
        return mine.isEmpty() || legendDomains.isEmpty() || legendDomains.containsAll(mine)
    }

    /**
     * Carries the legend's champion tag (Core Rules 103.2): the champion's name, Jinx for "Jinx - Loose Cannon".
     * A tag the legend shares with others is not one: Kennen's "Yordle" would offer every Yordle champion.
     */
    fun matchesLegend(card: Card, legend: Card): Boolean {
        val champion = legend.title
        return champion.isNotEmpty() && (card.title.equals(champion, true) || card.tags.orEmpty().any { it.equals(champion, true) })
    }

    /** A Signature card only goes with its own champion's legend (Core Rules 103.2.d); without a legend yet, any. */
    fun signatureFits(card: Card, legend: Card?): Boolean = !card.isSignature || legend == null || matchesLegend(card, legend)

    /** The rune card of a domain: the lowest collector number. */
    fun runeCard(domain: String, pool: List<Card>): Card? =
        pool.filter { c -> c.isRune && c.domains.any { it.equals(domain, true) } }.minByOrNull { it.collectorNumber ?: Int.MAX_VALUE }

    enum class Slot { Legend, Champion, Battlefield, Main, Side, Rune }

    /** Where "Add" puts a card in [deck]: a champion becomes the chosen one only while that slot is empty. */
    fun slotFor(card: Card, deck: Decklist, cards: Map<String, Card>): Slot = when {
        card.isLegend -> Slot.Legend
        card.isBattlefield -> Slot.Battlefield
        card.isRune -> Slot.Rune
        card.isChampion && deck.champion == null && deck.legend?.let { cards[it.cardId] }?.let { matchesLegend(card, it) } != false -> Slot.Champion
        else -> Slot.Main
    }

    fun legendDomains(deck: Decklist, cards: Map<String, Card>): Set<String> =
        deck.legend?.let { cards[it.cardId] }?.domains?.map { it.lowercase() }?.toSet() ?: emptySet()

    /** Copies of the card's identity in main + side, plus the champion as one. */
    fun copies(deck: Decklist, card: Card, cards: Map<String, Card>): Int {
        val key = identityKey(card)
        val listed = (deck.mainDeck + deck.sideDeck).filter { e -> cards[e.cardId]?.let(::identityKey) == key }.sumOf { it.count }
        val champion = deck.champion?.let { cards[it.cardId] }?.takeIf { identityKey(it) == key }?.let { 1 } ?: 0
        return listed + champion
    }

    fun signatures(deck: Decklist, cards: Map<String, Card>) =
        (deck.mainDeck + deck.sideDeck).filter { cards[it.cardId]?.isSignature == true }.sumOf { it.count }

    /** Why another copy cannot go in, or null when it can. */
    fun blocker(card: Card, deck: Decklist, cards: Map<String, Card>): String? = when (slotFor(card, deck, cards)) {
        Slot.Legend, Slot.Champion -> null
        Slot.Battlefield -> if (deck.battlefields.any { it.cardId == card.id }) "Already a battlefield" else if (deck.battlefields.size >= BATTLEFIELDS) "3 battlefields already" else null
        Slot.Rune -> if (deck.runes.sumOf { it.count } >= RUNES) "12 runes already" else null
        Slot.Main, Slot.Side -> when {
            !eligible(card, legendDomains(deck, cards)) -> "Outside the legend's domains"
            !signatureFits(card, deck.legend?.let { cards[it.cardId] }) -> "Signature card of another champion"
            copies(deck, card, cards) >= COPY_LIMIT -> "3 copies already"
            card.isSignature && signatures(deck, cards) >= SIGNATURE_LIMIT -> "3 signature cards already"
            deck.mainDeck.sumOf { it.count } >= MAIN -> "Main deck is full"
            else -> null
        }
    }

    fun add(card: Card, deck: Decklist, cards: Map<String, Card>, nowMs: Long): Decklist {
        val entry = DecklistEntry(card.id, card.name, 1)
        fun plus(list: List<DecklistEntry>) =
            if (list.any { it.cardId == card.id }) list.map { if (it.cardId == card.id) it.copy(count = it.count + 1) else it } else list + entry
        val next = when (slotFor(card, deck, cards)) {
            Slot.Legend -> deck.copy(legend = entry)
            Slot.Champion -> deck.copy(champion = entry)
            Slot.Battlefield -> deck.copy(battlefields = plus(deck.battlefields))
            Slot.Rune -> deck.copy(runes = plus(deck.runes))
            Slot.Main -> deck.copy(mainDeck = plus(deck.mainDeck))
            Slot.Side -> deck.copy(sideDeck = plus(deck.sideDeck))
        }
        return next.copy(updatedAt = nowMs)
    }

    /** Takes one copy out: main deck first, then side, then the battlefield, rune or champion slot. */
    fun remove(card: Card, deck: Decklist, nowMs: Long): Decklist {
        fun minus(list: List<DecklistEntry>) = list.mapNotNull { if (it.cardId == card.id) it.copy(count = it.count - 1).takeIf { e -> e.count > 0 } else it }
        val next = when {
            deck.mainDeck.any { it.cardId == card.id } -> deck.copy(mainDeck = minus(deck.mainDeck))
            deck.sideDeck.any { it.cardId == card.id } -> deck.copy(sideDeck = minus(deck.sideDeck))
            deck.battlefields.any { it.cardId == card.id } -> deck.copy(battlefields = minus(deck.battlefields))
            deck.runes.any { it.cardId == card.id } -> deck.copy(runes = minus(deck.runes))
            deck.champion?.cardId == card.id -> deck.copy(champion = null)
            deck.legend?.cardId == card.id -> deck.copy(legend = null)
            else -> return deck
        }
        return next.copy(updatedAt = nowMs)
    }

    /** Copies of exactly this printing in the deck (all slots). */
    fun count(card: Card, deck: Decklist): Int =
        (deck.mainDeck + deck.sideDeck + deck.battlefields + deck.runes).filter { it.cardId == card.id }.sumOf { it.count } +
            listOfNotNull(deck.champion, deck.legend).count { it.cardId == card.id }

    /**
     * iOS `DeckLegality` issue texts, verbatim; with [cards] also the copy and signature limits and cards outside
     * the legend's domains, which an imported or re-legended list can break (iOS only enforces them while adding).
     */
    fun issues(deck: Decklist, cards: Map<String, Card> = emptyMap()): List<String> = buildList {
        if (deck.champion == null) add("Missing champion")
        if (deck.legend == null) add("Missing legend")
        deck.battlefields.sumOf { it.count }.let { if (it != BATTLEFIELDS) add("Battlefields: $it/$BATTLEFIELDS") }
        deck.mainDeck.sumOf { it.count }.let { if (it != MAIN) add("Main deck: $it/$MAIN") }
        deck.sideDeck.sumOf { it.count }.let { if (it > SIDE_MAX) add("Side deck: $it (max $SIDE_MAX)") }
        deck.runes.sumOf { it.count }.let { if (it != RUNES) add("Runes: $it/$RUNES") }
        if (cards.isEmpty()) return@buildList
        val listed = (deck.mainDeck + deck.sideDeck).mapNotNull { e -> cards[e.cardId]?.let { it to e.count } } +
            listOfNotNull(deck.champion?.let { cards[it.cardId] }?.let { it to 1 })
        listed.groupBy { identityKey(it.first) }.values.forEach { rows ->
            val n = rows.sumOf { it.second }
            if (n > COPY_LIMIT) add("${rows.first().first.title}: $n copies (max $COPY_LIMIT)")
        }
        signatures(deck, cards).let { if (it > SIGNATURE_LIMIT) add("Signature cards: $it/$SIGNATURE_LIMIT") }
        val legend = deck.legend?.let { cards[it.cardId] } ?: return@buildList
        val listedCards = (deck.mainDeck + deck.sideDeck).mapNotNull { cards[it.cardId] }.distinctBy { it.id }
        listedCards.filterNot { eligible(it, legendDomains(deck, cards)) }.forEach { add("${it.name}: outside ${legend.title}'s domains") }
        listedCards.filterNot { signatureFits(it, legend) }.forEach { add("${it.name}: signature card of another champion") }
    }

    /** The pile's chip: Legal, Draft while the main deck is under 30 cards, else the number of issues (mock). */
    fun status(deck: Decklist, cards: Map<String, Card>): String {
        val n = issues(deck, cards).size
        return when {
            n == 0 -> "Legal"
            deck.mainDeck.sumOf { it.count } < 30 -> "Draft"
            n == 1 -> "1 issue"
            else -> "$n issues"
        }
    }
}
