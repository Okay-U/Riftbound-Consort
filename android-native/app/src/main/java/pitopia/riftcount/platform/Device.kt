package pitopia.riftcount.platform

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.View
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.platform.LocalContext
import kotlin.math.sqrt
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

/** Calls [onShake] on a firm shake while [enabled]; listens only then. */
@Composable
fun ShakeEffect(enabled: Boolean, onShake: () -> Unit) {
    val context = LocalContext.current
    val latest = rememberUpdatedState(onShake)
    DisposableEffect(enabled) {
        val sensors = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        val accel = sensors?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        if (!enabled || sensors == null || accel == null) return@DisposableEffect onDispose {}
        var lastShake = 0L
        val listener = object : SensorEventListener {
            override fun onSensorChanged(e: SensorEvent) {
                val (x, y, z) = e.values
                val g = sqrt(x * x + y * y + z * z) / SensorManager.GRAVITY_EARTH
                if (g > SHAKE_G && e.timestamp - lastShake > SHAKE_GAP_NS) {
                    lastShake = e.timestamp
                    latest.value()
                }
            }
            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
        }
        sensors.registerListener(listener, accel, SensorManager.SENSOR_DELAY_UI)
        onDispose { sensors.unregisterListener(listener) }
    }
}

private const val SHAKE_G = 2.4f
private const val SHAKE_GAP_NS = 1_000_000_000L
