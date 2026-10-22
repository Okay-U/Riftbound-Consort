package pitopia.riftcount.events

import androidx.activity.compose.BackHandler
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
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
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.ToastHost
import pitopia.riftcount.ui.common.Toaster
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

/** A page pushed over the sections: an event, or the event finder. */
sealed interface EvPage {
    data class Event(val entry: TournamentEntry) : EvPage
    data object Search : EvPage
}

/** Sheets of the Events tab. */
sealed interface EvSheet {
    data class Store(val organizer: Organizer) : EvSheet
    data object Month : EvSheet
}

/** A pushed page with its own slide (0 out at the right, 1 in place). */
class PageEntry(val page: EvPage, val key: Int) {
    val t = Animatable(0f)
    var leaving by mutableStateOf(false)
}

/** Where the Events tab is, kept while the app runs (tab switches, deep links). */
class EventsUi {
    var section by mutableIntStateOf(0)
    val stack = mutableStateListOf<PageEntry>()
    var sheet by mutableStateOf<EvSheet?>(null)
    private var keys = 0

    fun push(page: EvPage) {
        stack += PageEntry(page, ++keys)
    }
}

private val Sections = listOf("Events", "Stores", "PlayRiftbound")

/**
 * The Events tab (EventsMix): section tabs Events · Stores · PlayRiftbound with a glowing underline, the
 * sections sliding sideways, event and finder pages pushed over them like Settings' sub pages.
 */
@Composable
fun EventsScreen(data: EventsData, ui: EventsUi, bottomReserve: Dp, onOverlay: (Boolean) -> Unit) {
    val scope = rememberCoroutineScope()
    val toaster = remember { Toaster() }
    val browser = data.browser

    fun pop() {
        val top = ui.stack.lastOrNull { !it.leaving } ?: return
        top.leaving = true
        scope.launch {
            top.t.animateTo(0f, tween(620, easing = RiftEase))
            ui.stack.remove(top)
        }
    }
    val open: (EvPage) -> Unit = { page ->
        if (page is EvPage.Event && !data.signedIn) toaster.show("Sign in on PlayRiftbound first.") else ui.push(page)
    }
    val toSite: (String?) -> Unit = { url ->
        ui.stack.clear()
        ui.section = 2
        url?.let(browser::load) ?: browser.loadHomeIfNeeded()
    }

    // A deep link (scoreboard, an event's "Open on PlayRiftbound") lands in the PlayRiftbound section.
    LaunchedEffect(browser.pending) {
        browser.pending?.let {
            browser.pending = null
            toSite(it)
        }
    }

    val pageOpen = ui.stack.isNotEmpty()
    val report by rememberUpdatedState(onOverlay)
    LaunchedEffect(pageOpen) {
        if (!pageOpen) delay(180)
        report(pageOpen)
    }
    DisposableEffect(Unit) { onDispose { report(false) } }
    BackHandler(enabled = pageOpen || (ui.section == 2 && browser.canGoBack)) {
        if (ui.stack.isNotEmpty()) pop() else browser.goBack()
    }

    Box(Modifier.fillMaxSize()) {
        val first = ui.stack.firstOrNull()
        Column(Modifier.fillMaxSize().pushedBack(first)) {
            BasicText("Events", Modifier.statusBarsPadding().padding(start = 20.dp, end = 20.dp, top = 6.dp), style = RiftType.Title.copy(color = Color.White))
            SectionTabs(ui.section) { ui.section = it }
            Panes(ui.section) { i ->
                when (i) {
                    0 -> MyEventsPane(data, ui.section == 0, bottomReserve, toaster, onOpen = open, onSite = toSite)
                    1 -> StoresPane(data, ui.section == 1, bottomReserve, toaster, onSheet = { ui.sheet = it }, onOpen = open)
                    else -> WebPane(browser, bottomReserve, toaster, active = ui.section == 2) { data.refresh(force = true) }
                }
            }
        }
        ui.stack.forEachIndexed { i, entry ->
            key(entry.key) {
                LaunchedEffect(Unit) { entry.t.animateTo(1f, tween(620, easing = RiftEase)) }
                val next = ui.stack.getOrNull(i + 1)
                PageFrame(entry, next, if (entry.page is EvPage.Event) "Event" else "Find events", onBack = ::pop) {
                    when (val page = entry.page) {
                        is EvPage.Event -> EventPage(data, page.entry, toaster, onStore = { ui.sheet = EvSheet.Store(it) }, onSite = toSite)
                        EvPage.Search -> SearchPage(data, toaster, onOpen = open)
                    }
                }
            }
        }
        ToastHost(toaster)
    }

    when (val sheet = ui.sheet) {
        is EvSheet.Store -> StoreSheet(data, sheet.organizer, toaster, onOpen = { ui.sheet = null; open(it) }) { ui.sheet = null }
        EvSheet.Month -> MonthSheet(data, onOpen = { ui.sheet = null; open(it) }) { ui.sheet = null }
        null -> Unit
    }
}

/** A layer pushed back (26% to the left, nearly faded) while the page above it is in. */
private fun Modifier.pushedBack(above: PageEntry?) = graphicsLayer {
    val v = above?.t?.value ?: 0f
    translationX = -0.26f * size.width * v
    alpha = 1f - 0.84f * v
}

@Composable
private fun PageFrame(entry: PageEntry, next: PageEntry?, title: String, onBack: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier.fillMaxSize()
            .graphicsLayer { translationX = size.width * (1f - entry.t.value) }
            .pushedBack(next)
            .background(RiftColors.Page)
            .clickable(remember { MutableInteractionSource() }, null) {}
            .statusBarsPadding().navigationBarsPadding(),
    ) {
        Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            RoundIconButton("Back", onBack) { Image(EvIcons.Back, null, colorFilter = ColorFilter.tint(Color.White)) }
            BasicText(title, style = RiftType.Title.copy(fontSize = 28.sp, lineHeight = 28.sp, color = Color.White))
        }
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 14.dp, bottom = 40.dp), content = content)
    }
}

/** `.icon`: 42dp round button with a hairline. */
@Composable
fun RoundIconButton(label: String, onClick: () -> Unit, enabled: Boolean = true, content: @Composable () -> Unit) {
    Pressable(
        onClick,
        Modifier.size(42.dp).graphicsLayer { alpha = if (enabled) 1f else 0.3f }
            .background(Color.White.copy(alpha = 0.06f), CircleShape).border(1.dp, Color.White.copy(alpha = 0.14f), CircleShape),
        enabled = enabled,
        pressedScale = 0.92f,
        label = label,
    ) { content() }
}

/** `.stabs`: three text tabs on a hairline, the glowing bar slides under the chosen one. */
@Composable
private fun SectionTabs(section: Int, onPick: (Int) -> Unit) {
    BoxWithConstraints(
        Modifier.padding(start = 16.dp, end = 16.dp, top = 14.dp).fillMaxWidth().height(42.dp)
            .drawBehind { drawRect(Color.White.copy(alpha = 0.08f), Offset(0f, size.height - 1.dp.toPx()), Size(size.width, 1.dp.toPx())) },
    ) {
        val gap = 4.dp
        val tab = (maxWidth - gap * 2) / 3
        val x by animateFloatAsState(section.toFloat(), tween(520, easing = RiftEase), label = "bar")
        Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
            Sections.forEachIndexed { i, label ->
                val ink by animateColorAsState(if (i == section) Color.White else Color.White.copy(alpha = 0.5f), tween(300), label = "tabInk")
                Pressable(
                    { onPick(i) },
                    Modifier.width(tab).height(42.dp).semantics { selected = i == section },
                    pressedScale = 0.97f,
                    role = Role.Tab,
                ) { BasicText(label, style = RiftType.Body.copy(fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = ink)) }
            }
        }
        val shape = RoundedCornerShape(2.dp)
        Box(
            Modifier.align(Alignment.BottomStart).offset(y = 1.dp).graphicsLayer { translationX = x * (tab + gap).toPx() }
                .width(tab).height(3.dp).dropShadow(shape, Shadow(12.dp, Ev.Green.copy(alpha = 0.8f))).background(Ev.Green, shape),
        )
    }
}

/** The three sections side by side; the chosen one slides in (620ms), the others stay composed off screen. */
@Composable
private fun Panes(section: Int, content: @Composable (Int) -> Unit) {
    val x by animateFloatAsState(section.toFloat(), tween(620, easing = RiftEase), label = "panes")
    Box(Modifier.fillMaxSize()) {
        repeat(Sections.size) { i ->
            Box(
                Modifier.fillMaxSize().graphicsLayer { translationX = (i - x) * size.width }
                    .let { if (i == section) it else it.clearAndSetSemantics {} },
            ) { content(i) }
        }
    }
}
