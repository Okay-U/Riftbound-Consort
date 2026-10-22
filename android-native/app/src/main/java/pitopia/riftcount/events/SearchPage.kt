package pitopia.riftcount.events

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import pitopia.riftcount.data.Prefs
import pitopia.riftcount.ui.common.Rise
import pitopia.riftcount.ui.common.Toaster
import pitopia.riftcount.ui.theme.RiftType

/** The place the finders search around, saved under the iOS keys. */
object SearchPlace {
    var place: String
        get() = Prefs.string("riftSearchPlace", "")
        set(v) = Prefs.put("riftSearchPlace", v)
    var latitude: Double
        get() = Prefs.double("riftSearchLat", 0.0)
        set(v) = Prefs.put("riftSearchLat", v)
    var longitude: Double
        get() = Prefs.double("riftSearchLng", 0.0)
        set(v) = Prefs.put("riftSearchLng", v)
    var km: Int
        get() = Prefs.int("riftSearchKm", 50)
        set(v) = Prefs.put("riftSearchKm", v)
    val known get() = latitude != 0.0 || longitude != 0.0

    val DISTANCES = listOf(10, 25, 50, 100, 250)

    /**
     * City or address to coordinates through Photon (OpenStreetMap data), as the Skip app did; Android's own
     * geocoder is missing on phones without Google services. Nil when the place is unknown.
     */
    suspend fun geocode(text: String): Pair<Double, Double>? = withContext(Dispatchers.IO) {
        runCatching {
            val c = URL("https://photon.komoot.io/api/?q=${URLEncoder.encode(text, "UTF-8")}&limit=5").openConnection() as HttpURLConnection
            c.connectTimeout = 10_000
            c.readTimeout = 10_000
            c.setRequestProperty("User-Agent", "Riftcount-Android")
            try {
                if (c.responseCode != 200) return@runCatching null
                val json = CompeteJson.parseToJsonElement(c.inputStream.bufferedReader().use { it.readText() }).jsonObject
                pickPlace(json["features"]?.jsonArray?.map { it.jsonObject }.orEmpty())
            } finally {
                c.disconnect()
            }
        }.getOrNull()
    }
}

/** Larger places first; anything else after them. */
private val PlaceSizes = listOf("city", "town", "village", "suburb", "hamlet")

/**
 * The coordinates of Photon's answer. A bare name also matches smaller places called the same ("Munich" found a
 * village in North Dakota before München), so when the best hit is a place, the largest place among the hits wins;
 * an address keeps the best hit.
 */
internal fun pickPlace(features: List<JsonObject>): Pair<Double, Double>? {
    fun prop(f: JsonObject, key: String) = f["properties"]?.jsonObject?.get(key)?.jsonPrimitive?.contentOrNull
    fun isPlace(f: JsonObject) = prop(f, "osm_key") == "place"
    val top = features.firstOrNull() ?: return null
    val best = if (isPlace(top)) features.filter(::isPlace).minBy { f -> PlaceSizes.indexOf(prop(f, "osm_value")).let { if (it < 0) PlaceSizes.size else it } } else top
    val coords = best["geometry"]?.jsonObject?.get("coordinates")?.jsonArray
    val lng = coords?.getOrNull(0)?.jsonPrimitive?.doubleOrNull
    val lat = coords?.getOrNull(1)?.jsonPrimitive?.doubleOrNull
    return if (lat != null && lng != null) lat to lng else null
}

private val Types = listOf("LEARN_TO_PLAY" to "Learn to Play", "NEXUS_NIGHT" to "Nexus Night", "OPEN_PLAY" to "Open Play", "PRE_RIFT" to "Pre-Rift", "SUMMONER_SKIRMISH" to "Summoner Skirmish")
private val Formats = listOf("LIMITED_SEALED" to "Sealed", "LIMITED_DRAFT" to "Draft", "CONSTRUCTED" to "Constructed")
private val PlayerFormats = listOf("ONE_V_ONE" to "1v1", "TWO_V_TWO" to "2v2")

/** `.inp`: the place field; submits on the keyboard's search key. */
@Composable
fun PlaceField(value: String, onChange: (String) -> Unit, onSubmit: () -> Unit) {
    val focus = LocalFocusManager.current
    val source = remember { MutableInteractionSource() }
    val focused by source.collectIsFocusedAsState()
    val shape = RoundedCornerShape(24.dp)
    val style = RiftType.Body.copy(fontSize = 15.sp, color = Color.White)
    BasicTextField(
        value, onChange,
        Modifier.fillMaxWidth().height(48.dp).background(Color(0xFF0B0B0B), shape)
            .border(1.dp, if (focused) Ev.Green.copy(alpha = 0.6f) else Color.White.copy(alpha = 0.16f), shape),
        textStyle = style,
        singleLine = true,
        cursorBrush = SolidColor(Ev.Green),
        interactionSource = source,
        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Search, autoCorrectEnabled = false),
        keyboardActions = KeyboardActions(onSearch = { focus.clearFocus(); onSubmit() }),
        decorationBox = { inner ->
            Box(Modifier.padding(horizontal = 16.dp), contentAlignment = Alignment.CenterStart) {
                if (value.isEmpty()) BasicText("City or address", style = style.copy(color = Color.White.copy(alpha = 0.4f)))
                inner()
            }
        },
    )
}

/**
 * Find events (iOS `PlayRiftboundSearchView`, mock's search page): a place, a radius, the site's type /
 * format / player-count filters, favourites only, sorted by date or distance.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ColumnScope.SearchPage(data: EventsData, toaster: Toaster, onOpen: (EvPage) -> Unit) {
    val scope = rememberCoroutineScope()
    var draft by remember { mutableStateOf(SearchPlace.place) }
    var km by remember { mutableIntStateOf(SearchPlace.km) }
    var types by remember { mutableStateOf(emptySet<String>()) }
    var formats by remember { mutableStateOf(emptySet<String>()) }
    var players by remember { mutableStateOf(emptySet<String>()) }
    var favOnly by remember { mutableStateOf(false) }
    var sort by remember { mutableStateOf(RiftApi.Sort.DATE) }
    var results by remember { mutableStateOf(emptyList<TournamentEntry>()) }
    var next by remember { mutableStateOf<String?>(null) }
    var message by remember { mutableStateOf<String?>(if (SearchPlace.known) null else "Enter a city to find events nearby.") }
    var loading by remember { mutableStateOf(false) }
    var generation by remember { mutableIntStateOf(0) }

    fun filter() = RiftApi.SearchFilter(
        SearchPlace.latitude, SearchPlace.longitude, km * 1000,
        types.takeIf { it.isNotEmpty() }?.sorted(), formats.takeIf { it.isNotEmpty() }?.sorted(), players.takeIf { it.isNotEmpty() }?.sorted(), favOnly,
    )
    fun search() {
        if (!SearchPlace.known) return
        val request = ++generation
        loading = true
        scope.launch {
            try {
                val page = data.api.search(filter(), sort, RiotSession.publicCredentials())
                if (request != generation) return@launch
                results = page.nodes(TournamentEntry.serializer())
                next = page.nextCursor
                message = if (results.isEmpty()) "No events within $km km of ${SearchPlace.place}." else null
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                if (request == generation) message = e.message ?: "Couldn't search PlayRiftbound."
            } finally {
                if (request == generation) loading = false
            }
        }
    }
    fun locate() {
        val text = draft.trim()
        if (text.isEmpty()) return
        loading = true
        scope.launch {
            val found = SearchPlace.geocode(text)
            if (found == null) {
                loading = false
                message = "Couldn’t find “$text”."
                results = emptyList()
                return@launch
            }
            SearchPlace.place = text
            SearchPlace.latitude = found.first
            SearchPlace.longitude = found.second
            search()
        }
    }
    LaunchedEffect(Unit) { if (SearchPlace.known) search() }

    PlaceField(draft, { draft = it }, ::locate)
    FlowRow(Modifier.padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        SearchPlace.DISTANCES.forEach { d -> EvChip("$d km", km == d) { km = d; SearchPlace.km = d; search() } }
    }
    FlowRow(Modifier.padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        fun toggle(set: Set<String>, v: String) = if (v in set) set - v else set + v
        Types.forEach { (v, l) -> EvChip(l, v in types) { types = toggle(types, v); search() } }
        Formats.forEach { (v, l) -> EvChip(l, v in formats) { formats = toggle(formats, v); search() } }
        PlayerFormats.forEach { (v, l) -> EvChip(l, v in players) { players = toggle(players, v); search() } }
    }
    FlowRow(Modifier.padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        EvChip("By date", sort == RiftApi.Sort.DATE) { sort = RiftApi.Sort.DATE; search() }
        EvChip("By distance", sort == RiftApi.Sort.DISTANCE) { sort = RiftApi.Sort.DISTANCE; search() }
        if (data.signedIn) EvChip("\u2665\uFE0E Favourite stores only", favOnly) { favOnly = !favOnly; search() }
    }
    when {
        loading && results.isEmpty() -> Loading("Searching PlayRiftbound")
        message != null -> BasicText(message ?: "", Modifier.fillMaxWidth().padding(vertical = 26.dp, horizontal = 10.dp), style = Ev.Msg)
        else -> {
            Caption("${results.size} events · ${SearchPlace.place}")
            val registered = data.upcoming.map { it.tournament.id }.toSet()
            results.forEachIndexed { i, entry ->
                Rise(true, minOf(i, 8) * 50, Modifier.padding(bottom = 10.dp)) {
                    val s = entry.tournament
                    EvRowCard({ onOpen(EvPage.Event(entry)) }, label = "Open ${s.name}") {
                        DateBadge(s.startsAt)
                        EventInfo(s.name, Fmt.formatLine(s.config?.format, s.config?.playerFormat, s.config?.tournamentType), Fmt.storeLine(entry.organizer, entry.distanceMeters), entry.organizer?.isFavorited == true) {
                            EvPill(Fmt.price(s.entryFee, s.pricing))
                            EvPill(Fmt.players(s.registeredCount, s.config?.participantCapacity))
                            if (s.id in registered) EvPill("Registered", Ev.Green.copy(alpha = 0.16f), Ev.Green)
                        }
                    }
                }
            }
            next?.let { cursor ->
                EvButton("Load more", BtnKind.Ghost, Modifier.fillMaxWidth()) {
                    val request = generation
                    next = null
                    scope.launch {
                        runCatching { data.api.search(filter(), sort, RiotSession.publicCredentials(), after = cursor) }
                            .onSuccess { page ->
                                if (request != generation) return@onSuccess
                                val known = results.map { it.tournament.id }.toSet()
                                results = results + page.nodes(TournamentEntry.serializer()).filter { it.tournament.id !in known }
                                next = page.nextCursor
                            }
                            .onFailure {
                                if (it is CancellationException) throw it
                                if (request == generation) { next = cursor; toaster.show(it.message ?: "Couldn't load more") }
                            }
                    }
                }
            }
        }
    }
}
