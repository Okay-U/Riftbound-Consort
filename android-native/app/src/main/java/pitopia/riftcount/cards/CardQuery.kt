package pitopia.riftcount.cards

enum class CardSort(val label: String) { Set("Set"), Energy("Energy"), Type("Type") }

/** The Cards tab's search state, iOS `CardFilters`: a max slider at its cap means "no upper limit". */
data class CardFilters(
    val domains: Set<String> = emptySet(),
    val types: Set<String> = emptySet(),
    val series: Set<String> = emptySet(),
    val rarities: Set<String> = emptySet(),
    val energy: IntRange = 0..ENERGY_CAP,
    val power: IntRange = 0..POWER_CAP,
    val might: IntRange = 0..MIGHT_CAP,
) {
    /** Filters behind the Filter button (domains have their own row). */
    val sheetCount: Int
        get() = types.size + series.size + rarities.size +
            listOf(energy != 0..ENERGY_CAP, power != 0..POWER_CAP, might != 0..MIGHT_CAP).count { it }

    companion object {
        const val ENERGY_CAP = 12
        const val POWER_CAP = 12
        const val MIGHT_CAP = 14
        val knownTypes = listOf("Unit", "Spell", "Gear", "Battlefield", "Legend")
        val knownRarities = listOf("Common", "Uncommon", "Rare", "Epic", "Showcase")
        /** Release order, as the feed labels the sets (iOS matches these as label fragments). */
        val knownSeries = listOf("Origins", "Proving Grounds", "Spiritforged", "Unleashed", "Vendetta", "Radiance")
        val tokenParent = mapOf("recruit" to "unit", "gold" to "gear")
        val domainsInOrder = listOf("Fury", "Calm", "Mind", "Body", "Chaos", "Order")

        fun setRank(label: String?): Int =
            label?.let { l -> knownSeries.indexOfFirst { l.contains(it, ignoreCase = true) }.takeIf { it >= 0 } } ?: Int.MAX_VALUE
    }
}

object CardQuery {
    /** Matching cards in [sort] order; with a search, the cards named so lead those that only say it in their text. */
    fun filter(cards: List<Card>, query: String, f: CardFilters, sort: CardSort): List<Card> {
        val q = query.trim()
        val hits = cards.filter { matches(it, q, f) }.sortedWith(comparator(sort))
        if (q.isEmpty()) return hits
        val (named, said) = hits.partition { it.name.contains(q, ignoreCase = true) }
        return named + said
    }

    /** Hits without sorting, for the filter sheet's live "Show N cards" while a slider moves. */
    fun count(cards: List<Card>, query: String, f: CardFilters): Int = cards.count { matches(it, query.trim(), f) }

    private fun matches(c: Card, q: String, f: CardFilters) =
        (q.isEmpty() || c.name.contains(q, ignoreCase = true) || c.searchText.contains(q, ignoreCase = true)) &&
            (f.domains.isEmpty() || c.domains.any { d -> f.domains.any { it.equals(d, true) } }) &&
            (f.types.isEmpty() || f.types.any { matchesType(c, it) }) &&
            (f.series.isEmpty() || f.series.any { c.set?.label?.contains(it, ignoreCase = true) == true }) &&
            (f.rarities.isEmpty() || f.rarities.any { it.equals(c.rarity, true) }) &&
            within(c.attributes?.energy ?: 0, f.energy, CardFilters.ENERGY_CAP) &&
            within(c.attributes?.power ?: 0, f.power, CardFilters.POWER_CAP) &&
            within(c.attributes?.might ?: 0, f.might, CardFilters.MIGHT_CAP)

    private fun within(v: Int, r: IntRange, cap: Int) = v >= r.first && (r.last >= cap || v <= r.last)

    private fun matchesType(c: Card, option: String): Boolean {
        val t = option.lowercase()
        val type = c.type.lowercase()
        return type == t || (c.isToken && (CardFilters.tokenParent[type] ?: type) == t)
    }

    /** Primary sort, then energy (unless energy is primary), then collector number and name, like iOS. */
    fun comparator(sort: CardSort): Comparator<Card> {
        val set = compareBy<Card> { CardFilters.setRank(it.set?.label) }
        val energy = compareBy<Card> { it.attributes?.energy ?: Int.MAX_VALUE }
        val type = compareBy<Card, String>(String.CASE_INSENSITIVE_ORDER) { it.classification?.type ?: "~" }
        val primary = when (sort) {
            CardSort.Set -> set.then(energy)
            CardSort.Energy -> energy
            CardSort.Type -> type.then(energy)
        }
        return primary.thenBy { it.collectorNumber ?: Int.MAX_VALUE }.thenBy(String.CASE_INSENSITIVE_ORDER) { it.name }
    }

    /** Baseline options first, then any new value in the feed (a new set's type) alphabetically. */
    fun options(baseline: List<String>, values: List<String>, excluding: Set<String> = emptySet()): List<String> {
        val seen = baseline.map { it.lowercase() }.toMutableSet()
        val extras = values.filter { v -> v.isNotBlank() && v.lowercase() !in excluding && seen.add(v.lowercase()) }
        return baseline + extras.sortedBy { it.lowercase() }
    }

    /** One row per printing and per id: the feed is de-duplicated, a source hiccup must not double the grid. */
    fun dedupe(cards: List<Card>): List<Card> {
        val keys = HashSet<String>()
        val ids = HashSet<String>()
        return cards.filter { keys.add("${it.riftboundId ?: it.id}|${it.name}") && ids.add(it.id) }
    }

    /** Opponent legends for the scoreboard: rare legends, one name per legend (no printing suffix). */
    fun legendNames(cards: List<Card>): List<String> =
        cards.filter { it.isRareLegend }.map { it.name.replace(Regex("\\s*\\([^)]*\\)$"), "") }.distinct().sorted()

    /** A new feed must not be a broken build: at least 500 cards and half of what is shown now. */
    fun plausible(new: List<Card>, old: List<Card>) = new.size >= maxOf(500, old.size / 2)
}
