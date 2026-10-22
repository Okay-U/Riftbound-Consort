package pitopia.riftcount.settings

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import java.io.File
import kotlinx.coroutines.delay
import pitopia.riftcount.data.AppSettings
import pitopia.riftcount.platform.Haptic
import pitopia.riftcount.platform.haptic
import pitopia.riftcount.score.ScoreController
import pitopia.riftcount.tour.TourKind
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.Rise
import pitopia.riftcount.ui.common.ToastHost
import pitopia.riftcount.ui.common.Toaster
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

private enum class SubPage(val title: String) {
    Colors("Player colors"), Bug("Report a bug"), Wish("Wish a feature"), Ack("Acknowledgments"), Log("PlayRiftbound log"), Rules("Rules, FAQs and errata"),
}

/** The Settings tab (SettingsHybrid): flip tiles for the switches used most, then grouped rows; sub pages slide in. */
@Composable
fun SettingsScreen(score: ScoreController, logFile: File, bottomReserve: Dp, onTour: (TourKind) -> Unit, onOverlay: (Boolean) -> Unit) {
    val toaster = remember { Toaster() }
    var sub by remember { mutableStateOf<SubPage?>(null) }
    var subShown by remember { mutableStateOf(false) }
    // Colours live in prefs; this tells the Player colors row to read them again.
    var colorsRev by remember { mutableIntStateOf(0) }
    val push = remember { Animatable(0f) }
    LaunchedEffect(subShown) {
        push.animateTo(if (subShown) 1f else 0f, tween(620, easing = RiftEase))
        if (!subShown) sub = null
    }
    val report by rememberUpdatedState(onOverlay)
    LaunchedEffect(subShown) {
        if (!subShown) delay(180)
        report(subShown)
    }
    DisposableEffect(Unit) { onDispose { report(false) } }
    BackHandler(enabled = subShown) { subShown = false }
    fun open(page: SubPage) {
        sub = page
        subShown = true
    }

    Box(Modifier.fillMaxSize()) {
        Column(
            Modifier.fillMaxSize().graphicsLayer {
                translationX = -0.26f * size.width * push.value
                alpha = 1f - 0.82f * push.value
            },
        ) {
            BasicText("Settings", Modifier.statusBarsPadding().padding(start = 20.dp, end = 20.dp, top = 6.dp), style = RiftType.Title.copy(color = Color.White))
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = bottomReserve + 30.dp)) {
                MainList(score, colorsRev, toaster, onTour, ::open)
            }
        }
        sub?.let { page ->
            Column(
                Modifier.fillMaxSize().graphicsLayer { translationX = size.width * (1f - push.value) }.background(RiftColors.Page)
                    .clickable(remember { MutableInteractionSource() }, null) {}
                    .statusBarsPadding().navigationBarsPadding().imePadding(),
            ) {
                SubHeader(page.title) { subShown = false }
                Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = 40.dp)) {
                    // Keyed: a page opened while the last one slides out starts empty.
                    key(page) { SubContent(page, score, logFile, toaster, onColors = { colorsRev++ }) { subShown = false } }
                }
            }
        }
        ToastHost(toaster)
    }
}

@Composable
private fun ColumnScope.MainList(score: ScoreController, colorsRev: Int, toaster: Toaster, onTour: (TourKind) -> Unit, open: (SubPage) -> Unit) {
    val context = LocalContext.current
    val view = LocalView.current
    val players = score.state.players.size
    fun outside(ok: Boolean) {
        if (!ok) toaster.show("No app on this phone can open that")
    }
    Rise(true, 0) { SectionHead("Most used", "Tap i for what it does") }
    Tiles(players, toaster, onPlayers = { score.setPlayers(if (players == 2) 4 else 2) }, onHaptics = { if (it) view.haptic(Haptic.Tick) })

    Section("Scoreboard", 320) {
        key(colorsRev, players) {
            LinkRow(
                "Player colors", SettingsIcons.Colors, colorsSummary(players), divider = false,
                trailing = { ColorDots(players) },
            ) { open(SubPage.Colors) }
        }
    }
    Section("Help", 390) {
        LinkRow("Show the general tour", SettingsIcons.Tour, divider = false) { onTour(TourKind.Main) }
        LinkRow("Events and tournaments tour", SettingsIcons.Trophy) { onTour(TourKind.Events) }
        LinkRow("Rules, FAQs and errata", SettingsIcons.Book, "Riot's rulebook, tournament rules, set FAQs") { open(SubPage.Rules) }
    }
    Section("About", 460) {
        LinkRow("Acknowledgments", SettingsIcons.Heart, divider = false) { open(SubPage.Ack) }
        LinkRow("PlayRiftbound log", SettingsIcons.Log) { open(SubPage.Log) }
        LinkRow("Report a bug", SettingsIcons.Bug) { open(SubPage.Bug) }
        LinkRow("Wish a feature", SettingsIcons.Wish) { open(SubPage.Wish) }
        LinkRow("Share Riftcount with friends", SettingsIcons.Share, external = true) { outside(Support.share(context)) }
        LinkRow("Rate it on Google Play", SettingsIcons.Star, external = true) { outside(Support.rate(context)) }
        LinkRow("Buy me a coffee", SettingsIcons.Coffee, external = true) { outside(Support.open(context, Support.KOFI)) }
        LinkRow("Support and privacy", SettingsIcons.Shield, external = true) { outside(Support.open(context, Support.PRIVACY)) }
    }
    Rise(true, 530, Modifier.padding(top = 30.dp, bottom = 10.dp)) {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            BasicText("RIFTCOUNT", style = RiftType.Title.copy(fontSize = 22.sp, lineHeight = 26.sp, letterSpacing = 0.04.em, color = Color.White))
            BasicText(
                "Score Tracker · Version ${remember { Support.version(context) }} · Android",
                style = FootText.copy(textAlign = TextAlign.Center),
            )
        }
    }
}

@Composable
private fun Section(title: String, delayMs: Int, rows: @Composable ColumnScope.() -> Unit) {
    Rise(true, delayMs, Modifier.padding(top = 22.dp)) {
        Column {
            SectionHead(title)
            Group(content = rows)
        }
    }
}

private val TileInfo = listOf(
    "A tick on every point and a stronger pulse when a game is won.",
    "The phone does not sleep while Riftcount is open.",
    "Pure #000 background. Saves battery on OLED screens and looks deepest.",
    "In a live tournament the scoreboard shows your table, opponent and a Report button.",
    "2 is the face-to-face duel. 4 splits the table for free-for-all games.",
)

@Composable
private fun Tiles(players: Int, toaster: Toaster, onPlayers: () -> Unit, onHaptics: (Boolean) -> Unit) {
    val switches = listOf(
        Triple("Haptics", SettingsIcons.Haptics, AppSettings.haptics),
        Triple("Keep screen on", SettingsIcons.Awake, AppSettings.keepScreenOn),
        Triple("True black", SettingsIcons.Black, AppSettings.trueBlack),
        Triple("Match mode", SettingsIcons.Match, AppSettings.matchMode),
    )
    Column(Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        // The switches, then Players; an odd one out takes the whole row.
        (0..switches.size).chunked(2).forEach { pair ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                pair.forEach { i ->
                    Rise(true, 60 + i * 45, Modifier.weight(1f)) {
                        if (i < switches.size) {
                            val (label, icon, flag) = switches[i]
                            FlipTile(label, TileInfo[i], darkInfo = flag.on) {
                                SwitchFace(label, icon, flag.on) {
                                    flag.on = !flag.on
                                    when (flag) {
                                        AppSettings.haptics -> onHaptics(flag.on)
                                        AppSettings.trueBlack -> toaster.show(if (flag.on) "True black · pure #000 for OLED" else "Dark grey background")
                                    }
                                }
                            }
                        } else {
                            FlipTile("Players", TileInfo[i], darkInfo = false) { PlayersFace(players, onPlayers) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SubHeader(title: String, onBack: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 6.dp, bottom = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Pressable(
            onBack,
            Modifier.size(42.dp).background(Color.White.copy(alpha = 0.06f), CircleShape).border(1.dp, Color.White.copy(alpha = 0.14f), CircleShape),
            pressedScale = 0.92f,
            label = "Back to settings",
        ) { Image(SettingsIcons.Back, "Back to settings", colorFilter = ColorFilter.tint(Color.White)) }
        BasicText(
            title,
            style = RiftType.Title.copy(fontSize = 34.sp, lineHeight = 34.sp, color = Color.White),
            maxLines = 1,
            autoSize = TextAutoSize.StepBased(22.sp, 34.sp, 1.sp),
        )
    }
}

@Composable
private fun SubContent(page: SubPage, score: ScoreController, logFile: File, toaster: Toaster, onColors: () -> Unit, close: () -> Unit) {
    val context = LocalContext.current
    val open = { url: String -> if (!Support.open(context, url)) toaster.show("No app on this phone can open that") }
    when (page) {
        SubPage.Colors -> ColorsPage(score.state.players.size, toaster::show, onColors)
        SubPage.Bug, SubPage.Wish -> FormPage(page == SubPage.Bug) { subject, body ->
            if (Support.mail(context, subject, body)) {
                close()
                toaster.show(if (page == SubPage.Bug) "Opens your mail app with the report" else "Thanks! Opens your mail app")
            } else {
                toaster.show("No mail app · write to ${Support.EMAIL}")
            }
        }
        SubPage.Ack -> AckPage(open)
        SubPage.Log -> LogPage(logFile, toaster::show)
        SubPage.Rules -> RulesPage(open)
    }
}
