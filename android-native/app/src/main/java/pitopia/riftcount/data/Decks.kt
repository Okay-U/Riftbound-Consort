package pitopia.riftcount.data

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

// ponytail: read-only for the scoreboard's deck name; phase 3 grows this into the full deck store.
class DecklistStore(private val docs: Documents) {
    private val serializer = ListSerializer(Decklist.serializer())

    val lists: List<Decklist> = docs.read(FILE) { SwiftJson.decodeFromString(serializer, it) } ?: emptyList()

    fun find(id: String): Decklist? = lists.firstOrNull { it.id.equals(id, ignoreCase = true) }

    companion object {
        const val FILE = "decklists_v2.json"
    }
}
