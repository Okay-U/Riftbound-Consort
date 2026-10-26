package pitopia.riftcount.events

import android.content.Context
import android.content.Intent
import androidx.core.net.toUri
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * Debug builds only (iOS `FakeLiveEvent`; release and staging get the stub in src/nondebug): a made-up live event
 * answered here instead of by PlayRiftbound, so match mode, Report and the event screens can be tried without a
 * live event (Okay, 2026-10-26). The Summoner Skirmish at "Spielwiese" has round 3 running with your table open;
 * stores, players and results are fictional. Settings › Debug switches it and restarts the app. Nothing is sent to
 * Riot: a mutation succeeds and switches the later answers to its `after-<Operation>/` files. Every time moves by
 * the moment the switch went on, so the round clock runs as at the table. Answers: assets/fake_compete of the debug
 * source set (tools/fake-live-event).
 */
object DebugEvents {
    /** Debug tools in this build: Settings › Debug (this switch, the PlayRiftbound log) and the log itself. */
    const val TOOLS = true

    private const val DIR = "fake_compete"
    private const val ON = "fakeLiveEvent"
    private const val SINCE = "fakeLiveEventSince"
    private const val APPLIED = "fakeLiveEventApplied"
    private val Stamp = Regex("""\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z""")
    private val Format = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").withZone(ZoneOffset.UTC)

    /** Its own file, written at once: the app restarts right after a switch. */
    private fun prefs(context: Context) = context.getSharedPreferences("debug_events", Context.MODE_PRIVATE)

    fun isOn(context: Context): Boolean = prefs(context).getBoolean(ON, false)

    /** On or off from a clean start (times from now, nothing reported yet), then a fresh app. */
    fun switch(context: Context, on: Boolean) {
        prefs(context).edit().putBoolean(ON, on).putLong(SINCE, System.currentTimeMillis()).putString(APPLIED, "").commit()
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return
        context.startActivity(Intent.makeRestartActivityTask(launch.component))
        Runtime.getRuntime().exit(0)
    }

    fun transport(context: Context): Transport {
        if (!isOn(context)) return HttpTransport
        val assets = context.assets
        val prefs = prefs(context)
        fun file(name: String): String? = runCatching { assets.open("$DIR/$name").bufferedReader().use { it.readText() } }.getOrNull()
        val session = file("session.json")?.let { runCatching { CompeteJson.parseToJsonElement(it).jsonObject }.getOrNull() }
        RiotSession.override = {
            Credentials("fake", null, session?.get("gameName")?.jsonPrimitive?.content, session?.get("tagLine")?.jsonPrimitive?.content)
        }
        val generated = file("_meta.json")?.let { meta ->
            runCatching { CompeteJson.parseToJsonElement(meta).jsonObject["generatedAt"]?.jsonPrimitive?.content }.getOrNull()?.let(IsoTime::parse)
        }
        val shift = generated?.let { prefs.getLong(SINCE, it) - it } ?: 0L
        fun moved(text: String) = if (shift == 0L) text else Stamp.replace(text) { m ->
            runCatching { Format.format(Instant.parse(m.value).plusMillis(shift)) }.getOrDefault(m.value)
        }
        return Transport { method, url, _, body ->
            withContext(Dispatchers.IO) {
                if (!url.startsWith(RiftApi.ENDPOINT)) return@withContext 404 to ""
                val q = url.toUri()
                val operation = q.getQueryParameter("operationName")
                    ?: body?.let { CompeteJson.parseToJsonElement(it).jsonObject["operationName"]?.jsonPrimitive?.content }
                    ?: return@withContext 400 to ""
                val applied = prefs.getString(APPLIED, "").orEmpty().split(',').filter { it.isNotEmpty() }
                if (method == "POST") {
                    if (operation !in applied) prefs.edit().putString(APPLIED, (applied + operation).joinToString(",")).apply()
                    return@withContext 200 to """{"data":{}}"""
                }
                val id = q.getQueryParameter("variables")?.let { v ->
                    runCatching {
                        val o = CompeteJson.parseToJsonElement(v).jsonObject
                        (o["tournamentId"] ?: o["id"] ?: o["organizerId"])?.jsonPrimitive?.content
                    }.getOrNull()
                }
                val names = listOfNotNull(id?.let { "$operation-$it.json" }, "$operation.json")
                // The newest change first: after a report the event answers with the match reported.
                val text = names.firstNotNullOfOrNull { name ->
                    applied.reversed().firstNotNullOfOrNull { change -> file("after-$change/$name") } ?: file(name)
                }
                if (text == null) 404 to "" else 200 to moved(text)
            }
        }
    }
}
