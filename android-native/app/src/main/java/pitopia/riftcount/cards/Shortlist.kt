package pitopia.riftcount.cards

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import pitopia.riftcount.data.Prefs

/**
 * Cards kept in mind for a deck (Okay's "Merkliste", 2026-10-22): saved from a card's Add to deck sheet,
 * found again in the builder and the Cards filter. Ids in the order added, kept across launches.
 */
object Shortlist {
    private const val KEY = "native.shortlist"

    var ids by mutableStateOf(Prefs.string(KEY, "").split(',').filter { it.isNotBlank() }.toSet())
        private set

    fun has(id: String) = id in ids

    /** Puts the card on or takes it off; true when it is on now. */
    fun toggle(id: String): Boolean {
        ids = if (id in ids) ids - id else ids + id
        Prefs.put(KEY, ids.joinToString(","))
        return id in ids
    }
}
