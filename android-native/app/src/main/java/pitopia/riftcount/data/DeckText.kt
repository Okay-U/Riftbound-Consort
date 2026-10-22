package pitopia.riftcount.data

import pitopia.riftcount.cards.Card

/**
 * Plain-text deck lists, read and written like iOS `DeckTextFormat` (the format common Riftbound
 * deckbuilders use): sections Legend, Champion, MainDeck, Battlefields, Runes, Sideboard, "3 Card Name" lines.
 */
object DeckText {
    data class Parsed(
        val legend: Card? = null,
        val champion: Card? = null,
        val battlefields: List<Card> = emptyList(),
        val mainDeck: List<Pair<Card, Int>> = emptyList(),
        val sideDeck: List<Pair<Card, Int>> = emptyList(),
        /** Domain (lower case) to rune count. */
        val runeCounts: Map<String, Int> = emptyMap(),
        /** Lines that matched no card, as typed. */
        val unresolved: List<String> = emptyList(),
    ) {
        val isEmpty: Boolean
            get() = legend == null && champion == null && battlefields.isEmpty() && mainDeck.isEmpty() &&
                sideDeck.isEmpty() && runeCounts.isEmpty()
    }

    private enum class Section { None, Legend, Champion, Main, Battlefields, Runes, Side }

    fun export(deck: Decklist, cards: Map<String, Card>): String = buildList {
        fun section(title: String, entries: List<DecklistEntry>) {
            if (entries.isEmpty()) return
            add("$title:")
            aggregate(entries, cards).forEach { (name, count) -> add("$count $name") }
            add("")
        }
        section("Legend", listOfNotNull(deck.legend?.copy(count = 1)))
        section("Champion", listOfNotNull(deck.champion?.copy(count = 1)))
        section("MainDeck", deck.mainDeck)
        section("Battlefields", deck.battlefields)
        section("Runes", deck.runes)
        section("Sideboard", deck.sideDeck)
    }.joinToString("\n").trim()

    fun parse(text: String, pool: List<Card>): Parsed {
        var legend: Card? = null
        var champion: Card? = null
        val battlefields = mutableListOf<Card>()
        val main = mutableListOf<Pair<Card, Int>>()
        val side = mutableListOf<Pair<Card, Int>>()
        val runes = mutableMapOf<String, Int>()
        val unresolved = mutableListOf<String>()
        var section = Section.None
        text.lines().forEach { raw ->
            val line = raw.trim()
            if (line.isEmpty()) return@forEach
            header(line)?.let { section = it; return@forEach }
            val (count, name) = entry(line) ?: run { unresolved += raw; return@forEach }
            when (section) {
                Section.None -> unresolved += raw
                Section.Runes -> runeDomain(name)?.let { runes[it] = (runes[it] ?: 0) + count } ?: run { unresolved += raw }
                else -> {
                    val card = match(name, pool, section) ?: run { unresolved += raw; return@forEach }
                    when (section) {
                        Section.Legend -> legend = card
                        Section.Champion -> champion = card
                        Section.Battlefields -> repeat(count) { battlefields += card }
                        Section.Main -> main += card to count
                        Section.Side -> side += card to count
                        else -> Unit
                    }
                }
            }
        }
        return Parsed(legend, champion, battlefields, main, side, runes, unresolved)
    }

    /** The parsed list as a new deck, one entry per printing; runes are each domain's rune card. */
    fun toDeck(parsed: Parsed, name: String, pool: List<Card>, nowMs: Long): Decklist {
        fun entries(cards: List<Pair<Card, Int>>): List<DecklistEntry> =
            cards.groupBy { it.first.id }.map { (id, rows) -> DecklistEntry(id, rows.first().first.name, rows.sumOf { it.second }) }
        val runes = parsed.runeCounts.mapNotNull { (domain, count) ->
            DeckRules.runeCard(domain, pool)?.takeIf { count > 0 }?.let { it to count }
        }
        return Decklist(
            name = name, createdAt = nowMs, updatedAt = nowMs,
            legend = parsed.legend?.let { DecklistEntry(it.id, it.name, 1) },
            champion = parsed.champion?.let { DecklistEntry(it.id, it.name, 1) },
            battlefields = entries(parsed.battlefields.map { it to 1 }),
            mainDeck = entries(parsed.mainDeck),
            sideDeck = entries(parsed.sideDeck),
            runes = entries(runes),
        )
    }

    private fun header(line: String): Section? = when (line.replace(":", "").replace(" ", "").lowercase()) {
        "legend" -> Section.Legend
        "champion", "champions" -> Section.Champion
        "maindeck", "main" -> Section.Main
        "battlefields", "battlefield" -> Section.Battlefields
        "runes", "rune" -> Section.Runes
        "sideboard", "sidedeck", "side" -> Section.Side
        else -> null
    }

    /** "3 Card Name" or "3x Card Name". */
    private fun entry(line: String): Pair<Int, String>? {
        val parts = line.split(" ", limit = 2)
        if (parts.size != 2) return null
        val n = parts[0].lowercase().replace("x", "").toIntOrNull()?.takeIf { it > 0 } ?: return null
        return n to parts[1].trim()
    }

    /** Exact name (or clean name) first, then a name that contains the other; lowest collector number wins. */
    private fun match(name: String, pool: List<Card>, section: Section): Card? {
        val needle = normalise(name)
        val scope = pool.filter { fits(it, section) }.ifEmpty { pool }
        fun clean(c: Card) = normalise(c.metadata?.cleanName.orEmpty())
        val exact = scope.filter { normalise(it.name) == needle || clean(it) == needle }
        if (exact.isNotEmpty()) return preferred(exact)
        return preferred(scope.filter { c ->
            val n = normalise(c.name)
            val cn = clean(c)
            n.contains(needle) || cn.contains(needle) || needle.contains(n) || (cn.isNotEmpty() && needle.contains(cn))
        })
    }

    /**
     * iOS takes the lowest collector number; first the plain printing, so "Darius, Executioner" is not
     * imported as its Overnumbered reprint.
     */
    private fun preferred(cards: List<Card>): Card? = cards.minWithOrNull(
        compareBy<Card>({ it.metadata?.alternateArt == true || it.metadata?.overnumbered == true || it.metadata?.signature == true }, { it.collectorNumber ?: Int.MAX_VALUE }),
    )

    private fun fits(card: Card, section: Section) = when (section) {
        Section.Legend -> card.isLegend
        Section.Champion -> card.isChampion
        Section.Battlefields -> card.isBattlefield
        Section.Runes -> card.isRune
        Section.Main, Section.Side -> !card.isLegend && !card.isBattlefield && !card.isRune
        Section.None -> true
    }

    private val qualifier = Regex("\\s*\\([^)]*\\)")

    /** Lower case, no "(Showcase)" qualifiers, letters and digits only: "Yone, Blademaster" = "Yone Blademaster". */
    private fun normalise(s: String): String =
        s.lowercase().replace(qualifier, "").filter { it.isLetterOrDigit() || it.isWhitespace() }
            .split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ")

    private fun runeDomain(name: String): String? =
        normalise(name).removeSuffix(" rune").removePrefix("rune of ").trim().ifEmpty { null }

    private val variantSuffixes = listOf(
        " metal", " signature", " promo", " foil", " showcase", " alternate art", " alt art", " overnumbered", " gold", " silver", " bronze",
    )

    /** The name other deckbuilders read: no printing qualifier or variant word, "Name, Subtitle" instead of "Name - Subtitle". */
    fun exportName(raw: String): String {
        var t = raw.replace(qualifier, "").replace(" - ", ", ")
        var changed = true
        while (changed) {
            changed = false
            for (s in variantSuffixes) if (t.lowercase().endsWith(s)) { t = t.dropLast(s.length); changed = true; break }
        }
        return t.trim()
    }

    /** Printings of one card collapse into one line, in first-seen order. */
    private fun aggregate(entries: List<DecklistEntry>, cards: Map<String, Card>): List<Pair<String, Int>> {
        val counts = LinkedHashMap<String, Int>()
        entries.forEach { e ->
            val name = exportName(cards[e.cardId]?.name ?: e.cardName)
            counts[name] = (counts[name] ?: 0) + e.count
        }
        return counts.toList()
    }
}
