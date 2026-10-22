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
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.LifecycleResumeEffect
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.Toaster
import pitopia.riftcount.ui.common.softBlur
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

private enum class EvTab(val label: String) { Matches("Matches"), Rounds("Rounds"), Standings("Standings"), Roster("Roster"), Info("Info") }

private enum class Action(val title: String, val text: String, val label: String, val danger: Boolean, val done: String) {
    Register("Register for this event?", "Registers you for this event with your Riot account.", "Register", false, "Registered with your Riot account"),
    Deregister("Cancel registration?", "Removes your registration. You can register again while registration is open.", "Cancel registration", true, "Registration cancelled"),
    Drop("Drop from event?", "Drops you from the running event. This cannot be undone.", "Drop from event", true, "You dropped from the event"),
}

/**
 * One event (iOS `PlayRiftboundEventView`, mock's event page): store, name, when, who; with rounds the five
 * tabs Matches · Rounds · Standings · Roster · Info, before that the details.
 */
@Composable
fun ColumnScope.EventPage(data: EventsData, entry: TournamentEntry, toaster: Toaster, onStore: (Organizer) -> Unit, onSite: (String?) -> Unit) {
    val s = entry.tournament
    val scope = rememberCoroutineScope()
    var t by remember { mutableStateOf(data.cached(s.id)) }
    var error by remember { mutableStateOf<String?>(null) }
    var generation by remember { mutableIntStateOf(0) }
    var tab by rememberSaveable { mutableStateOf(EvTab.Matches) }
    var reporting by remember { mutableStateOf<Pairing?>(null) }
    var action by remember { mutableStateOf<Action?>(null) }
    var busy by remember { mutableStateOf(false) }
    var actionError by remember { mutableStateOf<String?>(null) }
    var drawing by remember { mutableStateOf(false) }

    suspend fun load() {
        val request = ++generation
        try {
            val fresh = data.tournament(s.id, force = true)
            if (request != generation) return
            t = fresh
            error = if (fresh == null) "Event not found." else null
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            if (request == generation && t == null) error = e.message
        }
    }
    LaunchedEffect(s.id) { load() }
    // Back from the lock screen between rounds: the new pairing, not the old one.
    LifecycleResumeEffect(s.id) {
        scope.launch { load() }
        onPauseOrDispose {}
    }

    val tt = t
    val me = tt?.let(data::playerId)
    val state = when {
        tt != null && me != null -> tt.state(me)
        tt == null && data.upcoming.any { it.tournament.id == s.id } -> PlayerState.Registered
        else -> PlayerState.None
    }
    val isPast = data.past.any { it.tournament.id == s.id }
    val now = System.currentTimeMillis()
    val isOver = isPast || tt?.isFinished == true || (s.startsAt?.let { it + 12 * 3_600_000 < now } == true)

    Hero(entry, tt, state, data.isLive(entry) && !isOver) { entry.organizer?.let(onStore) }
    when {
        tt != null && tt.rounds.isNotEmpty() -> {
            Tabs(tab) { tab = it }
            TabContent(tab) {
                when (tab) {
                    EvTab.Matches -> MatchesTab(tt, me, isPast, onReport = { reporting = it })
                    EvTab.Rounds -> RoundsTab(tt, me?.let(tt::teamId))
                    EvTab.Standings -> StandingsTab(tt, me?.let(tt::teamId), state != PlayerState.Dropped) { drawing = true }
                    EvTab.Roster -> RosterTab(tt, me)
                    EvTab.Info -> InfoTab(data, tt, s, me, state, isOver, busy, actionError, { action = it }, onSite)
                }
            }
        }
        tt != null -> InfoTab(data, tt, s, me, state, isOver, busy, actionError, { action = it }, onSite)
        error != null -> BasicText(error ?: "", Modifier.fillMaxWidth().padding(top = 20.dp), style = Ev.Msg)
        else -> Loading("Loading the event")
    }

    reporting?.let { p -> ReportDialog(data, s.id, p, toaster) { reporting = null; scope.launch { load() } } }
    action?.let { a ->
        ActionDialog(a.title, a.text, a.label, a.danger, onKeep = { action = null }) {
            action = null
            busy = true
            actionError = null
            // Once sent, Riot has the change: the call and the lists catching up finish also when the page closes.
            scope.launch {
                withContext(NonCancellable) {
                    try {
                        val credentials = RiotSession.valid(data.browser) ?: throw RiftError.NotSignedIn()
                        when (a) {
                            Action.Register -> data.api.register(s.id, credentials)
                            Action.Deregister -> data.api.deregister(s.id, credentials)
                            Action.Drop -> data.api.drop(s.id, credentials)
                        }
                        toaster.show(a.done)
                        load()
                        data.refresh(force = true)
                        data.refreshStrip(force = true)
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: Exception) {
                        actionError = e.message
                    } finally {
                        busy = false
                    }
                }
            }
        }
    }
    if (drawing && tt != null) me?.let(tt::teamId)?.let { team -> DrawSheet(tt, team) { drawing = false } }
}

private val HeroShape = RoundedCornerShape(24.dp)

/** `.ehero`: the store link, name, date and the player count with the player's status. */
@Composable
private fun Hero(entry: TournamentEntry, t: Tournament?, state: PlayerState, live: Boolean, onStore: () -> Unit) {
    val s = entry.tournament
    Column(Modifier.fillMaxWidth().background(Ev.Card, HeroShape).border(1.dp, Ev.Ring, HeroShape).padding(horizontal = 16.dp, vertical = 14.dp)) {
        entry.organizer?.let { o ->
            Pressable(onStore, pressedScale = 0.97f, label = "Open ${o.name}") {
                BasicText("${o.name.uppercase()} ›", style = RiftType.Body.copy(fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.16.em, color = Ev.Green))
            }
        }
        BasicText(s.name, Modifier.padding(top = 6.dp), style = Ev.Display.copy(fontSize = 28.sp, lineHeight = 28.6.sp, color = Color.White))
        s.startsAt?.let { BasicText(Fmt.whenLine(it), Modifier.padding(top = 6.dp), style = RiftType.Body.copy(fontSize = 13.sp, color = Color.White.copy(alpha = 0.66f))) }
        Row(Modifier.padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            val count = t?.tournamentRegistrants?.count { (it.status ?: "REGISTERED") == "REGISTERED" }?.takeIf { it > 0 } ?: s.registeredCount
            EvPill("${Fmt.players(count, s.config?.participantCapacity)} players")
            StatusPill(state, live)
        }
    }
}

/** `.tabs`: text tabs whose glowing underline grows under the chosen one. */
@Composable
private fun Tabs(tab: EvTab, onPick: (EvTab) -> Unit) {
    Row(
        Modifier.padding(top = 14.dp).fillMaxWidth().bleed(16.dp)
            .drawBehind { drawRect(Color.White.copy(alpha = 0.08f), Offset(0f, size.height - 1.dp.toPx()), Size(size.width, 1.dp.toPx())) }
            .horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        EvTab.entries.forEach { t ->
            val on = t == tab
            val ink by animateColorAsState(if (on) Color.White else Color.White.copy(alpha = 0.55f), tween(300), label = "tab")
            val bar by animateFloatAsState(if (on) 1f else 0f, tween(420, easing = RiftEase), label = "bar")
            Pressable({ onPick(t) }, Modifier.height(42.dp).semantics { selected = on }, pressedScale = 0.97f, role = Role.Tab) {
                BasicText(t.label, Modifier.padding(horizontal = 12.dp), style = RiftType.Body.copy(fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = ink))
                val shape = RoundedCornerShape(2.dp)
                // The row scrolls sideways (unbounded width): the bar takes the tab's size from matchParentSize.
                Box(Modifier.matchParentSize(), contentAlignment = Alignment.BottomCenter) {
                    Box(
                        Modifier.padding(horizontal = 10.dp).fillMaxWidth().height(3.dp)
                            .graphicsLayer { scaleX = bar; alpha = if (bar > 0.01f) 1f else 0f }
                            .dropShadow(shape, Shadow(10.dp, Ev.Green.copy(alpha = 0.8f))).background(Ev.Green, shape),
                    )
                }
            }
        }
    }
}

/** A tab's content slides in from the right out of a blur when the tab changes (mock's `tabA`). */
@Composable
private fun TabContent(tab: EvTab, content: @Composable ColumnScope.() -> Unit) {
    val t = remember { Animatable(1f) }
    LaunchedEffect(tab) {
        t.snapTo(0f)
        t.animateTo(1f, tween(520, easing = RiftEase))
    }
    Column(
        Modifier.fillMaxWidth().graphicsLayer {
            val v = t.value
            alpha = v
            translationX = 24.dp.toPx() * (1f - v)
            val b = 6.dp.toPx() * (1f - v)
            renderEffect = softBlur(b)
        },
        content = content,
    )
}

/** Before the rounds, and the Info tab: register / cancel / drop, the site, details and the player list. */
@Composable
private fun InfoTab(
    data: EventsData, t: Tournament, s: TournamentSummary, me: String?, state: PlayerState, isOver: Boolean, busy: Boolean, error: String?,
    onAction: (Action) -> Unit, onSite: (String?) -> Unit,
) {
    val started = t.hasStarted || t.rounds.isNotEmpty()
    val closed = (t.registrationEndAt?.let { it < System.currentTimeMillis() } == true) ||
        (s.config?.participantCapacity?.let { it > 0 && s.registeredCount >= it } == true)
    val action = when {
        data.me == null || isOver -> null
        state == PlayerState.Registered || state == PlayerState.Active || state == PlayerState.Waitlisted -> if (started) Action.Drop else Action.Deregister
        state == PlayerState.None && !started && !closed -> Action.Register
        else -> null
    }
    action?.let { a ->
        EvButton(if (busy) "Working…" else a.label, if (a.danger) BtnKind.DangerSoft else BtnKind.Green, Modifier.padding(top = 12.dp).fillMaxWidth(), enabled = !busy) { onAction(a) }
    }
    if (!data.signedIn) BasicText("Sign in on PlayRiftbound first.", Modifier.fillMaxWidth().padding(vertical = 14.dp), style = Ev.Msg)
    error?.let { BasicText(it, Modifier.padding(top = 8.dp), style = Ev.Muted.copy(color = Ev.Red)) }
    EvButton("Open on PlayRiftbound", BtnKind.Ghost, Modifier.padding(top = 8.dp).fillMaxWidth()) { onSite(s.webUrl) }

    Caption("Details")
    EvCard {
        t.tournamentProgram?.programName?.let { EvPill(it, height = 24) }
        Column(Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            val body = RiftType.Body.copy(fontSize = 14.sp, lineHeight = 21.sp, color = Color.White.copy(alpha = 0.82f))
            Fmt.formatLine(t.config?.format, t.config?.playerFormat, t.config?.structure ?: t.config?.tournamentType)?.let { BasicText(it, style = body) }
            listOfNotNull(
                t.config?.roundCount?.takeIf { it > 0 }?.let { "$it rounds" },
                t.config?.matchFormat?.let(Fmt::humanize),
                Fmt.price(t.entryFee, t.pricing),
            ).takeIf { it.isNotEmpty() }?.let { BasicText(it.joinToString(" • "), style = body) }
            t.description?.takeIf { it.isNotBlank() }?.let { BasicText(it, style = body.copy(color = Color.White.copy(alpha = 0.66f))) }
            t.registrationEndAt?.let {
                BasicText(
                    if (it > System.currentTimeMillis()) "Registration closes ${Fmt.whenLine(it)}" else "Registration closed",
                    style = body.copy(color = Color.White.copy(alpha = 0.5f)),
                )
            }
        }
    }
    val registrants = t.tournamentRegistrants.orEmpty().filter { (it.status ?: "REGISTERED") == "REGISTERED" }
    Caption("Players · ${registrants.size}")
    if (registrants.isEmpty()) {
        BasicText("No one registered yet.", style = Ev.Muted)
    } else {
        EvCard {
            registrants.forEachIndexed { i, r ->
                PersonRow(r.player?.displayName ?: "Player", you = r.player?.id == me && me != null, divider = i < registrants.lastIndex) {
                    if (r.checkedIn == true) Image(EvIcons.Check, "Checked in", colorFilter = ColorFilter.tint(Ev.Green))
                }
            }
        }
    }
}

/** `.prow`: a player row with a YOU tag and something on the right. */
@Composable
fun PersonRow(name: String, you: Boolean, divider: Boolean, faded: Boolean = false, tag: String = "YOU", trailing: @Composable () -> Unit = {}) {
    Row(
        Modifier.fillMaxWidth().height(46.dp).drawBehind {
            if (divider) drawRect(Color.White.copy(alpha = 0.06f), Offset(0f, size.height - 1.dp.toPx()), Size(size.width, 1.dp.toPx()))
        },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            BasicText(name, Modifier.weight(1f, fill = false), style = RiftType.Body.copy(fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = if (faded) 0.5f else 1f)), maxLines = 1)
            if (you) MiniPill(tag, Ev.Green.copy(alpha = 0.16f), Ev.Green)
        }
        trailing()
    }
}

/** Players with their seeds, dropped ones apart (iOS `PlayRiftboundRosterTab`). */
@Composable
private fun RosterTab(t: Tournament, me: String?) {
    val myTeam = me?.let(t::teamId)
    val all = t.tournamentParticipants.orEmpty().sortedBy { it.player?.displayName?.lowercase() }
    val (dropped, active) = all.partition { it.status?.uppercase()?.contains("DROP") == true }
    Caption("Players · ${active.size} active")
    EvCard {
        active.forEachIndexed { i, p ->
            val mine = me != null && p.player?.id == me
            val mate = !mine && myTeam != null && p.esportsTeamId == myTeam
            PersonRow(p.player?.displayName ?: "Player", mine || mate, i < active.lastIndex, tag = if (mine) "YOU" else "TEAM") { Seed(p.position) }
        }
    }
    if (dropped.isNotEmpty()) {
        Caption("Dropped")
        EvCard {
            dropped.forEachIndexed { i, p -> PersonRow(p.player?.displayName ?: "Player", false, i < dropped.lastIndex, faded = true) { Seed(p.position) } }
        }
    }
}

@Composable
private fun Seed(position: Int?) {
    position?.let { BasicText("#$it", style = Ev.Display.copy(fontSize = 13.sp, lineHeight = 13.sp, fontWeight = FontWeight.ExtraBold, color = Color.White.copy(alpha = 0.45f))) }
}
