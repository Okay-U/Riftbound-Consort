package pitopia.riftcount.settings

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.net.toUri
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import pitopia.riftcount.data.SwiftDateSerializer
import pitopia.riftcount.data.SwiftJson

/** Riot's rules documents (iOS `RulesLibrary`): every row opens Riot's own page, so nothing goes stale. */
object RulesLibrary {
    class Link(val title: String, val detail: String?, val url: String, val pdf: Boolean = false)
    class Section(val title: String, val links: List<Link>, val footer: String? = null)

    private const val CMS = "https://cmsassets.rgpub.io/sanity/files/dsfx7636/news_live/"
    private const val NEWS = "https://playriftbound.com/en-us/news/"

    val sections = listOf(
        Section(
            "Rules",
            listOf(
                Link("Rules Hub", "Riot's index of current rules documents", "https://playriftbound.com/en-us/rules-hub/"),
                Link("Core Rules", "The full rulebook", "${CMS}e9ac8e3d33e0f78cef296f5945aba7bc1313b086.pdf", pdf = true),
                Link("Tournament Rules", "Event procedure and penalties", "${CMS}503da65669ced10598d62925a6f6bc15111af726.pdf", pdf = true),
                Link("Bans & Restrictions", "Announcing Riftbound's first bans", "${NEWS}announcements/announcing-riftbounds-first-bans/"),
            ),
        ),
        Section(
            "Set FAQs",
            listOf(
                Link("Core Rules FAQ", null, "${CMS}e53e7f4dc1c258c5b203e044e538f101df2cb161.pdf", pdf = true),
                Link("Origins FAQ", null, "${NEWS}rules-and-releases/riftbound-origins-faq/"),
                Link("Spiritforged FAQ", null, "${NEWS}rules-and-releases/riftbound-spiritforged-faq/"),
                Link("Unleashed FAQ", null, "${NEWS}rules-and-releases/unleashed-rules-faq-and-clarifications/"),
                Link("Vendetta FAQ", null, "${NEWS}rules-and-releases/vendetta-rules-faq-and-clarifications/"),
            ),
        ),
        Section(
            "Core rules patch notes",
            listOf(
                Link("Core Rules", null, "${NEWS}rules-and-releases/riftbound-core-rules-patch-notes/"),
                Link("Spiritforged", null, "${NEWS}rules-and-releases/riftbound-core-rules-spiritforged-patch-notes/"),
                Link("Unleashed", null, "${NEWS}rules-and-releases/riftbound-core-rules-unleashed-patch-notes/"),
                Link("Vendetta", null, "${NEWS}announcements/core-rules-vendetta-patch-notes/"),
            ),
        ),
        Section(
            "Card errata",
            listOf(
                Link("Origins", "33 cards", "${NEWS}rules-and-releases/riftbound-origins-card-errata/"),
                Link("Spiritforged", "16 cards", "${NEWS}rules-and-releases/riftbound-spiritforged-errata/"),
                Link("Unleashed", "8 cards", "${NEWS}rules-and-releases/unleashed-errata-updates/"),
                Link("Vendetta", "8 cards", "${NEWS}announcements/vendetta-errata-updates/"),
            ),
            footer = "Errata'd cards are marked in the card database, with the corrected text on the card.",
        ),
    )
}

/** Outside apps: browser, mail, share sheet, Google Play. Each returns false when nothing could take it. */
object Support {
    const val EMAIL = "contact-okaydev@proton.me"
    const val KOFI = "https://ko-fi.com/okayunal"
    const val PRIVACY = "https://okay-u.github.io/privacy.html"

    // The store listing keeps the Skip app's id; debug builds only add a suffix to the installed one.
    private const val STORE_ID = "pitopia.Riftcount"
    private const val STORE_URL = "https://play.google.com/store/apps/details?id=$STORE_ID"

    fun open(context: Context, url: String): Boolean = start(context, Intent(Intent.ACTION_VIEW, url.toUri()))

    fun rate(context: Context): Boolean =
        start(context, Intent(Intent.ACTION_VIEW, "market://details?id=$STORE_ID".toUri())) || open(context, STORE_URL)

    fun share(context: Context): Boolean {
        val send = Intent(Intent.ACTION_SEND)
            .setType("text/plain")
            .putExtra(Intent.EXTRA_SUBJECT, "Riftcount: Score Tracker")
            .putExtra(Intent.EXTRA_TEXT, "Score tracker for Riftbound TCG. Check it out! $STORE_URL")
        return start(context, Intent.createChooser(send, null))
    }

    /**
     * The mail app with the report filled in (iOS `BugReportView` / `FeatureRequestView`), read before sending.
     * Address, subject and text ride in the mailto link as on iOS: Gmail ignores them as extras of SENDTO.
     * The extras stay for apps that read only those.
     */
    fun mail(context: Context, subject: String, body: String): Boolean {
        val link = "mailto:$EMAIL?subject=${Uri.encode(subject)}&body=${Uri.encode(body)}".toUri()
        val mail = Intent(Intent.ACTION_SENDTO, link)
            .putExtra(Intent.EXTRA_SUBJECT, subject)
            .putExtra(Intent.EXTRA_TEXT, body)
        return start(context, mail)
    }

    fun version(context: Context): String = runCatching {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        "${info.versionName} (${info.longVersionCode})"
    }.getOrDefault("?")

    fun reportBody(kind: String, summary: String, text: String, version: String): String =
        "Title: $summary\n\n$kind:\n${text.ifBlank { "-" }}\n\nRiftcount $version · Android ${Build.VERSION.RELEASE}"

    private fun start(context: Context, intent: Intent): Boolean = try {
        context.startActivity(intent)
        true
    } catch (_: ActivityNotFoundException) {
        false
    }
}

/** One call to PlayRiftbound as iOS `PlayRiftboundDiagnostics` writes it: never cookies, headers or responses. */
@Serializable
data class LogEntry(
    val id: String,
    @Serializable(with = SwiftDateSerializer::class) val date: Long,
    val operation: String,
    val method: String,
    val outcome: String,
    val detail: String? = null,
    val durationMs: Int,
) {
    val ok get() = outcome == "ok"
}

/** `playriftbound_log.json`, newest first; written in phase 5 by the PlayRiftbound client. */
class PlayRiftboundLog(private val file: File) {
    fun entries(): List<LogEntry> = runCatching {
        SwiftJson.decodeFromString(ListSerializer(LogEntry.serializer()), file.readText()).reversed()
    }.getOrDefault(emptyList())

    fun clear() {
        file.delete()
    }

    /** iOS `record`: one call, the last [LIMIT] kept; the detail is cut to 600 characters. */
    suspend fun record(operation: String, method: String, outcome: String, detail: String?, startedMs: Long) = withContext(Dispatchers.IO) {
        lock.withLock {
            val now = System.currentTimeMillis()
            val entry = LogEntry(
                UUID.randomUUID().toString().uppercase(), now, operation, method, outcome.take(120),
                detail?.take(600), (now - startedMs).toInt(),
            )
            val all = (runCatching { SwiftJson.decodeFromString(ListSerializer(LogEntry.serializer()), file.readText()) }.getOrDefault(emptyList()) + entry).takeLast(LIMIT)
            runCatching {
                file.parentFile?.mkdirs()
                val tmp = File(file.parentFile, file.name + ".tmp")
                tmp.writeText(SwiftJson.encodeToString(ListSerializer(LogEntry.serializer()), all))
                tmp.renameTo(file)
            }
        }
    }

    companion object {
        const val FILE = "playriftbound_log.json"
        private const val LIMIT = 150
        private val lock = Mutex()

        /** iOS `exportText`: a header, then one line per call, newest first. */
        fun export(entries: List<LogEntry>, version: String): String {
            val stamp = SimpleDateFormat("d MMM HH:mm:ss", Locale.US)
            val lines = entries.map { e ->
                "${stamp.format(Date(e.date))} ${e.method} ${e.operation} → ${e.outcome} (${e.durationMs} ms)" +
                    (e.detail?.let { "\n    $it" } ?: "")
            }
            return (listOf("Riftcount PlayRiftbound log · ${entries.size} entries · app $version") + lines).joinToString("\n")
        }
    }
}
