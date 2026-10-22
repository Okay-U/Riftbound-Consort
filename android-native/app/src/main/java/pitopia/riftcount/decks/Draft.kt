package pitopia.riftcount.decks

import pitopia.riftcount.cards.Card
import pitopia.riftcount.data.DeckRules
import pitopia.riftcount.data.Decklist
import pitopia.riftcount.data.DecklistEntry
import pitopia.riftcount.data.newId

/** The builder rail's seven stops, labelled like the mock. */
enum class BuildStep(val label: String, val title: String) {
    Legend("Legend", "Pick a legend"),
    Champion("Champion", "Pick your champion"),
    Fields("Fields", "Three battlefields"),
    Main("Main", "Main deck"),
    Side("Side", "Sideboard"),
    Runes("Runes", "Rune pool"),
    Save("Save", "Name and save"),
}

enum class Pile { Main, Side }

/**
 * A deck being built or edited, iOS `DeckBuilderState`: nothing reaches the store before it is saved.
 * Every change returns a new draft.
 */
data class Draft(
    val legend: Card? = null,
    val champion: Card? = null,
    val battlefields: List<Card> = emptyList(),
    val main: List<DecklistEntry> = emptyList(),
    val side: List<DecklistEntry> = emptyList(),
    /** Domain (lower case) to rune count, 12 in all. */
    val runes: Map<String, Int> = emptyMap(),
    val name: String = "",
    /** The deck being edited; null for a new one. */
    val editing: Decklist? = null,
    /** Battlefields or runes the pickers cannot show in full (a card the feed lacks, a rune outside the legend): saved as they are. */
    val keepBattlefields: Boolean = false,
    val keepRunes: Boolean = false,
    /** The edited deck's legend or champion when the card list does not know it: kept unless replaced. */
    val unknownLegend: DecklistEntry? = null,
    val unknownChampion: DecklistEntry? = null,
) {
    val domains: List<String> get() = legend?.domains.orEmpty().filterNot { it.equals("colorless", true) }
    val mainCount: Int get() = main.sumOf { it.count }
    val sideCount: Int get() = side.sumOf { it.count }
    val runeCount: Int get() = runes.values.sum()

    fun count(pile: Pile, card: Card): Int = entries(pile).firstOrNull { it.cardId == card.id }?.count ?: 0

    fun entries(pile: Pile) = if (pile == Pile.Main) main else side
}

object Builder {
    const val SIDE = 10

    fun legends(pool: List<Card>): List<Card> = pool.filter { it.isRareLegend }.distinctBy { it.id }.sortedBy { it.name.lowercase() }

    fun champions(legend: Card?, pool: List<Card>): List<Card> = legend?.let { l ->
        pool.filter { it.isChampion && DeckRules.matchesLegend(it, l) }.distinctBy { it.id }.sortedBy { it.name.lowercase() }
    }.orEmpty()

    /** Token battlefields (Baron Pit) only come up during a game. */
    fun battlefields(pool: List<Card>): List<Card> = pool.filter { it.isBattlefield && !it.isToken }.distinctBy { it.id }.sortedBy { it.name.lowercase() }

    /** Cards the legend allows, the legend's first domain first, then by energy and name (iOS pool order). */
    fun pool(draft: Draft, pool: List<Card>, query: String = "", types: Set<String> = emptySet()): List<Card> {
        val domains = draft.domains.map { it.lowercase() }
        val q = query.trim()
        fun rank(c: Card) = c.domains.map { it.lowercase() }.mapNotNull { d -> domains.indexOf(d).takeIf { it >= 0 } }.minOrNull() ?: Int.MAX_VALUE
        return pool.asSequence()
            .filter { DeckRules.eligible(it, domains.toSet()) }
            .filter { q.isEmpty() || it.name.contains(q, ignoreCase = true) }
            .filter { types.isEmpty() || types.any { t -> t.equals(it.type, true) } }
            .distinctBy { it.id }
            .sortedWith(compareBy<Card>({ rank(it) }, { it.attributes?.energy ?: Int.MAX_VALUE }, { it.name.lowercase() }))
            .toList()
    }

    /** A new legend clears what depended on the old one and splits the runes evenly (iOS `setLegend`). */
    fun pickLegend(d: Draft, card: Card): Draft {
        if (d.legend?.id == card.id) return d
        val autoName = d.name.isBlank() || d.name == defaultName(d.legend)
        return Draft(
            legend = card,
            runes = evenSplit(card.domains.filterNot { it.equals("colorless", true) }),
            name = if (autoName && d.editing == null) defaultName(card) else d.name,
            editing = d.editing,
        )
    }

    fun defaultName(legend: Card?) = legend?.let { "${it.title} deck" }.orEmpty()

    fun evenSplit(domains: List<String>): Map<String, Int> {
        if (domains.isEmpty()) return emptyMap()
        val base = DeckRules.RUNES / domains.size
        val extra = DeckRules.RUNES % domains.size
        return domains.mapIndexed { i, d -> d.lowercase() to base + if (i < extra) 1 else 0 }.toMap()
    }

    fun toggleBattlefield(d: Draft, card: Card): Draft = when {
        d.battlefields.any { it.id == card.id } -> d.copy(battlefields = d.battlefields.filterNot { it.id == card.id })
        d.battlefields.size < DeckRules.BATTLEFIELDS -> d.copy(battlefields = d.battlefields + card)
        else -> d
    }

    fun pickChampion(d: Draft, card: Card): Draft = d.copy(champion = card, unknownChampion = null)

    /** Copies of the card's identity across main, side and the chosen champion. */
    fun copies(d: Draft, card: Card, cards: Map<String, Card>): Int {
        val key = DeckRules.identityKey(card)
        val listed = (d.main + d.side).filter { e -> cards[e.cardId]?.let(DeckRules::identityKey) == key }.sumOf { it.count }
        return listed + if (d.champion?.let(DeckRules::identityKey) == key) 1 else 0
    }

    fun signatures(d: Draft, cards: Map<String, Card>) = (d.main + d.side).filter { cards[it.cardId]?.isSignature == true }.sumOf { it.count }

    /** Why one more copy cannot go on [pile], or null when it can (iOS `canAdd` plus the pile sizes). */
    fun blocker(d: Draft, pile: Pile, card: Card, cards: Map<String, Card>): String? = when {
        pile == Pile.Main && d.mainCount >= DeckRules.MAIN -> "Main deck is full"
        pile == Pile.Side && d.sideCount >= SIDE -> "Sideboard is full"
        copies(d, card, cards) >= DeckRules.COPY_LIMIT -> "3 copies already"
        card.isSignature && signatures(d, cards) >= DeckRules.SIGNATURE_LIMIT -> "3 signature cards already"
        else -> null
    }

    fun add(d: Draft, pile: Pile, card: Card): Draft {
        fun plus(list: List<DecklistEntry>) = if (list.any { it.cardId == card.id }) {
            list.map { if (it.cardId == card.id) it.copy(count = it.count + 1) else it }
        } else {
            list + DecklistEntry(card.id, card.name, 1)
        }
        return if (pile == Pile.Main) d.copy(main = plus(d.main)) else d.copy(side = plus(d.side))
    }

    fun remove(d: Draft, pile: Pile, card: Card): Draft {
        fun minus(list: List<DecklistEntry>) =
            list.mapNotNull { if (it.cardId == card.id) it.copy(count = it.count - 1).takeIf { e -> e.count > 0 } else it }
        return if (pile == Pile.Main) d.copy(main = minus(d.main)) else d.copy(side = minus(d.side))
    }

    fun rune(d: Draft, domain: String, delta: Int): Draft {
        val key = domain.lowercase()
        val cur = d.runes[key] ?: 0
        if (delta > 0 && d.runeCount >= DeckRules.RUNES) return d
        return d.copy(runes = d.runes + (key to (cur + delta).coerceAtLeast(0)))
    }

    /** The draft as a deck: new, or the edited one with its id and creation date. Runes are each domain's rune card. */
    fun toDeck(d: Draft, pool: List<Card>, nowMs: Long): Decklist {
        val base = d.editing ?: Decklist(id = newId(), name = d.name.trim(), createdAt = nowMs, updatedAt = nowMs)
        val runes = d.domains.mapNotNull { domain ->
            val n = d.runes[domain.lowercase()] ?: 0
            DeckRules.runeCard(domain, pool)?.takeIf { n > 0 }?.let { DecklistEntry(it.id, it.name, n) }
        }
        return base.copy(
            name = d.name.trim().ifEmpty { base.name },
            updatedAt = nowMs,
            legend = d.legend?.let { DecklistEntry(it.id, it.name, 1) } ?: d.unknownLegend,
            champion = d.champion?.let { DecklistEntry(it.id, it.name, 1) } ?: d.unknownChampion,
            battlefields = if (d.keepBattlefields) base.battlefields else d.battlefields.map { DecklistEntry(it.id, it.name, 1) },
            mainDeck = d.main,
            sideDeck = d.side,
            runes = if (d.keepRunes) base.runes else runes,
        )
    }

    /** An existing deck in the builder (iOS `loadFromExisting`): what the pickers cannot show stays untouched. */
    fun fromDeck(deck: Decklist, cards: Map<String, Card>): Draft {
        val legend = deck.legend?.let { cards[it.cardId] }
        val fields = deck.battlefields.mapNotNull { e -> cards[e.cardId]?.takeIf { e.count == 1 } }
        val domains = legend?.domains.orEmpty().map { it.lowercase() }.filter { it != "colorless" }
        val runes = HashMap<String, Int>().apply { domains.forEach { put(it, 0) } }
        var keepRunes = false
        deck.runes.forEach { e ->
            val domain = cards[e.cardId]?.domains?.firstOrNull()?.lowercase()
            if (domain != null && domain in domains) runes[domain] = (runes[domain] ?: 0) + e.count else keepRunes = true
        }
        val champion = deck.champion?.let { cards[it.cardId] }
        return Draft(
            legend = legend,
            champion = champion,
            battlefields = fields,
            main = deck.mainDeck,
            side = deck.sideDeck,
            runes = runes,
            name = deck.name,
            editing = deck,
            keepBattlefields = fields.size != deck.battlefields.size,
            keepRunes = keepRunes,
            unknownLegend = deck.legend.takeIf { legend == null },
            unknownChampion = deck.champion.takeIf { champion == null },
        )
    }
}
