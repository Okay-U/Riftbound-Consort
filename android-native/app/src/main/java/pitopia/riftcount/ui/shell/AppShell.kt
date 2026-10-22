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
import pitopia.riftcount.cards.CardStore
import pitopia.riftcount.cards.CardsScreen
import pitopia.riftcount.cards.CardsUi
import pitopia.riftcount.cards.ErrataStore
import pitopia.riftcount.data.DecklistStore
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
    val cardsUi = remember { CardsUi() }
    val score = remember { ScoreController(scope, GameRecordStore(docs), decks) }
    var overlay by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        cards.loadIfNeeded()
        errata.load()
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
                Tab.Score -> ScoreScreen(score, barReserve)
                Tab.Cards -> CardsScreen(cardsUi, cards, errata, decks, barReserve) { overlay = it }
                else -> Placeholder(shown)
            }
        }
        BottomNav(selected = tab, onSelect = { tab = it }, modifier = Modifier.align(Alignment.BottomCenter), hidden = overlay)
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
