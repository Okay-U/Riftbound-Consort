package pitopia.riftcount.events

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.LifecycleResumeEffect
import java.util.Calendar
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.Toaster
import pitopia.riftcount.ui.common.softBlur
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

/** Start of the day [ms] falls on, local time. */
fun dayStart(ms: Long): Long = Calendar.getInstance().apply {
    timeInMillis = ms
    set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
}.timeInMillis

fun sameDay(a: Long, b: Long) = dayStart(a) == dayStart(b)

/** One store found by the finder: its nearest event distance, how many events, the next one. */
private class StoreHit(val organizer: Organizer, val distanceMeters: Double?, val next: Long?, val count: Int)

/**
 * Stores (mock's B pane, iOS `PlayRiftboundStoresView` + calendar): the next two weeks at favourite stores and
 * the player's own events on a light rail, favourite store cards, and the store finder with a radius rail.
 */
@Composable
fun StoresPane(data: EventsData, active: Boolean, bottomReserve: Dp, toaster: Toaster, onSheet: (EvSheet) -> Unit, onOpen: (EvPage) -> Unit) {
    val scope = rememberCoroutineScope()
    LifecycleResumeEffect(active) {
        if (active) scope.launch {
            data.loadFavorites()
            data.loadCalendar()
        }
        onPauseOrDispose {}
    }
    val today = dayStart(System.currentTimeMillis())
    var picked by remember { mutableLongStateOf(today) }
    // The finder's place field sits low: the column ends above the keyboard so it can scroll into view.
    val keyboard = WindowInsets.ime.asPaddingValues().calculateBottomPadding()
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 14.dp, bottom = maxOf(bottomReserve, keyboard) + 30.dp)) {
        Caption("Next two weeks · favourites and yours", top = 4.dp) {
            Pressable({ onSheet(EvSheet.Month) }, pressedScale = 0.95f, label = "Open the month") {
                BasicText("MONTH", style = RiftType.Body.copy(fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.16.em, color = Ev.Green))
            }
        }
        DayRail(data.calendar, today, picked) { picked = it }
        DayList(data.calendar.filter { sameDay(it.startsAt, picked) }, picked) { onOpen(EvPage.Event(it.entry)) }
        if (data.calendarFailedStores > 0) {
            BasicText("Couldn't load the events of ${data.calendarFailedStores} favourite store${if (data.calendarFailedStores == 1) "" else "s"}.", Modifier.padding(top = 8.dp), style = Ev.Muted)
        }
        if (data.favoritesSignedIn == true) {
            Caption("Favourite stores")
            if (data.favorites.isEmpty()) {
                BasicText("Tap the heart on a store to keep it here.", Modifier.fillMaxWidth().padding(vertical = 14.dp), style = Ev.Msg)
            } else {
                Row(Modifier.fillMaxWidth().bleed(16.dp).horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    data.favorites.forEach { store ->
                        val next = data.calendar.firstOrNull { it.entry.organizer?.id == store.id && it.startsAt >= today }
                        FavoriteCard(store, next?.startsAt) { onSheet(EvSheet.Store(store)) }
                    }
                }
            }
        }
        Caption("Find stores")
        StoreFinder(data, toaster) { onSheet(EvSheet.Store(it)) }
    }
}

private const val STEP = 52

/** The 14-day light rail: a node per day, filled where you play, ringed where a favourite store has an event. */
@Composable
private fun DayRail(items: List<EventsData.CalEvent>, today: Long, picked: Long, onPick: (Long) -> Unit) {
    val days = (0 until 14).map { today + it * 86_400_000L + 3_600_000L }.map(::dayStart)
    Box(Modifier.fillMaxWidth().bleed(16.dp).height(96.dp).horizontalScroll(rememberScrollState())) {
        Box(Modifier.width((30 + 13 * STEP + 30).dp).height(96.dp)) {
            Box(Modifier.offset(x = 30.dp, y = 44.dp).width((13 * STEP).dp).height(3.dp).background(Color.White.copy(alpha = 0.12f), RoundedCornerShape(2.dp)))
            days.forEachIndexed { i, day ->
                val evs = items.filter { sameDay(it.startsAt, day) }
                val reg = evs.any { it.registered }
                val on = sameDay(day, picked)
                val scale by animateFloatAsState(if (on) 1.3f else 1f, tween(400, easing = RiftEase), label = "node")
                val ink by animateColorAsState(if (on) Color.White else Color.White.copy(alpha = 0.55f), tween(300), label = "dayInk")
                Pressable(
                    { onPick(day) },
                    Modifier.offset(x = (30 + i * STEP - 22).dp).width(44.dp).height(96.dp)
                        .semantics { contentDescription = "${Fmt.weekday(day)} ${Fmt.day(day)}" + if (evs.isEmpty()) "" else ", ${evs.size} events"; selected = on },
                    pressedScale = 0.94f,
                    contentAlignment = Alignment.TopCenter,
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        BasicText(Fmt.weekday(day).uppercase().take(2), style = RiftType.Body.copy(fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.1.em, color = Color.White.copy(alpha = 0.5f)))
                        Box(
                            Modifier.padding(top = 14.dp).size(14.dp).graphicsLayer { scaleX = scale; scaleY = scale }
                                .let { if (on) it.dropShadow(CircleShape, Shadow(1.dp, Color.White.copy(alpha = 0.15f), spread = 5.dp)) else it }
                                .let { if (reg) it.dropShadow(CircleShape, Shadow(12.dp, Ev.Green.copy(alpha = 0.8f))) else it }
                                .background(if (reg) Ev.Green else if (evs.isNotEmpty()) Color.Black else Color.White.copy(alpha = 0.14f), CircleShape)
                                .let { if (!reg && evs.isNotEmpty()) it.border(2.dp, Ev.Green, CircleShape) else it },
                        )
                        BasicText(Fmt.day(day), Modifier.padding(top = 10.dp), style = Ev.Display.copy(fontSize = 17.sp, lineHeight = 17.sp, color = ink))
                    }
                }
            }
        }
    }
}

/** The picked day's events; slides in from the right out of a blur when the day changes (mock's `itemIn`). */
@Composable
fun DayList(items: List<EventsData.CalEvent>, day: Long, onOpen: (EventsData.CalEvent) -> Unit) {
    val t = remember { Animatable(1f) }
    LaunchedEffect(day) {
        t.snapTo(0f)
        t.animateTo(1f, tween(600, easing = RiftEase))
    }
    Column(
        Modifier.fillMaxWidth().graphicsLayer {
            val v = t.value
            alpha = v
            translationX = 14.dp.toPx() * (1f - v)
            val b = 8.dp.toPx() * (1f - v)
            renderEffect = softBlur(b)
        },
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (items.isEmpty()) BasicText("Nothing at your favourite stores that day.", Modifier.fillMaxWidth().padding(vertical = 18.dp), style = Ev.Msg)
        items.forEach { e ->
            val s = e.entry.tournament
            UCard(s.name, "${s.startsAt?.let(Fmt::time) ?: ""} · ${Fmt.storeLine(e.entry.organizer).orEmpty()}", onClick = { onOpen(e) }) {
                EvPill(Fmt.price(s.entryFee, s.pricing))
                if (e.registered) EvPill("Registered", Ev.Green.copy(alpha = 0.16f), Ev.Green)
            }
        }
    }
}

private val UShape = RoundedCornerShape(20.dp)

/** `.ucard`: a compact event card (name, time and store, pills). */
@Composable
fun UCard(name: String, sub: String, onClick: () -> Unit, pills: @Composable () -> Unit = {}) {
    Pressable(onClick, Modifier.fillMaxWidth(), pressedScale = 0.98f, label = "Open $name", contentAlignment = Alignment.TopStart) {
        Column(
            Modifier.fillMaxWidth().background(Ev.Card, UShape).border(1.dp, Ev.Ring, UShape).padding(horizontal = 14.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            BasicText(name, style = RiftType.Body.copy(fontSize = 15.5.sp, lineHeight = 18.6.sp, fontWeight = FontWeight.Bold, color = Color.White), maxLines = 2, overflow = TextOverflow.Ellipsis)
            BasicText(sub, style = Ev.Muted, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { pills() }
        }
    }
}

private val FavShape = RoundedCornerShape(22.dp)

/** `.fcard`: a favourite store with its next event. */
@Composable
private fun FavoriteCard(store: Organizer, next: Long?, onClick: () -> Unit) {
    Pressable(onClick, Modifier.width(200.dp), pressedScale = 0.97f, label = "Open ${store.name}", contentAlignment = Alignment.TopStart) {
        Column(
            Modifier.fillMaxWidth().background(Ev.Card, FavShape)
                .background(Brush.radialGradient(listOf(Ev.Green.copy(alpha = 0.12f), Color.Transparent), center = Offset(560f, 0f), radius = 520f), FavShape)
                .border(1.dp, Color.White.copy(alpha = 0.1f), FavShape).padding(14.dp),
        ) {
            Image(EvIcons.HeartFilled, null, Modifier.size(18.dp), colorFilter = ColorFilter.tint(Ev.Green))
            // Two lines kept for every name, so the cards stand the same height side by side.
            BasicText(store.name, Modifier.padding(top = 8.dp), style = Ev.Display.copy(fontSize = 22.sp, lineHeight = 22.sp, color = Color.White), maxLines = 2, minLines = 2, overflow = TextOverflow.Ellipsis)
            BasicText(
                listOfNotNull(store.physicalAddress?.city, next?.let { "next ${Fmt.shortDate(it)}" } ?: "no events listed").joinToString(" · "),
                Modifier.padding(top = 4.dp), style = RiftType.Body.copy(fontSize = 12.sp, color = Color.White.copy(alpha = 0.6f)), maxLines = 1,
            )
        }
    }
}

/** The finder: a place, the radius light rail, stores with upcoming events nearest first (iOS). */
@Composable
private fun StoreFinder(data: EventsData, toaster: Toaster, onStore: (Organizer) -> Unit) {
    val scope = rememberCoroutineScope()
    var draft by remember { mutableStateOf(SearchPlace.place) }
    var km by remember { mutableIntStateOf(SearchPlace.km) }
    var hits by remember { mutableStateOf<List<StoreHit>?>(null) }
    var message by remember { mutableStateOf<String?>(if (SearchPlace.known) null else "Enter a city to see stores running events nearby.") }
    var loading by remember { mutableStateOf(false) }
    var generation by remember { mutableIntStateOf(0) }

    fun search() {
        if (!SearchPlace.known) return
        val request = ++generation
        loading = true
        scope.launch {
            try {
                val filter = RiftApi.SearchFilter(SearchPlace.latitude, SearchPlace.longitude, km * 1000)
                val seen = HashSet<String>()
                val nodes = mutableListOf<TournamentEntry>()
                var after: String? = null
                // Nearest first, up to 500 events: enough to reach the edge of the radius in a city.
                for (page in 0 until 10) {
                    val c = data.api.search(filter, RiftApi.Sort.DISTANCE, RiotSession.publicCredentials(), after, first = 50)
                    nodes += c.nodes(TournamentEntry.serializer()).filter { seen.add(it.tournament.id) }
                    after = c.nextCursor ?: break
                }
                if (request != generation) return@launch
                hits = nodes.groupBy { it.organizer?.id }.mapNotNull { (id, group) ->
                    val o = group.first().organizer ?: return@mapNotNull null
                    if (id == null) null else StoreHit(o, group.mapNotNull { it.distanceMeters }.minOrNull(), group.mapNotNull { it.tournament.startsAt }.minOrNull(), group.size)
                }.sortedBy { it.distanceMeters ?: Double.MAX_VALUE }
                message = if (hits.isNullOrEmpty()) "No stores with upcoming events within $km km of ${SearchPlace.place}." else null
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                if (request == generation) message = e.message ?: "Couldn't search PlayRiftbound."
            } finally {
                if (request == generation) loading = false
            }
        }
    }
    LaunchedEffect(Unit) { if (SearchPlace.known && hits == null) search() }

    PlaceField(draft, { draft = it }) {
        val text = draft.trim()
        if (text.isNotEmpty()) scope.launch {
            loading = true
            val found = SearchPlace.geocode(text)
            if (found == null) {
                loading = false
                hits = emptyList()
                message = "Couldn’t find “$text”."
                return@launch
            }
            SearchPlace.place = text
            SearchPlace.latitude = found.first
            SearchPlace.longitude = found.second
            search()
        }
    }
    RadiusRail(km) { km = it; SearchPlace.km = it; search() }
    when {
        loading && hits.isNullOrEmpty() -> Loading("Looking for stores")
        message != null -> BasicText(message ?: "", Modifier.fillMaxWidth().padding(vertical = 18.dp, horizontal = 10.dp), style = Ev.Msg)
        else -> {
            val shape = RoundedCornerShape(22.dp)
            Column(Modifier.padding(top = 12.dp).fillMaxWidth().background(Color.White.copy(alpha = 0.045f), shape).border(1.dp, Color.White.copy(alpha = 0.08f), shape)) {
                hits.orEmpty().forEachIndexed { i, hit ->
                    Pressable({ onStore(hit.organizer) }, Modifier.fillMaxWidth(), pressedScale = 0.99f, label = "Open ${hit.organizer.name}") {
                        Row(
                            Modifier.fillMaxWidth().height(60.dp).drawBehind {
                                if (i > 0) drawRect(Color.White.copy(alpha = 0.06f), Offset.Zero, Size(size.width, 1.dp.toPx()))
                            }.padding(horizontal = 14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                BasicText(hit.organizer.name, style = RiftType.Body.copy(fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Color.White), maxLines = 1)
                                BasicText(listOfNotNull(hit.organizer.physicalAddress?.city, hit.distanceMeters?.let { "%.0f km".format(it / 1000) }).joinToString(" • "), style = Ev.Muted, maxLines = 1)
                            }
                            EvPill("${hit.count}" + (hit.next?.let { " · next ${Fmt.shortDate(it)}" } ?: ""))
                        }
                    }
                }
            }
        }
    }
}

/** `.rad`: five stops on a line, the line lit up to the chosen radius. */
@Composable
private fun RadiusRail(km: Int, onPick: (Int) -> Unit) {
    val stops = SearchPlace.DISTANCES
    val index = stops.indexOf(km).coerceAtLeast(0)
    val fill by animateFloatAsState(index / (stops.size - 1f), tween(500, easing = RiftEase), label = "radius")
    BoxWithConstraints(Modifier.padding(start = 10.dp, end = 10.dp, top = 8.dp).fillMaxWidth().height(56.dp)) {
        val w = maxWidth
        Box(Modifier.offset(y = 16.dp).fillMaxWidth().height(3.dp).background(Color.White.copy(alpha = 0.12f), RoundedCornerShape(2.dp)))
        val shape = RoundedCornerShape(2.dp)
        Box(
            Modifier.offset(y = 16.dp).fillMaxWidth().height(3.dp)
                .graphicsLayer { scaleX = fill; transformOrigin = TransformOrigin(0f, 0.5f) }
                .dropShadow(shape, Shadow(10.dp, Ev.Green.copy(alpha = 0.8f))).background(Ev.Green, shape),
        )
        stops.forEachIndexed { i, d ->
            val on = i == index
            val lit = i <= index
            val scale by animateFloatAsState(if (on) 1.3f else 1f, tween(400, easing = RiftEase), label = "stop")
            Pressable(
                { onPick(d) },
                Modifier.offset(x = w * (i / (stops.size - 1f)) - 14.dp, y = 4.dp).width(28.dp).height(48.dp).semantics { contentDescription = "$d km"; selected = on },
                pressedScale = 0.9f,
                contentAlignment = Alignment.TopCenter,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(
                        Modifier.padding(top = 4.dp).size(16.dp).graphicsLayer { scaleX = scale; scaleY = scale }
                            .let { if (on) it.dropShadow(CircleShape, Shadow(14.dp, Ev.Green.copy(alpha = 0.8f), spread = 2.dp)) else it }
                            .background(if (lit) Ev.Green else Color.White.copy(alpha = 0.2f), CircleShape),
                    )
                    // The stop is 28dp; its label may run wider (the mock's nowrap overflow).
                    BasicText(
                        "$d km", Modifier.padding(top = 8.dp).wrapContentWidth(unbounded = true),
                        style = RiftType.Body.copy(fontSize = 10.5.sp, fontWeight = FontWeight.Bold, color = if (on) Color.White else Color.White.copy(alpha = 0.55f)),
                        maxLines = 1, softWrap = false,
                    )
                }
            }
        }
    }
}
