package pitopia.riftcount.tour

import androidx.activity.compose.BackHandler
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import pitopia.riftcount.cards.CardStyle
import pitopia.riftcount.settings.SettingsIcons
import pitopia.riftcount.ui.common.GlowButton
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.Rise
import pitopia.riftcount.ui.shell.NavIcons
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

enum class TourKind { Main, Events }

private class Page(val icon: ImageVector, val accent: Color, val title: String, val subtitle: String, val points: List<Pair<String, String>>)

/**
 * The first-launch tour (iOS `OnboardingView`, six pages, `didOnboard`) and the Events tour (iOS
 * `EventsOnboardingView`, `didOnboardEvents`), with this app's tabs. No mock: built from the mocks' parts.
 */
@Composable
fun Tour(kind: TourKind, onDone: () -> Unit) {
    val pages = if (kind == TourKind.Main) MainPages else EventsPages
    val pager = rememberPagerState { pages.size }
    val scope = rememberCoroutineScope()
    var seen by remember { mutableStateOf(setOf(0)) }
    LaunchedEffect(pager.currentPage) { seen = seen + pager.currentPage }
    val last = pager.currentPage == pages.lastIndex
    BackHandler {
        if (pager.currentPage > 0) scope.launch { pager.animateScrollToPage(pager.currentPage - 1) } else onDone()
    }
    val accent by animateColorAsState(pages[pager.currentPage].accent, tween(500), label = "accent")

    Box(
        Modifier.fillMaxSize().background(RiftColors.Page)
            .clickable(remember { MutableInteractionSource() }, null) {},
    ) {
        HorizontalPager(pager, Modifier.fillMaxSize()) { i -> TourPage(pages[i], i in seen) }
        val skip by animateFloatAsState(if (last) 0f else 1f, tween(300), label = "skip")
        if (skip > 0f) {
            Pill(
                "Skip",
                Modifier.align(Alignment.TopEnd).statusBarsPadding().padding(top = 14.dp, end = 18.dp).graphicsLayer { alpha = skip },
                onDone,
            )
        }
        Column(
            Modifier.align(Alignment.BottomCenter).fillMaxWidth().navigationBarsPadding().padding(start = 24.dp, end = 24.dp, bottom = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Dots(pages.size, pager.currentPage, accent)
            GlowButton(if (last) "Get started" else "Next", enabled = true) {
                if (last) onDone() else scope.launch { pager.animateScrollToPage(pager.currentPage + 1) }
            }
        }
    }
}

@Composable
private fun TourPage(page: Page, shown: Boolean) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding()
            .padding(start = 24.dp, end = 24.dp, top = 76.dp, bottom = 150.dp),
    ) {
        Rise(shown, 0) {
            Box(
                Modifier.size(84.dp).dropShadow(CircleShape, Shadow(30.dp, page.accent.copy(alpha = 0.3f)))
                    .background(page.accent.copy(alpha = 0.14f), CircleShape).border(1.dp, page.accent.copy(alpha = 0.4f), CircleShape),
                contentAlignment = Alignment.Center,
            ) { Image(page.icon, null, Modifier.size(34.dp), colorFilter = ColorFilter.tint(page.accent)) }
        }
        Rise(shown, 80, Modifier.padding(top = 26.dp)) { BasicText(page.title, style = RiftType.Title.copy(color = Color.White)) }
        Rise(shown, 140, Modifier.padding(top = 8.dp)) {
            BasicText(page.subtitle, style = RiftType.Body.copy(fontSize = 16.sp, lineHeight = 22.sp, color = Color.White.copy(alpha = 0.7f)))
        }
        page.points.forEachIndexed { i, (title, detail) ->
            Rise(shown, 200 + i * 60, Modifier.padding(top = if (i == 0) 28.dp else 16.dp)) { Point(title, detail, page.accent) }
        }
    }
}

@Composable
private fun Point(title: String, detail: String, accent: Color) {
    Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Box(
            Modifier.padding(top = 6.dp).size(8.dp).dropShadow(CircleShape, Shadow(8.dp, accent.copy(alpha = 0.6f))).background(accent, CircleShape),
        )
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            BasicText(title, style = RiftType.Body.copy(fontSize = 15.5.sp, lineHeight = 20.sp, fontWeight = FontWeight.SemiBold, color = Color.White))
            BasicText(detail, style = RiftType.Body.copy(fontSize = 13.sp, lineHeight = 18.sp, color = Color.White.copy(alpha = 0.6f)))
        }
    }
}

@Composable
private fun Dots(count: Int, current: Int, accent: Color) {
    Row(Modifier.clearAndSetSemantics {}, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
        repeat(count) { i ->
            val width by animateDpAsState(if (i == current) 22.dp else 7.dp, tween(300, easing = RiftEase), label = "dot")
            Box(Modifier.width(width).height(7.dp).background(if (i == current) accent else Color.White.copy(alpha = 0.3f), RoundedCornerShape(4.dp)))
        }
    }
}

@Composable
private fun Pill(text: String, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(50)
    Pressable(
        onClick,
        modifier.background(Color.White.copy(alpha = 0.06f), shape).border(1.dp, Color.White.copy(alpha = 0.12f), shape)
            .padding(horizontal = 14.dp, vertical = 8.dp),
    ) {
        BasicText(text, style = RiftType.Body.copy(fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.7f)))
    }
}

private val MainPages = listOf(
    Page(
        SettingsIcons.Trophy, RiftColors.Gold, "Riftcount", "Score tracker and more for Riftbound TCG",
        listOf("See what's new" to "with our latest version", "Show this app to your friends" to "while playing :)"),
    ),
    Page(
        NavIcons.Score, RiftColors.You, "Scoreboard", "Track every point with one tap",
        listOf(
            "Conquer, hold, effect" to "One tap per point; the 8th by conquering is checked",
            "Track XP" to "Gain and spend XP right on your half",
            "Who goes first" to "Roll the dice in the middle, D6 or D20",
            "Best of three" to "Games, series and the match clock carry on",
            "Pick decks" to "Tap a name to choose your deck and your opponent's legend",
            "Undo" to "Rewind step by step when you misclick",
        ),
    ),
    Page(
        NavIcons.Events, RiftColors.Opponent, "Events", "Your tournament companion",
        listOf(
            "Follow your events" to "Standings, pairings and results, live",
            "Find local stores" to "Search, save favorites, see their calendar",
            "Play connected" to "Link a tournament match to your Scoreboard",
        ),
    ),
    Page(
        NavIcons.Cards, CardStyle.domainColor("mind"), "Cards", "Browse the whole pool",
        listOf(
            "Search" to "Find any card by name, type, or text",
            "Filter" to "Narrow by domain, type, energy, might, more",
            "Sort" to "By set, energy or type",
            "Card view" to "Tap any card for full art and details",
            "Add to a deck" to "Straight from the card, three copies at most",
        ),
    ),
    Page(
        NavIcons.Decks, CardStyle.domainColor("body"), "Decks", "Build, browse, analyze",
        listOf(
            "Build wizard" to "Legend → champion → battlefields → cards → runes",
            "Draw hand" to "Simulate openings with a mulligan",
            "Draw odds" to "Chance to draw key cards by turn N",
            "Deck stats" to "Energy curve, power by domain, type breakdown",
            "Import / Export" to "Copy decklists as text, paste in or share out",
            "Match log" to "Every game with its point race and turn order",
        ),
    ),
    Page(
        NavIcons.Settings, RiftColors.You, "Make it yours", "Tweak in Settings whenever",
        listOf(
            "Player colors" to "16 colors, one per seat",
            "Stay awake" to "The screen stays on during games",
            "Haptics" to "Toggle feedback to taste",
            "True black" to "Pure black for OLED screens, or a dark grey",
        ),
    ),
)

private val EventsPages = listOf(
    Page(
        SettingsIcons.Trophy, RiftColors.You, "Events", "Your tournament companion for Riftbound.",
        listOf(
            "Follow your events" to "Standings, pairings and results, live.",
            "Find local stores" to "Search, save favorites, see their calendar.",
            "Play connected" to "Link a tournament match to your Scoreboard.",
        ),
    ),
    Page(
        SettingsIcons.Shield, RiftColors.You, "Sign in", "Use your Riot ID on PlayRiftbound.",
        listOf(
            "Riot's own pages" to "Sign in happens in the PlayRiftbound segment, never in the app.",
            "Nothing stored by us" to "Your session stays in the in-app browser on your device.",
            "Sign out anytime" to "From the menu in the PlayRiftbound segment.",
        ),
    ),
    Page(
        SettingsIcons.Heart, RiftColors.You, "Find your stores", "Discover and save the shops you play at.",
        listOf(
            "Search by city" to "Events and stores nearby, with the site's filters.",
            "Save favorites" to "Tap the heart on any store.",
            "Store calendar" to "Every event at your saved stores, by date.",
        ),
    ),
    Page(
        NavIcons.Events, RiftColors.You, "Register in seconds", "Sign up for events right here.",
        listOf(
            "Browse events" to "Upcoming, live and past.",
            "Sign up" to "Register with your Riot account, pay at the store.",
            "Drop anytime" to "Change your mind with one tap.",
        ),
    ),
    Page(
        SettingsIcons.Log, RiftColors.You, "Live, in the app", "No more juggling the website during rounds.",
        listOf(
            "Pairings and your table" to "Know exactly where to sit each round.",
            "Live standings" to "Track your place as rounds finish.",
            "Report results" to "Submit your match without leaving the app.",
            "Can I draw?" to "Your top-cut outlook, shown automatically.",
        ),
    ),
    Page(
        SettingsIcons.Match, RiftColors.You, "Match mode", "Score and report from the Scoreboard.",
        listOf(
            "Turn it on in Settings" to "One tap in Most used.",
            "Table and opponent" to "Shown right on your Scoreboard.",
            "Report on the spot" to "Send your result the moment you finish.",
        ),
    ),
)
