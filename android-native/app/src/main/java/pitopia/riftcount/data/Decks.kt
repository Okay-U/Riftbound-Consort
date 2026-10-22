package pitopia.riftcount.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer

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

    var lists by mutableStateOf(docs.read(FILE) { SwiftJson.decodeFromString(serializer, it) } ?: emptyList())
        private set

    fun find(id: String): Decklist? = lists.firstOrNull { it.id.equals(id, ignoreCase = true) }

    fun create(name: String, nowMs: Long = System.currentTimeMillis()): Decklist =
        Decklist(name = name, createdAt = nowMs, updatedAt = nowMs).also { save(lists + it) }

    /** Writes an edited deck back in one save, so an interrupted edit never leaves half a deck on disk. */
    fun replace(deck: Decklist) = save(lists.map { if (it.id == deck.id) deck else it })

    fun delete(id: String) = save(lists.filterNot { it.id == id })

    private fun save(next: List<Decklist>) {
        lists = next
        docs.write(FILE, SwiftJson.encodeToString(serializer, next))
    }

    companion object {
        const val FILE = "decklists_v2.json"
    }
}
