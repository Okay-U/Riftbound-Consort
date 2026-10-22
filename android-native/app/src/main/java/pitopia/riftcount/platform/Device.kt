package pitopia.riftcount.platform

import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.View
import pitopia.riftcount.data.AppSettings

enum class Haptic { Tick, Success, Warning, Undo }

/** iOS `Haptics.*`, through the view so no vibrate permission is needed. Off when the setting is off. */
fun View.haptic(kind: Haptic) {
    if (!AppSettings.haptics.on) return
    val newer = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
    performHapticFeedback(
        when (kind) {
            Haptic.Tick -> HapticFeedbackConstants.KEYBOARD_TAP
            Haptic.Success -> if (newer) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.LONG_PRESS
            Haptic.Warning -> if (newer) HapticFeedbackConstants.REJECT else HapticFeedbackConstants.LONG_PRESS
            Haptic.Undo -> HapticFeedbackConstants.VIRTUAL_KEY
        },
    )
}
