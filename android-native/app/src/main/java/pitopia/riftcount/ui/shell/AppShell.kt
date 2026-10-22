package pitopia.riftcount.ui.shell

import android.app.Activity
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import java.io.File
import androidx.lifecycle.compose.LifecycleResumeEffect
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.builtins.ListSerializer
import pitopia.riftcount.cards.Card
import pitopia.riftcount.cards.CardStore
import pitopia.riftcount.cards.CardsScreen
import pitopia.riftcount.cards.CardsUi
import pitopia.riftcount.cards.ErrataStore
import pitopia.riftcount.data.DecklistStore
import pitopia.riftcount.data.LegacyIds
import pitopia.riftcount.data.SwiftJson
import pitopia.riftcount.decks.DecksScreen
import pitopia.riftcount.decks.DecksUi
import pitopia.riftcount.data.Documents
import pitopia.riftcount.data.GameRecordStore
import pitopia.riftcount.data.AppSettings
import pitopia.riftcount.data.Prefs
import pitopia.riftcount.platform.Sounds
import pitopia.riftcount.platform.haptic
import pitopia.riftcount.score.ScoreController
import pitopia.riftcount.score.ScoreScreen
import pitopia.riftcount.events.DebugEvents
import pitopia.riftcount.events.EventsData
import pitopia.riftcount.events.EventsScreen
import pitopia.riftcount.events.EventsUi
import pitopia.riftcount.events.RiftApi
import pitopia.riftcount.events.RiftBrowser
import pitopia.riftcount.events.tableLink
import pitopia.riftcount.settings.Support
import pitopia.riftcount.settings.PlayRiftboundLog
import pitopia.riftcount.settings.SettingsScreen
import pitopia.riftcount.tour.Tour
import pitopia.riftcount.tour.TourKind
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase

/** Five tabs on true black, reopening on the last tab like iOS. Back on another tab returns to Score. */
@Composable
fun AppShell() {
    var tab by rememberSaveable { mutableStateOf(Tab.fromKey(Prefs.string(TAB_KEY, Tab.Score.key))) }
    LaunchedEffect(tab) { Prefs.put(TAB_KEY, tab.key) }
    BackHandler(enabled = tab != Tab.Score) { tab = Tab.Score }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val docs = remember { Documents(File(context.filesDir, "Documents")) }
    val decks = remember { DecklistStore(docs) }
    val cards = remember { CardStore(docs, scope) }
    val errata = remember { ErrataStore(docs, scope) }
    val games = remember { GameRecordStore(docs) }
    val cardsUi = remember { CardsUi() }
    val decksUi = remember { DecksUi() }
    val score = remember { ScoreController(scope, games, decks) }
    val browser = remember { RiftBrowser(context) }
    val events = remember {
        val dir = File(context.filesDir, "Documents")
        EventsData(RiftApi(DebugEvents.transport(context, dir), PlayRiftboundLog(File(dir, PlayRiftboundLog.FILE)), Support.version(context).substringBefore(' ')), browser)
    }
    val eventsUi = remember { EventsUi() }
    DisposableEffect(Unit) { onDispose { browser.destroy() } }
    // "Open on PlayRiftbound" from anywhere lands in the Events tab's browser.
    LaunchedEffect(browser.pending) { if (browser.pending != null) tab = Tab.Events }
    // Per tab: a screen leaving reports "no overlay" after the next one reported its own.
    var overlays by remember { mutableStateOf(emptySet<Tab>()) }
    fun overlay(t: Tab, on: Boolean) {
        overlays = if (on) overlays + t else overlays - t
    }
    LaunchedEffect(Unit) {
        cards.loadIfNeeded()
        errata.load()
    }
    // Decks of Skip 3.4 and iOS before 3.5 point at riftcodex ids; every card publish maps what it can (iOS).
    LaunchedEffect(cards.revision) {
        val legacy = docs.file(LegacyIds.LEGACY_SNAPSHOT).takeIf { it.exists() && cards.cards.isNotEmpty() } ?: return@LaunchedEffect
        val old = withContext(Dispatchers.IO) {
            runCatching { SwiftJson.decodeFromString(ListSerializer(Card.serializer()), legacy.readText()) }.getOrDefault(emptyList())
        }
        if (decks.migrateLegacyIds(cards.cards, old)) withContext(Dispatchers.IO) { legacy.delete() }
    }
    LifecycleResumeEffect(Unit) {
        cards.refreshIfDue()
        onPauseOrDispose {}
    }
    // Match mode: the scoreboard's pairing, fetched when the Score tab shows (iOS, at most every 45 s).
    LifecycleResumeEffect(tab) {
        if (tab == Tab.Score && AppSettings.matchMode.on) scope.launch { events.refreshStrip() }
        onPauseOrDispose {}
    }
    val view = LocalView.current
    SideEffect {
        score.haptic = {
            view.haptic(it)
            Sounds.play(it)
        }
    }
    StatusBarHidden(tab == Tab.Score)
    KeepAwake(AppSettings.keepScreenOn.on)
    // The six-page tour on first launch; the Events tour the first time Events opens; both again from Settings.
    var tour by remember { mutableStateOf(if (AppSettings.didOnboard.on) null else TourKind.Main) }
    LaunchedEffect(tab) {
        if (tab == Tab.Events && tour == null && !AppSettings.didOnboardEvents.on) tour = TourKind.Events
    }
    fun endTour() {
        when (tour) {
            TourKind.Main -> AppSettings.didOnboard.on = true
            TourKind.Events -> AppSettings.didOnboardEvents.on = true
            null -> Unit
        }
        tour = null
    }
    // The tab bar (66 + 14 margin) above the system navigation; the score halves end above it.
    val barReserve = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + 80.dp
    val page by animateColorAsState(RiftColors.Page, tween(600), label = "page")
    Box(Modifier.fillMaxSize().background(page)) {
        AnimatedContent(
            targetState = tab,
            transitionSpec = {
                (fadeIn(tween(320, delayMillis = 60, easing = RiftEase)) + scaleIn(tween(420, easing = RiftEase), initialScale = 0.98f))
                    .togetherWith(fadeOut(tween(140)))
            },
            label = "tab",
        ) { shown ->
            when (shown) {
                Tab.Score -> ScoreScreen(score, barReserve, decks.lists, cards, if (AppSettings.matchMode.on && score.state.isDuel) events.tableLink(scope) else null)
                Tab.Cards -> CardsScreen(cardsUi, cards, errata, decks, barReserve, onOverlay = { overlay(Tab.Cards, it) }) { card ->
                    decksUi.startBuilder(card)
                    tab = Tab.Decks
                }
                Tab.Decks -> DecksScreen(decksUi, decks, games, cards, barReserve) { overlay(Tab.Decks, it) }
                Tab.Settings -> SettingsScreen(score, docs.file(PlayRiftboundLog.FILE), barReserve, onTour = { tour = it }) {
                    overlay(Tab.Settings, it)
                }
                Tab.Events -> EventsScreen(events, eventsUi, barReserve) { overlay(Tab.Events, it) }
            }
        }
        BottomNav(selected = tab, onSelect = { tab = it }, modifier = Modifier.align(Alignment.BottomCenter), hidden = tab in overlays)
        AnimatedContent(
            targetState = tour,
            modifier = Modifier.fillMaxSize(),
            transitionSpec = { fadeIn(tween(420, easing = RiftEase)).togetherWith(fadeOut(tween(300))) },
            label = "tour",
        ) { kind -> if (kind != null) Tour(kind, ::endTour) }
    }
}

/** iOS keeps the screen awake while the app is open; the Keep screen on switch turns it off right away. */
@Composable
private fun KeepAwake(on: Boolean) {
    val view = LocalView.current
    DisposableEffect(on) {
        view.keepScreenOn = on
        onDispose { view.keepScreenOn = false }
    }
}

private const val TAB_KEY = "currentTab"

/** The scoreboard is full screen like the mock; a swipe from the top brings the status bar back. */
@Composable
private fun StatusBarHidden(hidden: Boolean) {
    val view = LocalView.current
    DisposableEffect(hidden) {
        val window = (view.context as? Activity)?.window
        val bars = window?.let { WindowCompat.getInsetsController(it, view) }
        bars?.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        if (hidden) bars?.hide(WindowInsetsCompat.Type.statusBars()) else bars?.show(WindowInsetsCompat.Type.statusBars())
        onDispose {}
    }
}

