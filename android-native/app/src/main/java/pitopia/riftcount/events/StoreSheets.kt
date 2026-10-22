package pitopia.riftcount.events

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
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
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.core.net.toUri
import java.net.URLEncoder
import java.util.Calendar
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.Sheet
import pitopia.riftcount.ui.common.ToastHost
import pitopia.riftcount.ui.common.Toaster
import pitopia.riftcount.ui.theme.RiftType

private fun Context.openOutside(url: String): Boolean = try {
    startActivity(Intent(Intent.ACTION_VIEW, url.toUri()))
    true
} catch (_: ActivityNotFoundException) {
    false
}

/**
 * One store (iOS `PlayRiftboundStoreView`, mock's store sheet): contact rows from `OrganizerSummary`, the
 * favourite heart, and its upcoming events (the search centred on the store).
 */
@Composable
fun StoreSheet(data: EventsData, store: Organizer, toaster: Toaster, onOpen: (EvPage) -> Unit, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var summary by remember { mutableStateOf<OrganizerSummary?>(null) }
    var events by remember { mutableStateOf<List<TournamentEntry>?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(store.id) {
        data.loadFavorites()
        try {
            val credentials = runCatching { RiotSession.valid(data.browser) }.getOrNull()
            val s = data.api.organizer(store.id, credentials)
            summary = s
            val lat = s?.physicalAddress?.latitude ?: store.physicalAddress?.latitude
            val lng = s?.physicalAddress?.longitude ?: store.physicalAddress?.longitude
            if (lat == null || lng == null) {
                error = "This store has no location on PlayRiftbound, so its events can't be listed."
                events = emptyList()
            } else {
                events = data.api.storeEvents(store.id, lat, lng, credentials).sortedBy { it.tournament.startsAt ?: Long.MAX_VALUE }
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            error = e.message
            events = emptyList()
        }
    }
    Sheet(store.name, onDismiss, overlay = { ToastHost(toaster) }) {
        Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Column(Modifier.weight(1f)) {
                BasicText(store.name, style = Ev.Display.copy(fontSize = 26.sp, lineHeight = 26.sp, color = Color.White))
                (summary?.physicalAddress?.formattedAddress ?: store.physicalAddress?.formattedAddress)?.let {
                    BasicText(it, Modifier.padding(top = 6.dp, bottom = 12.dp), style = RiftType.Body.copy(fontSize = 13.sp, lineHeight = 19.sp, color = Color.White.copy(alpha = 0.7f)))
                }
            }
            if (data.favoritesSignedIn == true) {
                val fav = data.isFavorite(store.id)
                RoundIconButton(if (fav) "Remove from favourites" else "Add to favourites", {
                    scope.launch {
                        try {
                            data.toggleFavorite(store)
                            toaster.show(if (data.isFavorite(store.id)) "${store.name} is a favourite" else "${store.name} removed from favourites")
                            // A new favourite's events join the rail and the month.
                            if (data.isFavorite(store.id)) data.loadCalendar()
                        } catch (e: CancellationException) {
                            throw e
                        } catch (e: Exception) {
                            toaster.show(e.message ?: "Couldn't change the favourite")
                        }
                    }
                }, enabled = store.id !in data.favoritePending) {
                    Image(if (fav) EvIcons.HeartFilled else EvIcons.Heart, null, Modifier.size(20.dp), colorFilter = ColorFilter.tint(if (fav) Ev.Green else Color.White))
                }
            }
        }
        summary?.let { s ->
            val rows = buildList {
                val lat = s.physicalAddress?.latitude
                val lng = s.physicalAddress?.longitude
                if (lat != null && lng != null) add(Triple("Directions", s.physicalAddress.city ?: "Map", "geo:$lat,$lng?q=$lat,$lng(${URLEncoder.encode(store.name, "UTF-8")})"))
                s.website?.takeIf { it.isNotBlank() }?.let { w -> add(Triple("Website", w.removePrefix("https://").removePrefix("http://"), if (w.startsWith("http")) w else "https://$w")) }
                s.email?.takeIf { it.isNotBlank() }?.let { add(Triple("Email", it, "mailto:$it")) }
                s.phone?.display?.let { p -> add(Triple("Phone", p, "tel:${p.filterNot(Char::isWhitespace)}")) }
            }
            if (rows.isNotEmpty()) {
                val shape = RoundedCornerShape(22.dp)
                Column(Modifier.fillMaxWidth().background(Color.White.copy(alpha = 0.045f), shape).border(1.dp, Color.White.copy(alpha = 0.08f), shape)) {
                    rows.forEachIndexed { i, (label, value, url) ->
                        Pressable({ if (!context.openOutside(url)) toaster.show("No app on this phone can open that") }, Modifier.fillMaxWidth(), pressedScale = 0.99f, label = "$label $value") {
                            Row(
                                Modifier.fillMaxWidth().height(54.dp).drawBehind {
                                    if (i > 0) drawRect(Color.White.copy(alpha = 0.06f), Offset.Zero, Size(size.width, 1.dp.toPx()))
                                }.padding(horizontal = 14.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                            ) {
                                BasicText(label, style = RiftType.Body.copy(fontSize = 14.5.sp, fontWeight = FontWeight.SemiBold, color = Color.White))
                                BasicText(value, Modifier.weight(1f), style = RiftType.Body.copy(fontSize = 12.5.sp, color = Color.White.copy(alpha = 0.55f), textAlign = TextAlign.End), maxLines = 1, overflow = TextOverflow.Ellipsis)
                            }
                        }
                    }
                }
            }
        }
        val list = events
        Caption("Upcoming events", list?.size?.toString())
        when {
            list == null -> Loading("Loading the store's events")
            error != null && list.isEmpty() -> BasicText(error ?: "", Modifier.fillMaxWidth().padding(vertical = 18.dp), style = Ev.Msg)
            list.isEmpty() -> BasicText("No upcoming events listed for this store.", Modifier.fillMaxWidth().padding(vertical = 18.dp), style = Ev.Msg)
            else -> {
                val registered = data.upcoming.map { it.tournament.id }.toSet()
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    list.forEach { e ->
                        val s = e.tournament
                        UCard(s.name, listOfNotNull(s.startsAt?.let { "${Fmt.weekday(it)} ${Fmt.shortDate(it)} · ${Fmt.time(it)}" }, Fmt.formatLine(s.config?.format, s.config?.playerFormat)).joinToString(" · "), { onOpen(EvPage.Event(e)) }) {
                            EvPill(Fmt.price(s.entryFee, s.pricing))
                            EvPill(Fmt.players(s.registeredCount, s.config?.participantCapacity))
                            if (s.id in registered) EvPill("Registered", Ev.Green.copy(alpha = 0.16f), Ev.Green)
                        }
                    }
                }
            }
        }
    }
}

/**
 * The month (iOS `PlayRiftboundCalendarView`, mock's month sheet): a solid dot where you are registered, a ring
 * where a favourite store has an event; a day lists its events.
 */
@Composable
fun MonthSheet(data: EventsData, onOpen: (EvPage) -> Unit, onDismiss: () -> Unit) {
    LaunchedEffect(Unit) { data.loadCalendar() }
    val today = dayStart(System.currentTimeMillis())
    var month by remember { mutableLongStateOf(Calendar.getInstance().apply { set(Calendar.DAY_OF_MONTH, 1) }.let { dayStart(it.timeInMillis) }) }
    var day by remember { mutableLongStateOf(today) }
    Sheet("Calendar", onDismiss) { close ->
        val cal = Calendar.getInstance().apply { timeInMillis = month }
        Row(Modifier.fillMaxWidth().padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
            RoundIconButton("Previous month", { month = shiftMonth(month, -1) }) { Image(EvIcons.ChevronLeft, null, colorFilter = ColorFilter.tint(Color.White)) }
            BasicText(
                Fmt.monthYear(month),
                Modifier.weight(1f), style = Ev.Display.copy(fontSize = 26.sp, lineHeight = 26.sp, color = Color.White, textAlign = TextAlign.Center),
            )
            RoundIconButton("Next month", { month = shiftMonth(month, 1) }) { Image(EvIcons.ChevronRight, null, colorFilter = ColorFilter.tint(Color.White)) }
        }
        val first = cal.firstDayOfWeek
        val names = (0 until 7).map { (first - 1 + it) % 7 + 1 }.map { dow ->
            Fmt.weekday(Calendar.getInstance().apply { set(Calendar.DAY_OF_WEEK, dow) }.timeInMillis).uppercase().take(2)
        }
        Row(Modifier.padding(top = 12.dp).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            names.forEach { BasicText(it, Modifier.weight(1f), style = RiftType.Body.copy(fontSize = 10.5.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.1.em, color = Color.White.copy(alpha = 0.45f), textAlign = TextAlign.Center)) }
        }
        val lead = (cal.get(Calendar.DAY_OF_WEEK) - first + 7) % 7
        val count = cal.getActualMaximum(Calendar.DAY_OF_MONTH)
        val cells = List(lead) { null } + (1..count).map { d -> dayStart(month + (d - 1) * 86_400_000L + 3_600_000L) }
        Column(Modifier.padding(top = 6.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            cells.chunked(7).forEach { week ->
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    week.forEach { d -> Box(Modifier.weight(1f)) { d?.let { DayCell(it, data.calendar, it == day, it == today) { day = it } } } }
                    repeat(7 - week.size) { Box(Modifier.weight(1f)) }
                }
            }
        }
        BasicText("Solid dot: you're registered. Ring: an event at a favourite store.", Modifier.padding(top = 10.dp, bottom = 10.dp), style = Ev.Muted)
        DayList(data.calendar.filter { sameDay(it.startsAt, day) }, day) { close(); onOpen(EvPage.Event(it.entry)) }
        EvButton("Done", BtnKind.Ghost, Modifier.padding(top = 12.dp).fillMaxWidth(), onClick = close)
    }
}

private fun shiftMonth(month: Long, by: Int): Long = Calendar.getInstance().apply {
    timeInMillis = month
    add(Calendar.MONTH, by)
    set(Calendar.DAY_OF_MONTH, 1)
}.let { dayStart(it.timeInMillis) }

@Composable
private fun DayCell(day: Long, items: List<EventsData.CalEvent>, on: Boolean, today: Boolean, onPick: () -> Unit) {
    val evs = items.filter { sameDay(it.startsAt, day) }
    val reg = evs.any { it.registered }
    val shape = RoundedCornerShape(14.dp)
    Pressable(
        onPick,
        Modifier.fillMaxWidth().height(48.dp)
            .background(if (on) Ev.Green else Color.Transparent, shape)
            .let { if (today && !on) it.border(1.5.dp, Ev.Gold, shape) else it },
        pressedScale = 0.94f,
        label = "${Fmt.weekday(day)} ${Fmt.day(day)}" + if (evs.isEmpty()) "" else ", ${evs.size} events",
    ) {
        BasicText(Fmt.day(day), style = Ev.Display.copy(fontSize = 16.sp, lineHeight = 16.sp, fontWeight = FontWeight.ExtraBold, color = if (on) Color.Black else if (today) Ev.Gold else Color.White))
        if (evs.isNotEmpty()) {
            Box(
                Modifier.align(Alignment.BottomCenter).padding(bottom = 7.dp).size(6.dp)
                    .let { if (reg) it.background(if (on) Color.Black else Ev.Green, CircleShape) else it.border(1.5.dp, if (on) Color.Black else Ev.Green, CircleShape) },
            )
        }
    }
}
