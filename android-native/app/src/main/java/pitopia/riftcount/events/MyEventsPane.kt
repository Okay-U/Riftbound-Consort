package pitopia.riftcount.events

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.LifecycleResumeEffect
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.Rise
import pitopia.riftcount.ui.common.Toaster
import pitopia.riftcount.ui.theme.RiftType

/** The Events section: my registrations on PlayRiftbound (iOS `PlayRiftboundEventsView`, mock's Feed). */
@Composable
fun MyEventsPane(data: EventsData, active: Boolean, bottomReserve: Dp, toaster: Toaster, onOpen: (EvPage) -> Unit, onSite: (String?) -> Unit) {
    val scope = rememberCoroutineScope()
    val live = data.upcoming.firstOrNull(data::isLive)
    suspend fun prefetch() = data.prefetch((data.upcoming.filter(data::isLive) + data.upcoming + data.past.take(12)).map { it.tournament.id }.distinct())
    // Each time the section shows and on every resume: signing in on the PlayRiftbound section counts at once.
    LifecycleResumeEffect(active) {
        if (active) scope.launch {
            data.refresh(force = data.state == EventsData.State.SignedOut)
            prefetch()
        }
        onPauseOrDispose {}
    }
    LaunchedEffect(data.upcoming, data.past) { prefetch() }
    var reporting by remember { mutableStateOf<Pair<String, Pairing>?>(null) }

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 14.dp, bottom = bottomReserve + 30.dp)) {
        when (val state = data.state) {
            EventsData.State.Idle, EventsData.State.Loading -> Loading("Picking up your PlayRiftbound session")
            EventsData.State.SignedOut -> EmptyState(
                "Sign in on PlayRiftbound", "Your registered events show up here once you are signed in.", "Open PlayRiftbound",
            ) { onSite(RiftPolicy.HOME) }
            is EventsData.State.Failed -> EmptyState("Couldn't load events", state.message, "Retry") { scope.launch { data.refresh(force = true) } }
            EventsData.State.Loaded -> {
                FindPill { onOpen(EvPage.Search) }
                if (!data.hasEvents) {
                    EmptyState("No events yet", "Events you register for on PlayRiftbound show up here.", "Find an event") { onOpen(EvPage.Search) }
                    return@Column
                }
                live?.let { entry ->
                    val t = data.cached(entry.tournament.id)
                    val me = t?.let(data::playerId)
                    if (t == null || me == null || t.state(me) != PlayerState.Dropped) {
                        LiveCard(entry, t, me, onReport = { p -> reporting = entry.tournament.id to p }, onReported = { toaster.show("Already reported on PlayRiftbound") }) {
                            onOpen(EvPage.Event(entry))
                        }
                    }
                }
                val rest = data.upcoming.filter { it != live }
                Caption("Upcoming", data.upcoming.size.toString())
                rest.forEachIndexed { i, entry -> Rise(true, minOf(i, 8) * 50, Modifier.padding(bottom = 10.dp)) { UpcomingCard(data, entry) { onOpen(EvPage.Event(entry)) } } }
                if (data.past.isNotEmpty()) {
                    Caption("Past", data.past.size.toString())
                    data.past.forEachIndexed { i, entry -> Rise(true, minOf(i, 8) * 50, Modifier.padding(bottom = 10.dp)) { PastCard(data, entry) { onOpen(EvPage.Event(entry)) } } }
                }
            }
        }
    }
    reporting?.let { (id, pairing) ->
        ReportDialog(data, id, pairing, toaster::show) { reporting = null }
    }
}

@Composable
fun Loading(text: String) {
    Column(Modifier.fillMaxWidth().padding(vertical = 40.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Spinner()
        BasicText(text, Modifier.padding(top = 14.dp), style = Ev.Msg)
    }
}

/** `.findpill`. */
@Composable
fun FindPill(onClick: () -> Unit) {
    val shape = RoundedCornerShape(25.dp)
    Pressable(onClick, Modifier.fillMaxWidth(), pressedScale = 0.98f) {
        Row(
            Modifier.fillMaxWidth().height(50.dp).background(Color.White.copy(alpha = 0.06f), shape).border(1.dp, Color.White.copy(alpha = 0.14f), shape).padding(horizontal = 18.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Image(EvIcons.Search, null, colorFilter = ColorFilter.tint(Color.White.copy(alpha = 0.85f)))
            BasicText("Find events near you", style = RiftType.Body.copy(fontSize = 14.5.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.85f)))
        }
    }
}

/** The running round's clock as the site shows it: `startedAt` plus `roundDuration` (60 min when missing). */
class RoundClock(val text: String, val over: Boolean, val fraction: Float, val endsAt: Long)

fun roundClock(round: Tournament.Round?, now: Long): RoundClock? {
    val started = round?.startedAt ?: return null
    val end = round.endsAt ?: return null
    val total = end - started
    val left = ((end - now) / 1000).toInt()
    val over = left < 0
    return RoundClock(if (over) "+" + Fmt.clock(-left) else Fmt.clock(left), over, ((now - started).toFloat() / total).coerceIn(0f, 1f), end)
}

/** Ticks every second while [running]. */
@Composable
fun rememberNow(running: Boolean): Long {
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(running) {
        while (running) {
            now = System.currentTimeMillis()
            delay(1000)
        }
    }
    return now
}

private val LiveShape = RoundedCornerShape(26.dp)

/** `.live`: the event running now, its round clock and the player's table, with Report. */
@Composable
private fun LiveCard(entry: TournamentEntry, t: Tournament?, me: String?, onReport: (Pairing) -> Unit, onReported: () -> Unit, onOpen: () -> Unit) {
    val round = t?.rounds?.lastOrNull()
    val pairing = if (t != null && me != null) Pairing.latest(t, me) else null
    val running = round != null && round.startedAt != null && round.matches.any { !it.isComplete }
    Rise(true, 0, Modifier.padding(top = 14.dp)) {
        Pressable(onOpen, Modifier.fillMaxWidth(), pressedScale = 0.98f, label = "Open the live event", contentAlignment = Alignment.TopStart) {
            Column(
                Modifier.fillMaxWidth()
                    .dropShadow(LiveShape, Shadow(30.dp, Ev.Green.copy(alpha = 0.12f)))
                    .background(Color(0xFF0B0B0B), LiveShape)
                    .background(Brush.radialGradient(listOf(Ev.Green.copy(alpha = 0.16f), Color.Transparent), center = Offset.Zero, radius = 600f), LiveShape)
                    .border(1.dp, Ev.Green.copy(alpha = 0.5f), LiveShape)
                    .padding(16.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Box(Modifier.size(8.dp).dropShadow(CircleShape, Shadow(10.dp, Ev.Green)).background(Ev.Green, CircleShape))
                    BasicText("LIVE NOW", style = RiftType.Body.copy(fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.16.em, color = Ev.Green))
                }
                BasicText(entry.tournament.name, Modifier.padding(top = 8.dp), style = Ev.Display.copy(fontSize = 26.sp, lineHeight = 26.sp, color = Color.White))
                BasicText(
                    listOfNotNull(entry.organizer?.name, entry.tournament.startsAt?.let(Fmt::time)).joinToString(" • "),
                    Modifier.padding(top = 4.dp), style = RiftType.Body.copy(fontSize = 13.sp, color = Color.White.copy(alpha = 0.66f)),
                )
                if (running) LiveClock(round)
                Row(Modifier.fillMaxWidth().padding(top = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                    BasicText(
                        when {
                            pairing == null -> "Your pairing shows here once round 1 is up"
                            pairing.isBye -> "Bye this round"
                            pairing.isComplete -> "Reported · ${pairing.mySide} ${pairing.scoreText ?: ""}".trim()
                            else -> "${pairing.mySide} vs ${pairing.opponentName ?: "?"}"
                        },
                        Modifier.weight(1f),
                        style = RiftType.Body.copy(fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Color.White),
                    )
                    pairing?.let { p ->
                        BasicText(
                            (p.roundTitle + (p.tableNumber?.let { " · Table $it" } ?: "")).uppercase(),
                            style = RiftType.Body.copy(fontSize = 11.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.12.em, color = Color.White.copy(alpha = 0.6f)),
                        )
                    }
                }
                Row(Modifier.padding(top = 14.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    when {
                        pairing?.isReportable == true -> EvButton("Report", BtnKind.Green, Modifier.weight(1f)) { onReport(pairing) }
                        pairing != null && pairing.isComplete && !pairing.isBye -> EvButton("Reported", BtnKind.Green, Modifier.weight(1f), onClick = onReported)
                        else -> Unit
                    }
                    EvButton("Open event", BtnKind.Ghost, Modifier.weight(1f), onClick = onOpen)
                }
            }
        }
    }
}

/** The live card's clock; ticks in its own scope so the card around it does not redraw every second. */
@Composable
private fun LiveClock(round: Tournament.Round) {
    val clock = roundClock(round, rememberNow(true)) ?: return
    val ink = if (clock.over) Ev.Red else Color.White
    Row(Modifier.padding(top = 14.dp), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        BasicText(clock.text, style = Ev.Display.copy(fontSize = 52.sp, lineHeight = 52.sp, color = ink, fontFeatureSettings = "tnum"))
        BasicText(
            if (clock.over) "TIME OVER" else "LEFT · ENDS ${Fmt.time(clock.endsAt)}",
            Modifier.padding(bottom = 6.dp),
            style = RiftType.Body.copy(fontSize = 12.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.12.em, color = Color.White.copy(alpha = 0.66f)),
        )
    }
    Rail(clock.fraction, ink, Modifier.padding(top = 10.dp))
}

/** `.rail`: the round clock's 4dp track, filled as time passes. */
@Composable
fun Rail(fraction: Float, color: Color, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().height(4.dp).background(Color.White.copy(alpha = 0.1f), RoundedCornerShape(2.dp))) {
        Box(Modifier.fillMaxHeight().fillMaxWidth().graphicsLayer {
            scaleX = fraction
            transformOrigin = TransformOrigin(0f, 0.5f)
        }.background(color, RoundedCornerShape(2.dp)))
    }
}

@Composable
private fun UpcomingCard(data: EventsData, entry: TournamentEntry, onClick: () -> Unit) {
    val s = entry.tournament
    val t = data.cached(s.id)
    val state = t?.let { tt -> data.playerId(tt)?.let(tt::state) } ?: PlayerState.None
    val fav = entry.organizer?.let { o -> if (data.favoritesSignedIn == true) data.isFavorite(o.id) else o.isFavorited == true } == true
    EvRowCard(onClick, label = "Open ${s.name}") {
        DateBadge(s.startsAt)
        EventInfo(s.name, Fmt.formatLine(s.config?.format, s.config?.playerFormat, s.config?.tournamentType), Fmt.storeLine(entry.organizer), fav) {
            EvPill(Fmt.price(s.entryFee, s.pricing))
            EvPill(Fmt.players(s.registeredCount, s.config?.participantCapacity))
            StatusPill(state, data.isLive(entry))
        }
    }
}

/** A past event: where the player finished, their Swiss record, the store. */
@Composable
private fun PastCard(data: EventsData, entry: TournamentEntry, onClick: () -> Unit) {
    val s = entry.tournament
    val t = data.cached(s.id)
    val team = t?.let { tt -> data.playerId(tt)?.let(tt::teamId) }
    val placement = team?.let { t.placement(it) }
    val standing = team?.let { t.finalSwissStanding(it) }
    val (place, crown) = when (placement) {
        is Placement.Rank -> Fmt.ordinal(placement.n) to (placement.n == 1)
        is Placement.Top -> "Top ${placement.n}" to false
        null -> "—" to false
    }
    EvRowCard(onClick, label = "Open ${s.name}") {
        Column(
            Modifier.width(60.dp).background(
                when {
                    crown -> Ev.Gold
                    placement != null -> Color.White.copy(alpha = 0.1f)
                    else -> Color.White.copy(alpha = 0.04f)
                },
                RoundedCornerShape(16.dp),
            ).padding(vertical = 10.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            val ink = if (crown) Color.Black else Color.White
            BasicText(place, style = Ev.Display.copy(fontSize = if (place.length > 4) 17.sp else 24.sp, lineHeight = 24.sp, color = ink), maxLines = 1)
            s.startsAt?.let {
                BasicText("${Fmt.month(it)} ${Fmt.day(it)}", style = RiftType.Body.copy(fontSize = 9.5.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.12.em, color = ink))
            }
        }
        EventInfo(
            s.name,
            standing?.let { "${it.record} · ${it.matchPoints ?: 0} pts" } ?: Fmt.formatLine(s.config?.format, s.config?.playerFormat),
            Fmt.storeLine(entry.organizer),
            favoriteStore = false,
        )
    }
}
