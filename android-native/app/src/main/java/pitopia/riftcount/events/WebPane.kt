package pitopia.riftcount.events

import android.view.ViewGroup
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.net.toUri
import kotlinx.coroutines.launch
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.Toaster
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

/**
 * The PlayRiftbound section (iOS `PlayRiftboundView`): the domain-locked browser with back / forward, the host,
 * reload and a menu. Sign-in happens on Riot's own pages; the hint says Riot ID + password only.
 */
@Composable
fun WebPane(browser: RiftBrowser, bottomReserve: Dp, toaster: Toaster, active: Boolean, onSignedOut: suspend () -> Unit) {
    val scope = rememberCoroutineScope()
    // The site loads the first time the section is shown, not before.
    var started by remember { mutableStateOf(false) }
    LaunchedEffect(active) {
        if (active) {
            started = true
            browser.loadHomeIfNeeded()
        }
    }
    var menu by remember { mutableStateOf(false) }
    val onRiot = RiftPolicy.isRiotDomain(browser.url)
    Column(Modifier.fillMaxSize().padding(top = 10.dp, bottom = bottomReserve)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            ToolIcon("Back", browser.canGoBack, browser::goBack) { Image(EvIcons.ChevronLeft, null, colorFilter = ColorFilter.tint(Color.White)) }
            ToolIcon("Forward", browser.canGoForward, browser::goForward) { Image(EvIcons.ChevronRight, null, colorFilter = ColorFilter.tint(Color.White)) }
            Row(
                Modifier.weight(1f).height(38.dp).background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(19.dp)).padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Image(EvIcons.Lock, null, colorFilter = ColorFilter.tint(Ev.Green))
                BasicText(browser.url?.toUri()?.host ?: "playriftbound.com", style = RiftType.Body.copy(fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.85f)), maxLines = 1)
            }
            ToolIcon(if (browser.loading) "Stop loading" else "Reload", true, { if (browser.loading) browser.stop() else browser.reload() }) {
                Image(EvIcons.Reload, null, colorFilter = ColorFilter.tint(Color.White))
            }
            ToolIcon("More", true, { menu = !menu }) {
                Canvas(Modifier.size(18.dp)) {
                    listOf(0.2f, 0.5f, 0.8f).forEach { x -> drawCircle(Color.White, 2.dp.toPx(), Offset(size.width * x, size.height / 2)) }
                }
            }
        }
        val progress by animateFloatAsState(browser.progress / 100f, tween(700, easing = RiftEase), label = "progress")
        val shown by animateFloatAsState(if (browser.loading) 1f else 0f, tween(300), label = "progressShown")
        val bar = RoundedCornerShape(1.dp)
        Box(
            Modifier.padding(top = 8.dp).fillMaxWidth().height(2.dp)
                .graphicsLayer { scaleX = progress; alpha = shown; transformOrigin = TransformOrigin(0f, 0.5f) }
                .dropShadow(bar, Shadow(8.dp, Ev.Green.copy(alpha = 0.8f))).background(Ev.Green, bar),
        )
        val notice = browser.notice
        when {
            notice != null -> Banner(notice, "Add", { browser.openOutside(RiftPolicy.ADD_PASSWORD) }) { browser.notice = null }
            onRiot -> Banner("Sign in with your Riot ID and password. Signed up with Google, Apple or another provider? Add a Riot password first.", "Add", { browser.openOutside(RiftPolicy.ADD_PASSWORD) })
        }
        Box(Modifier.padding(start = 12.dp, end = 12.dp, top = 10.dp).fillMaxSize().clip(RoundedCornerShape(20.dp)).background(Color.Black)) {
            if (started) key(browser.generation) {
                AndroidView(
                    factory = { browser.webView().also { (it.parent as? ViewGroup)?.removeView(it) } },
                    modifier = Modifier.fillMaxSize(),
                    onRelease = { (it.parent as? ViewGroup)?.removeView(it) },
                )
            }
            browser.loadError?.let { message ->
                Column(
                    Modifier.align(Alignment.Center).padding(24.dp).widthIn(max = 320.dp).background(Ev.Card, RoundedCornerShape(22.dp))
                        .border(1.dp, Ev.Ring, RoundedCornerShape(22.dp)).padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    BasicText("Couldn't load PlayRiftbound", style = RiftType.Body.copy(fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color.White))
                    BasicText(message, style = RiftType.Body.copy(fontSize = 13.sp, color = Color.White.copy(alpha = 0.66f), textAlign = TextAlign.Center))
                    EvButton("Try again", BtnKind.Green, Modifier.width(160.dp), onClick = browser::reload)
                }
            }
        }
    }
    if (menu) Menu(
        onClose = { menu = false },
        items = listOf(
            "Home" to { browser.load(RiftPolicy.HOME) },
            "Open in browser" to { browser.openOutside() },
            "Sign out of Riot" to {
                scope.launch {
                    browser.signOut()
                    toaster.show("Signed out of Riot on this phone")
                    onSignedOut()
                }
            },
        ),
    )
}

@Composable
private fun ToolIcon(label: String, enabled: Boolean, onClick: () -> Unit, content: @Composable () -> Unit) {
    Pressable(onClick, Modifier.size(38.dp).graphicsLayer { alpha = if (enabled) 1f else 0.28f }, enabled = enabled, pressedScale = 0.9f, label = label) { content() }
}

/** `.wbanner`: the gold hint on Riot's pages, and the notice of a blocked social sign-in. */
@Composable
private fun Banner(text: String, action: String, onAction: () -> Unit, onClose: (() -> Unit)? = null) {
    val shape = RoundedCornerShape(16.dp)
    Row(
        Modifier.padding(start = 12.dp, end = 12.dp, top = 10.dp).fillMaxWidth().background(Ev.Gold.copy(alpha = 0.08f), shape).border(1.dp, Ev.Gold.copy(alpha = 0.3f), shape)
            .let { if (onClose != null) it.clickable(remember { MutableInteractionSource() }, null, onClick = onClose) else it }
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        BasicText(text, Modifier.weight(1f), style = RiftType.Body.copy(fontSize = 13.sp, lineHeight = 18.85.sp, color = Color.White))
        val pill = RoundedCornerShape(15.dp)
        Pressable(onAction, Modifier.height(30.dp).border(1.dp, Ev.Gold.copy(alpha = 0.6f), pill).padding(horizontal = 12.dp), pressedScale = 0.94f, label = "Add a Riot password, opens your browser") {
            BasicText(action, style = RiftType.Body.copy(fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Ev.Gold))
        }
    }
}

/** `.wmenu`: pops from the top right; tapping beside it closes it. */
@Composable
private fun Menu(onClose: () -> Unit, items: List<Pair<String, () -> Unit>>) {
    val t = remember { Animatable(0f) }
    LaunchedEffect(Unit) { t.animateTo(1f, tween(360, easing = RiftEase)) }
    Box(Modifier.fillMaxSize().clickable(remember { MutableInteractionSource() }, null, onClick = onClose)) {
        val shape = RoundedCornerShape(20.dp)
        Column(
            Modifier.align(Alignment.TopEnd).padding(top = 52.dp, end = 12.dp).width(230.dp)
                .graphicsLayer {
                    alpha = t.value
                    val sc = 0.94f + 0.06f * t.value
                    scaleX = sc
                    scaleY = sc
                    translationY = -6.dp.toPx() * (1f - t.value)
                    transformOrigin = TransformOrigin(1f, 0f)
                }
                .background(Color(0xFF121212), shape).border(1.dp, Color.White.copy(alpha = 0.14f), shape).padding(6.dp),
        ) {
            items.forEachIndexed { i, (label, action) ->
                Pressable({ onClose(); action() }, Modifier.fillMaxWidth().height(46.dp), pressedScale = 0.98f, contentAlignment = Alignment.CenterStart) {
                    BasicText(label, Modifier.padding(horizontal = 12.dp), style = RiftType.Body.copy(fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = if (i == items.lastIndex) Ev.Red else Color.White))
                }
            }
        }
    }
}
