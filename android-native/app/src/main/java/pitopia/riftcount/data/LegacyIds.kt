package pitopia.riftcount.data

import pitopia.riftcount.cards.Card

/**
 * Decks saved before 3.5 (iOS) and by the Skip app 3.4 point at riftcodex database ids; the snapshot of that
 * database (`cards_cache_v1.json`) leads them to the hosted feed's ids. iOS `DecklistStore.remapLegacyIDs`.
 */
object LegacyIds {
    const val LEGACY_SNAPSHOT = "cards_cache_v1.json"

    class Result(val lists: List<Decklist>, val changed: Boolean, val unresolved: Int)

    fun remap(lists: List<Decklist>, cards: List<Card>, legacy: List<Card>): Result {
        val known = cards.mapTo(HashSet()) { it.id }
        val byRiftboundId = HashMap<String, String>().apply { cards.forEach { c -> c.riftboundId?.let { putIfAbsent(it, c.id) } } }
        val byName = cards.groupBy { it.name.lowercase() }
        val legacyById = HashMap<String, Card>().apply { legacy.forEach { putIfAbsent(it.id, it) } }

        fun unique(name: String, set: String?): String? {
            val candidates = byName[name.lowercase()].orEmpty()
            if (candidates.size == 1) return candidates[0].id
            return candidates.filter { it.set?.setId != null && it.set.setId == set }.singleOrNull()?.id
        }
        fun resolve(e: DecklistEntry): String? {
            if (e.cardId in known) return e.cardId
            legacyById[e.cardId]?.let { old ->
                old.riftboundId?.let(byRiftboundId::get)?.let { return it }
                val base = old.name.replace(Regex("\\s*\\([^)]*\\)$"), "")
                (unique(old.name, old.set?.setId) ?: unique(base, old.set?.setId))?.let { return it }
                // Runes of a domain play the same: a promo printing the feed lacks becomes the domain's rune card.
                if (old.isRune) old.domains.firstOrNull()?.let { DeckRules.runeCard(it, cards) }?.let { return it.id }
            }
            return unique(e.cardName, null)
        }

        var changed = false
        var unresolved = 0
        fun remap(e: DecklistEntry): DecklistEntry {
            val id = resolve(e) ?: run { unresolved++; return e }
            if (id == e.cardId) return e
            changed = true
            return e.copy(cardId = id)
        }
        // Two old printings can land on one new id: one row per card.
        fun merged(entries: List<DecklistEntry>): List<DecklistEntry> =
            entries.map(::remap).groupBy { it.cardId }.map { (_, rows) -> rows.first().copy(count = rows.sumOf { it.count }) }

        val out = lists.map { d ->
            d.copy(
                champion = d.champion?.let(::remap), legend = d.legend?.let(::remap),
                battlefields = merged(d.battlefields), mainDeck = merged(d.mainDeck),
                sideDeck = merged(d.sideDeck), runes = merged(d.runes),
            )
        }
        return Result(out, changed, unresolved)
    }
}
