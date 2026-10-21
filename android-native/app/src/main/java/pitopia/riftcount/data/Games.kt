package pitopia.riftcount.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer

/** One point change inside a game, as iOS stores it (`type` conquer, hold or manual). */
@Serializable
data class ScoreEvent(
    val id: String = newId(),
    @SerialName("elapsed_seconds") val elapsedSeconds: Int,
    val slot: Int,
    val type: String,
    val delta: Int,
)

/** A finished game in `games.json`, field for field the iOS `GameRecord`. */
@Serializable
data class GameRecord(
    val id: String = newId(),
    @Serializable(with = SwiftDateSerializer::class) val date: Long,
    @SerialName("deck_id") val deckId: String? = null,
    @SerialName("deck_name") val deckName: String? = null,
    val opponent: String = "",
    val result: String,
    @SerialName("duration_seconds") val durationSeconds: Int,
    val events: List<ScoreEvent> = emptyList(),
    @SerialName("started_first") val startedFirst: Boolean? = null,
)

/** `games.json`, newest first. Unreadable files are kept aside by [Documents.read]. */
class GameRecordStore(private val docs: Documents) {
    private val serializer = ListSerializer(GameRecord.serializer())

    var records: List<GameRecord> = load()
        private set

    private fun load(): List<GameRecord> =
        docs.read(FILE) { SwiftJson.decodeFromString(serializer, it) }?.sortedByDescending { it.date } ?: emptyList()

    fun record(game: GameRecord) = save((records + game).sortedByDescending { it.date })

    fun update(game: GameRecord) = save(records.map { if (it.id == game.id) game else it }.sortedByDescending { it.date })

    fun delete(id: String) = save(records.filterNot { it.id == id })

    private fun save(next: List<GameRecord>) {
        records = next
        docs.write(FILE, SwiftJson.encodeToString(serializer, next))
    }

    companion object {
        const val FILE = "games.json"
    }
}
