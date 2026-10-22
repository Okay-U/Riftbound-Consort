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
    val sounds = Flag("soundsEnabled", false)
    val keepScreenOn = Flag("keepScreenOn", true)
    val trueBlack = Flag("trueBlack", true)
    val matchMode = Flag("matchModeEnabled", true)
    val shakeToRoll = Flag("diceShakeToRoll", true)
    val didOnboard = Flag("didOnboard", false)
    val didOnboardEvents = Flag("didOnboardEvents", false)
    val didSeeBuilderTip = Flag("didSeeBuilderTip", false)
}
