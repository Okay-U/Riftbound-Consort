package pitopia.riftcount.ui.shell

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import pitopia.riftcount.data.Prefs
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

/** Five tabs on true black, reopening on the last tab like iOS. Back on another tab returns to Score. */
@Composable
fun AppShell() {
    var tab by rememberSaveable { mutableStateOf(Tab.fromKey(Prefs.string(TAB_KEY, Tab.Score.key))) }
    LaunchedEffect(tab) { Prefs.put(TAB_KEY, tab.key) }
    BackHandler(enabled = tab != Tab.Score) { tab = Tab.Score }
    Box(Modifier.fillMaxSize().background(RiftColors.Black)) {
        AnimatedContent(
            targetState = tab,
            transitionSpec = {
                (fadeIn(tween(320, delayMillis = 60, easing = RiftEase)) + scaleIn(tween(420, easing = RiftEase), initialScale = 0.98f))
                    .togetherWith(fadeOut(tween(140)))
            },
            label = "tab",
        ) { shown -> Placeholder(shown) }
        BottomNav(selected = tab, onSelect = { tab = it }, modifier = Modifier.align(Alignment.BottomCenter))
    }
}

private const val TAB_KEY = "currentTab"

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
