package pitopia.riftcount.data

import android.util.Log
import java.io.File
import java.util.UUID
import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json

/**
 * The JSON files the iOS and Skip apps keep in `Documents/`, read and written in exactly their format:
 * compact, nil fields left out, defaults written, unknown keys ignored.
 */
val SwiftJson = Json {
    ignoreUnknownKeys = true
    explicitNulls = false
    encodeDefaults = true
    coerceInputValues = true
}

/** Swift's default `Date` coding: seconds since 2001-01-01Z as a Double. Kotlin side is epoch millis. */
object SwiftDateSerializer : KSerializer<Long> {
    private const val REFERENCE_EPOCH_SECONDS = 978_307_200.0
    override val descriptor = PrimitiveSerialDescriptor("SwiftDate", PrimitiveKind.DOUBLE)
    override fun serialize(encoder: Encoder, value: Long) =
        encoder.encodeDouble(value / 1000.0 - REFERENCE_EPOCH_SECONDS)
    override fun deserialize(decoder: Decoder): Long =
        ((decoder.decodeDouble() + REFERENCE_EPOCH_SECONDS) * 1000.0).toLong()
}

/** Swift encodes UUIDs upper case. */
fun newId(): String = UUID.randomUUID().toString().uppercase()

/** `filesDir/Documents`, the directory the Skip app resolved `.documentDirectory` to. */
class Documents(private val dir: File) {
    fun file(name: String) = File(dir, name)

    /** Write through a temp file and rename, like Swift's `.atomic`. */
    fun write(name: String, text: String) {
        dir.mkdirs()
        val tmp = File(dir, "$name.tmp")
        tmp.writeText(text)
        if (!tmp.renameTo(file(name))) {
            file(name).writeText(text)
            tmp.delete()
        }
    }

    /**
     * Reads [name] with [decode]. A file that exists but cannot be decoded is copied aside once
     * (named by its own modification time, like iOS) so the next save cannot lose it; then null.
     */
    fun <T> read(name: String, decode: (String) -> T): T? {
        val f = file(name)
        if (!f.exists()) return null
        return runCatching { decode(f.readText()) }.getOrElse { error ->
            Log.e("Documents", "could not decode $name", error)
            val copy = File(dir, name.removeSuffix(".json") + ".unreadable-${f.lastModified() / 1000}.json")
            if (!copy.exists()) runCatching { f.copyTo(copy) }
            null
        }
    }
}
