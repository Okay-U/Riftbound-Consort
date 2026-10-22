package pitopia.riftcount.cards

import android.content.Context
import android.graphics.BitmapFactory
import android.util.Log
import android.util.LruCache
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.produceState
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.withContext

/**
 * Card art from Riot's image CDN. The grid asks the CDN for a WebP at tile width (about 20 KB instead of
 * the 780 KB PNG iOS loads); memory cache in front of a disk cache that survives restarts.
 */
object CardImages {
    private lateinit var dir: File
    private val downloads = Semaphore(6)
    private val memory = object : LruCache<String, ImageBitmap>((Runtime.getRuntime().maxMemory() / 8).toInt()) {
        override fun sizeOf(key: String, value: ImageBitmap) = value.width * value.height * 4
    }

    fun init(context: Context) {
        dir = File(context.cacheDir, "cards").apply { mkdirs() }
    }

    /** The CDN resizes on request; widths are bucketed so tiles of similar size share one file. */
    fun sized(url: String, widthPx: Int): String {
        if (!url.contains("rgpub.io")) return url
        val w = ((widthPx + 79) / 80 * 80).coerceIn(160, 800)
        return url + (if (url.contains('?')) "&" else "?") + "w=$w&fm=webp"
    }

    fun cached(url: String): ImageBitmap? = memory.get(url)

    suspend fun load(url: String): ImageBitmap? = memory.get(url) ?: withContext(Dispatchers.IO) {
        val file = File(dir, sha1(url))
        try {
            if (!file.exists()) downloads.withPermit { download(url, file) }
            BitmapFactory.decodeFile(file.path)?.asImageBitmap()?.also { memory.put(url, it) }
                ?: run { file.delete(); null }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.w("CardImages", "image failed", e)
            null
        }
    }

    private fun download(url: String, file: File) {
        val conn = URL(url).openConnection() as HttpURLConnection
        try {
            conn.connectTimeout = 15_000
            conn.readTimeout = 30_000
            if (conn.responseCode != HttpURLConnection.HTTP_OK) return
            // Own temp file: the tile and the detail hero can fetch the same image at once.
            val tmp = File.createTempFile(file.name, ".part", dir)
            conn.inputStream.use { input -> tmp.outputStream().use { input.copyTo(it) } }
            if (!tmp.renameTo(file)) tmp.delete()
        } finally {
            conn.disconnect()
        }
    }

    private fun sha1(s: String) = MessageDigest.getInstance("SHA-1").digest(s.toByteArray()).joinToString("") { "%02x".format(it) }
}

/** The card's art for a frame [widthPx] wide, null while it loads or when it cannot be fetched. */
@Composable
fun rememberCardArt(card: Card, widthPx: Int): State<ImageBitmap?> {
    // Landscape art (battlefields) is turned, so its long side fills the frame's height.
    val w = if (card.orientation.equals("landscape", true)) (widthPx / CARD_ASPECT).toInt() else widthPx
    val url = card.media?.imageUrl?.let { CardImages.sized(it, w) }
    return produceState(initialValue = url?.let(CardImages::cached), url) {
        // Another card in the same place (a new hand) starts from its own image, never the last card's.
        value = url?.let(CardImages::cached)
        if (url != null && value == null) value = CardImages.load(url)
    }
}
