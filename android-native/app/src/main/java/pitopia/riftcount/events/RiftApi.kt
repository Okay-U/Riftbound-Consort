package pitopia.riftcount.events

import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.Instant
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonObject
import pitopia.riftcount.settings.PlayRiftboundLog

/**
 * What can go wrong talking to PlayRiftbound; the message is what the screen shows (iOS `PlayRiftboundError`),
 * [logName] what the on-device log says (iOS case names; class names do not survive R8).
 */
sealed class RiftError(message: String, val logName: String) : Exception(message) {
    class NotSignedIn : RiftError("Sign in on PlayRiftbound first.", "notSignedIn")
    class SessionExpired : RiftError("Your PlayRiftbound session expired. Open the PlayRiftbound segment to refresh it.", "sessionExpired")
    class UnknownOperation(name: String) : RiftError("Unknown operation $name.", "unknownOperation($name)")
    class StaleIds : RiftError("PlayRiftbound changed. Update the app or try again later.", "staleOperationIDs")
    class Http(val code: Int) : RiftError("PlayRiftbound answered with status $code.", "http($code)")
    class GraphQL(messages: List<String>) : RiftError(messages.joinToString("\n"), "graphQL")
    class BadResponse : RiftError("Unexpected answer from PlayRiftbound.", "badResponse")
}

/**
 * Persisted-query ids by operation (the endpoint takes no free queries). Built-in ids from the site build
 * of 2026-10-20; `okay-u.github.io/playriftbound-ops.json` overrides them after a Riot deploy.
 */
class OperationIds(private val fetchFeed: suspend () -> Map<String, String>) {
    private val lock = Mutex()
    private var ids = BUILT_IN
    private var feed: Deferred<Map<String, String>>? = null
    // The fetch belongs to no caller (iOS: an unstructured Task): one that leaves early must not cancel it for all.
    private val scope = CoroutineScope(SupervisorJob())

    suspend fun id(operation: String): String? {
        // One feed fetch shared by every caller; the first calls wait for it (10 s at most, as on iOS)
        // instead of racing with old ids.
        val pending = lock.withLock { feed ?: scope.async { fetchFeed() }.also { feed = it } }
        val fetched = withTimeoutOrNull(10_000) { pending.await() }.orEmpty()
        return lock.withLock {
            if (fetched.isNotEmpty()) ids = ids + fetched
            ids[operation]
        }
    }

    /** Fetch the feed again on the next call (after Riot rejected an id). */
    suspend fun invalidate() = lock.withLock { feed = null }

    companion object {
        const val FEED = "https://okay-u.github.io/playriftbound-ops.json"

        val BUILT_IN = mapOf(
            "PlayerTournaments" to "b210fdb2100186e794cb96a3cd72b294dcc7ca9ae5733ad540141ac6a390be4d",
            "PlayerRegisteredTournamentIds" to "b224261bf00cb424c12a30d914d6216f898e665fefc4550d89cf02679b629b29",
            "GetCompeteTournamentForRiftboundPlayer" to "e56d6d93e4f8fa287557521535544350e5cc9baafd78ba69f9f592873b090e57",
            "GetCompeteRbRefreshPoller" to "459dbd58b231ad1767b999a1bf987836123ac86a0b5110e166de15b69723ba0d",
            "SubmitGameResults" to "4f304b3a523f27d1abde2291d1b9e836e7b524f9e455d70b548680170e91c430",
            // Beyond the reads and the report (docs/PLAYRIFTBOUND.md §4):
            "CompeteTournamentSearch" to "acbcbba681a9c9a8063f792f7d665ba1eda81b19528b6af19e523f0c2061bec2",
            "RegisterCompetePlayer" to "7372d50ddebea493bd6aefdfce20666c7030d272252c0714fdcb2f63a92f9089",
            "DeregisterCompetePlayer" to "c2c3984c2c050f1f9ab54e5fb373e99e645e91cf010ee4a681b80089826b63d2",
            "DropCompetePlayerFromTournament" to "de49d7c455017093075e79b537558ee398b84aceab36bb0e1e648a665967d95d",
            "FavoritedOrganizers" to "8186f58c21e12fb11f76e413ba2795d62baf8d21bc422575f3ea34d894edda2f",
            "FavoriteOrganizer" to "80740df75cd7148fae22aa75c6070f37a8f16467c992c1eb8fc4711926d0816d",
            "UnfavoriteOrganizer" to "8e20642289398a5a26a552089dd25ea5c8d81f3e197d4f0f3bd9d33f845b7fdf",
            "OrganizerSummary" to "9142e18241bb86a3b4c2692d899b31aaf61d11065ca8a259191aa9cc0a06ed57",
        )
    }
}

@Serializable
private class OpsFeed(val operations: Map<String, Entry> = emptyMap()) {
    @Serializable
    class Entry(val id: String = "")
}

/** One HTTP exchange; the network, or recorded answers in a debug build. */
fun interface Transport {
    /** Status code and body. */
    suspend fun send(method: String, url: String, headers: Map<String, String>, body: String?): Pair<Int, String>
}

/** Plain HttpURLConnection: no cookie jar of its own, redirects refused (the cookies are set by hand). */
object HttpTransport : Transport {
    override suspend fun send(method: String, url: String, headers: Map<String, String>, body: String?): Pair<Int, String> =
        withContext(Dispatchers.IO) {
            val c = URL(url).openConnection() as HttpURLConnection
            try {
                c.requestMethod = method
                c.instanceFollowRedirects = false
                c.connectTimeout = 20_000
                c.readTimeout = 20_000
                c.useCaches = false
                headers.forEach { (k, v) -> c.setRequestProperty(k, v) }
                if (body != null) {
                    c.doOutput = true
                    c.outputStream.use { it.write(body.toByteArray()) }
                }
                val code = c.responseCode
                val text = (if (code < 400) c.inputStream else c.errorStream)?.bufferedReader()?.use { it.readText() }.orEmpty()
                code to text
            } finally {
                c.disconnect()
            }
        }
}

/**
 * PlayRiftbound's GraphQL endpoint (iOS `PlayRiftboundAPI`): the player's own tournaments, one tournament,
 * their result report, plus search, registration and favourites. Every call lands in the on-device log
 * (operation, outcome, mutation ids; never cookies or responses).
 */
class RiftApi(private val transport: Transport, private val log: PlayRiftboundLog, private val appVersion: String) {
    val ids = OperationIds { fetchFeed() }

    // --- reads and the report ----------------------------------------------------------------------

    suspend fun myTournaments(credentials: Credentials, upcoming: Int = 50, past: Int = 50): PlayerTournamentsData =
        query("PlayerTournaments", buildJsonObject { put("upcomingFirst", upcoming); put("pastFirst", past) }, credentials, PlayerTournamentsData.serializer())

    suspend fun tournament(id: String, credentials: Credentials): Tournament? =
        query("GetCompeteTournamentForRiftboundPlayer", buildJsonObject { put("tournamentId", id) }, credentials, TournamentsData.serializer())
            .competeTournaments.firstOrNull()

    /** One game of a report: a winner, or a draw. Shape recovered from the gateway's validation (docs). */
    class GameResult(val gameId: String, val draw: Boolean, val winnerParticipantId: String?)

    suspend fun submitGameResults(tournamentId: String, games: List<GameResult>, credentials: Credentials) {
        val input = buildJsonObject {
            put("esportsTournamentId", tournamentId)
            put("games", buildJsonArray {
                games.forEach { g ->
                    add(buildJsonObject {
                        put("gameId", g.gameId)
                        put("draw", g.draw)
                        g.winnerParticipantId?.let { put("winnerParticipantId", it) }
                    })
                }
            })
        }
        mutate("SubmitGameResults", buildJsonObject { put("input", input) }, credentials)
    }

    // --- beyond the reads and the report ------------------------------------------------------------

    class SearchFilter(
        val latitude: Double,
        val longitude: Double,
        val distanceMeters: Int?,
        val types: List<String>? = null,
        val formats: List<String>? = null,
        val playerFormats: List<String>? = null,
        val favoritesOnly: Boolean = false,
    )

    enum class Sort { DATE, DISTANCE }

    /** Public; credentials only add `isFavorited` and the favourites filter. */
    suspend fun search(filter: SearchFilter, sort: Sort, credentials: Credentials?, after: String? = null, first: Int = 20): Connection {
        val vars = buildJsonObject {
            put("sport", "rb")
            put("first", first)
            after?.let { put("after", it) }
            putJsonObject("filter") {
                putJsonObject("rb") {
                    putJsonObject("coords") { put("latitude", filter.latitude); put("longitude", filter.longitude) }
                    // The site passes "now minus one hour" so running events stay listed.
                    put("startDate", Instant.now().minusSeconds(3600).toString())
                    filter.distanceMeters?.let { put("distanceMeters", it) }
                    filter.types?.let { put("types", strings(it)) }
                    filter.formats?.let { put("formats", strings(it)) }
                    filter.playerFormats?.let { put("playerFormats", strings(it)) }
                    if (filter.favoritesOnly) put("favoritedOrganizersOnly", true)
                }
            }
            putJsonObject("sortBy") { put("rb", sort.name) }
        }
        return query("CompeteTournamentSearch", vars, credentials, SearchData.serializer()).competeTournamentSearch
    }

    suspend fun register(tournamentId: String, credentials: Credentials) = mutate("RegisterCompetePlayer", tournamentVars(tournamentId), credentials)

    /** Before the event starts. */
    suspend fun deregister(tournamentId: String, credentials: Credentials) = mutate("DeregisterCompetePlayer", tournamentVars(tournamentId), credentials)

    /** Once rounds are running. */
    suspend fun drop(tournamentId: String, credentials: Credentials) = mutate("DropCompetePlayerFromTournament", tournamentVars(tournamentId), credentials)

    suspend fun favorites(credentials: Credentials): List<Organizer> =
        query("FavoritedOrganizers", JsonObject(emptyMap()), credentials, FavoritesData.serializer()).favoritedOrganizers

    suspend fun setFavorite(organizerId: String, on: Boolean, credentials: Credentials) =
        mutate(if (on) "FavoriteOrganizer" else "UnfavoriteOrganizer", buildJsonObject { put("organizerId", organizerId) }, credentials)

    /** Contact card and coordinates of a store. Public. */
    suspend fun organizer(id: String, credentials: Credentials?): OrganizerSummary? =
        query("OrganizerSummary", buildJsonObject { put("id", id) }, credentials, OrganizerSummaryData.serializer()).organizerSummary

    /** A store's upcoming events: the search centred on the store, kept to that organizer (iOS). */
    suspend fun storeEvents(organizerId: String, latitude: Double, longitude: Double, credentials: Credentials?): List<TournamentEntry> {
        val filter = SearchFilter(latitude, longitude, distanceMeters = 2000)
        val results = mutableListOf<TournamentEntry>()
        var after: String? = null
        for (page in 0 until 5) {
            val c = try {
                search(filter, Sort.DATE, credentials, after, first = 50)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                if (after == null) throw e
                break // a later page failed (also offline): keep the events already found
            }
            results += c.nodes(TournamentEntry.serializer()).filter { it.organizer?.id == organizerId }
            after = c.nextCursor ?: break
        }
        return results
    }

    private fun tournamentVars(id: String) = buildJsonObject { put("esportsTournamentId", id) }

    private fun strings(list: List<String>) = JsonArray(list.map { JsonPrimitive(it) })

    // --- transport ---------------------------------------------------------------------------------

    private fun extensions(id: String) = buildJsonObject { putJsonObject("persistedQuery") { put("version", 1); put("sha256Hash", id) } }

    /** Persisted query over GET, the way the site does it. */
    suspend fun <T> query(operation: String, variables: JsonObject, credentials: Credentials?, serializer: KSerializer<T>): T {
        val id = ids.id(operation) ?: throw RiftError.UnknownOperation(operation)
        fun enc(s: String) = URLEncoder.encode(s, "UTF-8")
        val url = "$ENDPOINT?operationName=${enc(operation)}&variables=${enc(variables.toString())}&extensions=${enc(extensions(id).toString())}"
        val data = send("GET", url, null, operation, credentials)
        return runCatching { CompeteJson.decodeFromJsonElement(serializer, data) }.getOrElse {
            log.record(operation, "GET", "decode", it.message?.take(300), System.currentTimeMillis())
            throw RiftError.BadResponse()
        }
    }

    /** Persisted mutation over POST; success is the absence of errors. */
    private suspend fun mutate(operation: String, variables: JsonObject, credentials: Credentials) {
        val id = ids.id(operation) ?: throw RiftError.UnknownOperation(operation)
        val body = buildJsonObject {
            put("operationName", operation)
            put("variables", variables)
            put("extensions", extensions(id))
        }.toString()
        send("POST", ENDPOINT, body, operation, credentials)
    }

    private suspend fun send(method: String, url: String, body: String?, operation: String, credentials: Credentials?): JsonElement {
        val started = System.currentTimeMillis()
        return try {
            perform(method, url, body, operation, credentials).also { log.record(operation, method, "ok", body, started) }
        } catch (e: RiftError) {
            // Mutation variables (ids only) go into the on-device log; GET query strings carry nothing a failure needs.
            log.record(operation, method, e.logName, listOfNotNull(body, e.message).joinToString("\n"), started)
            throw e
        } catch (e: java.io.IOException) {
            log.record(operation, method, "network", e.message, started)
            throw e
        }
    }

    private suspend fun perform(method: String, url: String, body: String?, operation: String, credentials: Credentials?): JsonElement {
        val headers = buildMap {
            put("Content-Type", "application/json")
            put("Accept", "application/json")
            put("apollographql-client-name", "Riftcount")
            put("apollographql-client-version", appVersion)
            if (method == "POST") put("Origin", "https://playriftbound.com")
            if (credentials != null) {
                if (credentials.isExpired) throw RiftError.SessionExpired()
                put("Cookie", credentials.cookieHeader)
                put("Authorization", "Cookie ${RiotSession.ACCESS}")
            }
        }
        val (code, text) = transport.send(method, url, headers, body)
        // Without a session a 401/403 is the gateway or CDN, not an expired sign-in.
        if (code == 401 || code == 403) throw if (credentials == null) RiftError.Http(code) else RiftError.SessionExpired()
        val envelope = runCatching { CompeteJson.decodeFromString(GraphQLEnvelope.serializer(), text) }.getOrElse {
            if (code !in 200..299) throw RiftError.Http(code)
            throw RiftError.BadResponse()
        }
        val errors = envelope.errors.orEmpty()
        if (errors.isNotEmpty()) {
            val codes = errors.mapNotNull { it.extensions?.code }
            if ("PERSISTED_QUERY_NOT_FOUND" in codes || "PERSISTED_QUERY_ID_REQUIRED" in codes) {
                ids.invalidate()
                throw RiftError.StaleIds()
            }
            if ("UNAUTHENTICATED" in codes || errors.any { it.message.contains("jwt", true) && it.message.contains("expired", true) }) {
                throw RiftError.SessionExpired()
            }
            throw RiftError.GraphQL(errors.map { it.message })
        }
        return envelope.data ?: throw RiftError.BadResponse()
    }

    /** Built-in ids stay in force when this fails; the feed is an accelerator, not a dependency. */
    private suspend fun fetchFeed(): Map<String, String> = runCatching {
        val (code, text) = transport.send("GET", OperationIds.FEED, mapOf("Accept" to "application/json"), null)
        if (code != 200) return@runCatching emptyMap()
        CompeteJson.decodeFromString(OpsFeed.serializer(), text).operations.mapValues { it.value.id }.filterValues { it.length == 64 }
    }.getOrDefault(emptyMap())

    companion object {
        const val ENDPOINT = "https://playriftbound.com/api/gql"
    }
}
