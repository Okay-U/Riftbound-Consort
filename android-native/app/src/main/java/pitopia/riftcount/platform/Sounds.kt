package pitopia.riftcount.platform

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.min
import kotlin.math.sin
import pitopia.riftcount.data.AppSettings

/** Soft clicks for points and the dice, made in code (no sound files). Silent while Sounds is off. */
object Sounds {
    private const val RATE = 44_100
    private const val LOUDNESS = 0.22f
    private val tracks = HashMap<Haptic, AudioTrack?>()

    fun play(kind: Haptic) {
        if (!AppSettings.sounds.on) return
        // A device that cannot build one (no audio output) stays silent instead of retrying every tap.
        if (kind !in tracks) tracks[kind] = runCatching { build(pcm(kind)) }.getOrNull()
        val track = tracks[kind] ?: return
        runCatching {
            // A static track plays once; rewinding lets the next point click again right away.
            if (track.playState == AudioTrack.PLAYSTATE_PLAYING) track.pause()
            track.reloadStaticData()
            track.play()
        }
    }

    /** Frequency (Hz) and length (ms) of each note. */
    private fun notes(kind: Haptic): List<Pair<Float, Int>> = when (kind) {
        Haptic.Tick -> listOf(1600f to 22)
        Haptic.Undo -> listOf(1050f to 26)
        Haptic.Warning -> listOf(520f to 70)
        Haptic.Success -> listOf(990f to 70, 1480f to 120)
    }

    /** Sine bursts with a 2 ms attack and an exponential tail, so nothing pops. */
    internal fun pcm(kind: Haptic): ShortArray {
        val out = ArrayList<Short>()
        for ((freq, ms) in notes(kind)) {
            val n = RATE * ms / 1000
            for (i in 0 until n) {
                val env = min(1f, i / (RATE * 0.002f)) * exp(-5f * i / n)
                out += (sin(2 * PI * freq * i / RATE).toFloat() * env * LOUDNESS * Short.MAX_VALUE).toInt().toShort()
            }
        }
        return out.toShortArray()
    }

    private fun build(pcm: ShortArray): AudioTrack =
        AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(RATE)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build(),
            )
            .setBufferSizeInBytes(pcm.size * 2)
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()
            .apply { write(pcm, 0, pcm.size) }
}
