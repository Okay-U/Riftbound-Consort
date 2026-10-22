package pitopia.riftcount.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import pitopia.riftcount.cards.Card

@Serializable
data class DecklistEntry(
    @SerialName("card_id") val cardId: String,
    @SerialName("card_name") val cardName: String,
    val count: Int,
)

/** One deck in `decklists_v2.json`, field for field the iOS `Decklist` (camelCase keys there). */
@Serializable
data class Decklist(
    val id: String = newId(),
    val name: String,
    @Serializable(with = SwiftDateSerializer::class) val createdAt: Long,
    @Serializable(with = SwiftDateSerializer::class) val updatedAt: Long,
    val champion: DecklistEntry? = null,
    val legend: DecklistEntry? = null,
    val battlefields: List<DecklistEntry> = emptyList(),
    val mainDeck: List<DecklistEntry> = emptyList(),
    val sideDeck: List<DecklistEntry> = emptyList(),
    val runes: List<DecklistEntry> = emptyList(),
)

/** `decklists_v2.json`; an unreadable file is kept aside by [Documents.read] before the next save. */
class DecklistStore(private val docs: Documents) {
    private val serializer = ListSerializer(Decklist.serializer())
    private val stored = docs.read(FILE) { SwiftJson.decodeFromString(serializer, it) }

    /** The file is there but could not be read: the id migration must not run on the empty list. */
    private val loadFailed = stored == null && docs.file(FILE).exists()

    var lists by mutableStateOf(stored ?: emptyList())
        private set

    fun find(id: String): Decklist? = lists.firstOrNull { it.id.equals(id, ignoreCase = true) }

    fun create(name: String, nowMs: Long = System.currentTimeMillis()): Decklist =
        Decklist(name = name, createdAt = nowMs, updatedAt = nowMs).also(::add)

    fun add(deck: Decklist) = save(lists + deck)

    /** Writes an edited deck back in one save, so an interrupted edit never leaves half a deck on disk. */
    fun replace(deck: Decklist) = save(lists.map { if (it.id == deck.id) deck else it })

    fun rename(id: String, name: String, nowMs: Long = System.currentTimeMillis()) =
        find(id)?.let { replace(it.copy(name = name, updatedAt = nowMs)) }

    fun delete(id: String) = save(lists.filterNot { it.id == id })

    /**
     * Old riftcodex ids onto the hosted feed, once the card list is there (iOS runs it on every card publish).
     * The legacy snapshot goes once every entry resolved. [legacy] is the decoded snapshot, read off the main thread.
     */
    fun migrateLegacyIds(cards: List<Card>, legacy: List<Card>): Boolean {
        if (cards.isEmpty() || loadFailed) return false
        val result = LegacyIds.remap(lists, cards, legacy)
        if (result.changed) save(result.lists)
        return result.unresolved == 0
    }

    private fun save(next: List<Decklist>) {
        lists = next
        docs.write(FILE, SwiftJson.encodeToString(serializer, next))
    }

    companion object {
        const val FILE = "decklists_v2.json"
    }
}
