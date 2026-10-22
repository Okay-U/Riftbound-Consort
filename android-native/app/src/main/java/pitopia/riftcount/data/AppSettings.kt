package pitopia.riftcount.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/** A switch the UI observes, saved under its iOS key on every change. */
class Flag(private val key: String, default: Boolean) {
    private var state by mutableStateOf(Prefs.bool(key, default))

    var on: Boolean
        get() = state
        set(value) {
            state = value
            Prefs.put(key, value)
        }
}

/** The switches of Settings and the tours, iOS defaults. First used after [Prefs.init]. */
object AppSettings {
    val haptics = Flag("hapticsEnabled", true)
    val keepScreenOn = Flag("keepScreenOn", true)
    val trueBlack = Flag("trueBlack", true)
    val matchMode = Flag("matchModeEnabled", true)
    val didOnboard = Flag("didOnboard", false)
    val didOnboardEvents = Flag("didOnboardEvents", false)
    val didSeeBuilderTip = Flag("didSeeBuilderTip", false)
    /** The deck detail shows main and side as a list instead of the card gallery; the gallery by energy, not type. */
    val deckList = Flag("native.deckList", false)
    val deckByEnergy = Flag("native.deckByEnergy", false)
}
