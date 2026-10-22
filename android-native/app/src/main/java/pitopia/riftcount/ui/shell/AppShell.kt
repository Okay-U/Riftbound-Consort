package pitopia.riftcount.ui.shell

import android.app.Activity
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
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
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.text.BasicText
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
import pitopia.riftcount.data.Prefs
import pitopia.riftcount.platform.haptic
import pitopia.riftcount.score.ScoreController
import pitopia.riftcount.score.ScoreScreen
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

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
    val view = LocalView.current
    SideEffect { score.haptic = { view.haptic(it) } }
    StatusBarHidden(tab == Tab.Score)
    // The tab bar (66 + 14 margin) above the system navigation; the score halves end above it.
    val barReserve = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + 80.dp
    Box(Modifier.fillMaxSize().background(RiftColors.Black)) {
        AnimatedContent(
            targetState = tab,
            transitionSpec = {
                (fadeIn(tween(320, delayMillis = 60, easing = RiftEase)) + scaleIn(tween(420, easing = RiftEase), initialScale = 0.98f))
                    .togetherWith(fadeOut(tween(140)))
            },
            label = "tab",
        ) { shown ->
            when (shown) {
                Tab.Score -> ScoreScreen(score, barReserve, decks.lists, cards)
                Tab.Cards -> CardsScreen(cardsUi, cards, errata, decks, barReserve, onOverlay = { overlay(Tab.Cards, it) }) { card ->
                    decksUi.startBuilder(card)
                    tab = Tab.Decks
                }
                Tab.Decks -> DecksScreen(decksUi, decks, games, cards, barReserve) { overlay(Tab.Decks, it) }
                else -> Placeholder(shown)
            }
        }
        BottomNav(selected = tab, onSelect = { tab = it }, modifier = Modifier.align(Alignment.BottomCenter), hidden = tab in overlays)
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

// ponytail: stand-in screens until each tab is built in its own phase
@Composable
private fun Placeholder(tab: Tab) {
    val phase = when (tab) {
        Tab.Score -> "Phase 1 · scoreboard"
        Tab.Events -> "Phase 5 · events"
        Tab.Cards -> "Phase 2 · cards"
        Tab.Decks -> "Phase 3 · decks"
        Tab.Settings -> "Phase 4 · settings"
    }
    Column(Modifier.fillMaxSize().statusBarsPadding().padding(start = 20.dp, top = 30.dp, end = 20.dp)) {
        BasicText(tab.label, style = RiftType.Title.copy(color = RiftColors.Ink))
        Spacer(Modifier.height(10.dp))
        BasicText(phase.uppercase(), style = RiftType.Caption.copy(color = RiftColors.InkMuted))
    }
}
