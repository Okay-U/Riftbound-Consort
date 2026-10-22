package pitopia.riftcount.events

import android.content.Context
import android.content.pm.ApplicationInfo
import androidx.core.net.toUri
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * Debuggable builds only: recorded PlayRiftbound answers, so the Events screens can be tested on an emulator
 * without a Riot account. Active only while `files/Documents/fake_compete/` exists; release and staging
 * builds always talk to the network.
 *
 * Files: `session.json` (`{"gameName","tagLine"}`), `<Operation>.json`, `<Operation>-<tournament or store id>.json`.
 * A mutation answers success and, when `after-<Operation>/` exists, copies its files over the recorded ones.
 */
object DebugEvents {
    fun transport(context: Context, documents: File): Transport {
        val dir = File(documents, "fake_compete")
        val debuggable = context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        if (!debuggable || !dir.isDirectory) return HttpTransport
        RiotSession.override = {
            File(dir, "session.json").takeIf { it.exists() }?.let { f ->
                val o = runCatching { CompeteJson.parseToJsonElement(f.readText()).jsonObject }.getOrNull()
                Credentials("fake", null, o?.get("gameName")?.jsonPrimitive?.content, o?.get("tagLine")?.jsonPrimitive?.content)
            }
        }
        return Transport { method, url, _, body ->
            withContext(Dispatchers.IO) {
                if (!url.startsWith(RiftApi.ENDPOINT)) return@withContext 404 to ""
                val q = url.toUri()
                val operation = q.getQueryParameter("operationName")
                    ?: body?.let { CompeteJson.parseToJsonElement(it).jsonObject["operationName"]?.jsonPrimitive?.content }
                    ?: return@withContext 400 to ""
                if (method == "POST") {
                    File(dir, "after-$operation").listFiles()?.forEach { it.copyTo(File(dir, it.name), overwrite = true) }
                    return@withContext 200 to """{"data":{}}"""
                }
                val id = q.getQueryParameter("variables")?.let { v ->
                    runCatching {
                        val o = CompeteJson.parseToJsonElement(v).jsonObject
                        (o["tournamentId"] ?: o["id"])?.jsonPrimitive?.content
                    }.getOrNull()
                }
                val file = listOfNotNull(id?.let { File(dir, "$operation-$it.json") }, File(dir, "$operation.json")).firstOrNull { it.exists() }
                if (file == null) 404 to "" else 200 to file.readText()
            }
        }
    }
}
