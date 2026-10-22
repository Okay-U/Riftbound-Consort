package pitopia.riftcount.cards

import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.text.Normalizer
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import pitopia.riftcount.data.Documents
import pitopia.riftcount.data.Prefs
import pitopia.riftcount.data.SwiftJson

private const val TAG = "CardStore"

/** GET with a timeout; null on 304 when [etag] still matches. */
internal fun httpGet(url: String, etag: String? = null, timeoutMs: Int = 60_000): Pair<String, String?>? {
    val conn = URL(url).openConnection() as HttpURLConnection
    try {
        conn.connectTimeout = 15_000
        conn.readTimeout = timeoutMs
        conn.useCaches = false
        conn.setRequestProperty("Accept", "application/json")
        etag?.let { conn.setRequestProperty("If-None-Match", it) }
        return when (val code = conn.responseCode) {
            HttpURLConnection.HTTP_NOT_MODIFIED -> null
            HttpURLConnection.HTTP_OK -> conn.inputStream.bufferedReader().use { it.readText() } to conn.getHeaderField("ETag")
            else -> throw IOException("HTTP $code")
        }
    } finally {
        conn.disconnect()
    }
}

/**
 * The card database: last snapshot first, then the hosted feed (ETag, 6 h refresh, 15 min after an error).
 * A feed that lost most cards is refused and the cards on screen stay, like iOS `CardStore`.
 */
class CardStore(private val docs: Documents, private val scope: CoroutineScope) {
    var cards by mutableStateOf<List<Card>>(emptyList())
        private set
    var legendNames by mutableStateOf<List<String>>(emptyList())
        private set
    /** Cards by id, for decks (they store ids). */
    var index by mutableStateOf<Map<String, Card>>(emptyMap())
        private set
    var loading by mutableStateOf(false)
        private set
    var error by mutableStateOf<String?>(null)
        private set
    /** Bumped on every publish: text, images or the preview flag can change while the count stays. */
    var revision by mutableIntStateOf(0)
        private set

    private var job: Job? = null
    private var nextCheckMs: Long? = null
    private val listSerializer = ListSerializer(Card.serializer())

    fun loadIfNeeded() { if (cards.isEmpty() && !loading) load() }

    /** Back in the foreground: check again once due (an unchanged feed answers 304). */
    fun refreshIfDue(nowMs: Long = System.currentTimeMillis()) {
        val due = nextCheckMs ?: return
        if (cards.isNotEmpty() && !loading && nowMs >= due) load()
    }

    fun load() {
        job?.cancel()
        job = scope.launch {
            if (cards.isEmpty()) withContext(Dispatchers.IO) { readSnapshot() }?.let(::publish)
            loading = cards.isEmpty()
            error = null
            try {
                val etag = if (cards.isEmpty()) null else Prefs.string(ETAG_KEY, "").ifEmpty { null }
                val fetched = withContext(Dispatchers.IO) {
                    httpGet(FEED, etag)?.let { (body, tag) -> SwiftJson.decodeFromString(CardPage.serializer(), body).items to tag }
                }
                nextCheckMs = System.currentTimeMillis() + REFRESH_MS
                if (fetched != null) {
                    val (items, tag) = fetched
                    if (!CardQuery.plausible(items, cards)) {
                        if (cards.isEmpty()) error = "The card list looks incomplete. Please try again later."
                    } else {
                        publish(items)
                        // The ETag only after its snapshot is on disk, else a 304 would keep a stale catalogue.
                        val ok = withContext(Dispatchers.IO) { runCatching { docs.write(SNAPSHOT, SwiftJson.encodeToString(listSerializer, items)) }.isSuccess }
                        if (ok && tag != null) Prefs.put(ETAG_KEY, tag)
                    }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.w(TAG, "card feed failed", e)
                if (cards.isEmpty()) error = "Could not reach the card database. Check your connection."
                nextCheckMs = System.currentTimeMillis() + RETRY_MS
            } finally {
                loading = false
            }
        }
    }

    private fun readSnapshot(): List<Card>? = docs.file(SNAPSHOT).takeIf { it.exists() }?.let { f ->
        runCatching { SwiftJson.decodeFromString(listSerializer, f.readText()) }.getOrNull()
    }

    private fun publish(items: List<Card>) {
        val unique = CardQuery.dedupe(items)
        cards = unique
        index = unique.associateBy { it.id }
        legendNames = CardQuery.legendNames(unique)
        revision++
    }

    companion object {
        const val FEED = "https://okay-u.github.io/cards.json"
        const val SNAPSHOT = "cards_cache_v2.json"
        private const val ETAG_KEY = "cardsFeedETag"
        private const val REFRESH_MS = 6 * 60 * 60 * 1000L
        private const val RETRY_MS = 15 * 60 * 1000L
    }
}

@Serializable
data class Erratum(val card: String, val key: String, val set: String? = null, val newText: String, val oldText: String? = null, val note: String? = null, val source: String)

@Serializable
data class ErrataDocument(val version: Int, val updated: String? = null, val entries: List<Erratum>)

/** Official text corrections from `errata.json`, refreshed once a day (by the cache file's age). */
class ErrataStore(private val docs: Documents, private val scope: CoroutineScope) {
    var byKey by mutableStateOf<Map<String, Erratum>>(emptyMap())
        private set

    fun load() = scope.launch {
        withContext(Dispatchers.IO) { read() }?.let(::apply)
        val f = docs.file(CACHE)
        if (f.exists() && System.currentTimeMillis() - f.lastModified() < DAY_MS) return@launch
        val fetched = withContext(Dispatchers.IO) {
            runCatching { httpGet(FEED)?.first?.let { SwiftJson.decodeFromString(ErrataDocument.serializer(), it) } }.getOrNull()
        } ?: return@launch
        apply(fetched)
        withContext(Dispatchers.IO) { runCatching { docs.write(CACHE, SwiftJson.encodeToString(ErrataDocument.serializer(), fetched)) } }
    }

    fun forCard(card: Card): Erratum? = byKey[normalize(card.name)]

    private fun read() = docs.file(CACHE).takeIf { it.exists() }?.let { runCatching { SwiftJson.decodeFromString(ErrataDocument.serializer(), it.readText()) }.getOrNull() }

    private fun apply(doc: ErrataDocument) { byKey = doc.entries.associateBy { it.key } }

    companion object {
        const val FEED = "https://okay-u.github.io/errata.json"
        private const val CACHE = "errata_v1.json"
        private const val DAY_MS = 24 * 60 * 60 * 1000L

        /** iOS `ErrataStore.normalize`: no printing suffix, no accents, lower case, letters and digits only. */
        fun normalize(name: String): String =
            Normalizer.normalize(name.replace(Regex("\\s*\\([^)]*\\)\\s*$"), ""), Normalizer.Form.NFD)
                .replace(Regex("\\p{Mn}+"), "").lowercase().filter { it.isLetterOrDigit() }
    }
}
