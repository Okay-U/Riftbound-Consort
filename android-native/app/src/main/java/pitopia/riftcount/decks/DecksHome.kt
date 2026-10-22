package pitopia.riftcount.decks

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlurEffect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.toSize
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.delay
import pitopia.riftcount.cards.Card
import pitopia.riftcount.data.DeckRules
import pitopia.riftcount.data.Decklist
import pitopia.riftcount.data.GameRecord
import pitopia.riftcount.ui.common.RoundIcon
import pitopia.riftcount.ui.common.lineIcon
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

/** Line icons of the Decks mock. */
object DeckIcons {
    val Import = lineIcon("M12 3v12M7 10l5 5 5-5M4 19h16", 19.dp)
    val Export = lineIcon("M12 15V3M7 8l5-5 5 5M4 19h16", 18.dp)
    val Plus = lineIcon("M12 5v14M5 12h14", 24.dp, 2.4f)
    val Back = lineIcon("M19 12H5M11 18l-6-6 6-6", 20.dp, 2.2f)
    val Close = lineIcon("M6 6l12 12M18 6 6 18", 18.dp, 2.4f)
    val Down = lineIcon("m6 9 6 6 6-6", 20.dp, 2.2f)
    val Edit = lineIcon("M4 20h4L19 9l-4-4L4 16z", 18.dp)
    val Hand = lineIcon("M3.2 8.6 11.9 6.8 14.2 17.6 5.5 19.4zM12.8 6.8l8.7 1.8-2.3 10.8-8.7-1.8", 22.dp)
    val Odds = lineIcon("M19 5 5 19M4.5 7a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0M14.5 17a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0", 22.dp)
    val Stats = lineIcon("M4 20V12M10 20V6M16 20v-9M22 20H2", 22.dp)
    val Clock = lineIcon("M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0M12 7v5l3 2", 22.dp)
    val Check = lineIcon("m5 12 5 5 9-10", 13.dp, 3.4f)
    val Warn = lineIcon("M12 3 2 20h20zM12 10v4M12 17h.01", 18.dp, 2.2f)
}

val Violet = RiftColors.Opponent

/** "Legal" green, issues gold, "Draft" grey: the pile's chip. */
@Composable
fun LegalChip(status: String, modifier: Modifier = Modifier, onDark: Boolean = false) {
    val ink = when (status) {
        "Legal" -> RiftColors.You
        "Draft" -> Color.White.copy(alpha = 0.75f)
        else -> RiftColors.Gold
    }
    val border = when (status) {
        "Legal" -> RiftColors.You.copy(alpha = 0.5f)
        "Draft" -> Color.White.copy(alpha = 0.25f)
        else -> RiftColors.Gold.copy(alpha = 0.5f)
    }
    val shape = RoundedCornerShape(11.dp)
    BasicText(
        status.uppercase(),
        modifier.height(22.dp).let { if (onDark) it.background(Color.Black.copy(alpha = 0.35f), shape) else it }
            .border(1.dp, border, shape).padding(horizontal = 9.dp, vertical = 4.dp),
        style = RiftType.Caption.copy(fontSize = 10.sp, lineHeight = 13.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.08.em, color = ink),
        maxLines = 1,
    )
}

/** The table of piles, the new-deck spot, then the all-decks win rate and the last games. */
@Composable
fun DecksHome(
    decks: List<Decklist>,
    games: List<GameRecord>,
    index: Map<String, Card>,
    hiddenDeck: String?,
    hiddenTile: String?,
    bottomReserve: Dp,
    onOpenDeck: (Decklist, Rect) -> Unit,
    onNewDeck: () -> Unit,
    onImport: () -> Unit,
    onOpenLog: (String, Rect) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = bottomReserve + 30.dp)) {
        Row(Modifier.fillMaxWidth().statusBarsPadding().padding(start = 20.dp, end = 20.dp, top = 6.dp), verticalAlignment = Alignment.Bottom) {
            Column(Modifier.weight(1f)) {
                BasicText("Decks", style = RiftType.Title.copy(color = Color.White))
                BasicText(
                    "TAP A PILE TO OPEN IT", Modifier.padding(top = 6.dp),
                    style = RiftType.Caption.copy(fontSize = 11.5.sp, letterSpacing = 0.14.em, color = Color.White.copy(alpha = 0.62f)),
                )
            }
            RoundIcon(onImport, "Import a deck from text", Modifier.border(1.dp, Color.White.copy(alpha = 0.14f), CircleShape), fill = Color.White.copy(alpha = 0.06f)) {
                Image(DeckIcons.Import, null, colorFilter = ColorFilter.tint(Color.White))
            }
        }
        Column(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 18.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            val cells = decks.size + 1
            for (row in 0 until (cells + 1) / 2) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    for (col in 0..1) {
                        val i = row * 2 + col
                        Box(Modifier.weight(1f)) {
                            when {
                                i < decks.size -> PileCell(decks[i], games, index, i, hidden = decks[i].id == hiddenDeck, onOpenDeck)
                                i == decks.size -> NewDeckCell(i, onNewDeck)
                            }
                        }
                    }
                }
            }
        }
        val record = Tally.of(games)
        Row(Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 10.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            BasicText("ALL DECKS", style = SectionLabel)
            BasicText("${record.games} ${if (record.games == 1) "GAME" else "GAMES"}", style = SectionLabel)
        }
        Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            WinRateTile(games, hidden = hiddenTile == "win") { onOpenLog("win", it) }
            LastGamesTile(games, decks, hidden = hiddenTile == "last") { onOpenLog("last", it) }
        }
    }
}

val SectionLabel = RiftType.Caption.copy(letterSpacing = 0.16.em, color = Color.White.copy(alpha = 0.55f))

/** The mock's cellIn: up 16dp out of an 8dp blur, 70ms apart. */
@Composable
private fun rememberCellIn(index: Int): Animatable<Float, *> {
    val t = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        delay(index * 70L)
        t.animateTo(1f, tween(760, easing = RiftEase))
    }
    return t
}

private fun Modifier.cellIn(t: Animatable<Float, *>) = graphicsLayer {
    val v = t.value
    alpha = v
    translationY = 16.dp.toPx() * (1f - v)
    val b = 8.dp.toPx() * (1f - v)
    renderEffect = if (b > 0.5f) BlurEffect(b, b) else null
}

@Composable
private fun PileCell(deck: Decklist, games: List<GameRecord>, index: Map<String, Card>, i: Int, hidden: Boolean, onOpen: (Decklist, Rect) -> Unit) {
    val t = rememberCellIn(i)
    val coords = remember { arrayOfNulls<LayoutCoordinates>(1) }
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val lift by animateFloatAsState(if (pressed) 1f else 0f, tween(320, easing = RiftEase), label = "lift")
    val legend = deck.legend?.let { index[it.cardId] }
    val r = Tally.of(games.filter { it.deckId.equals(deck.id, true) })
    Column(
        Modifier.fillMaxWidth().height(262.dp).cellIn(t)
            .clickable(source, indication = null, role = Role.Button) {
                coords[0]?.takeIf { it.isAttached }?.let { onOpen(deck, Rect(it.positionInRoot(), it.size.toSize())) }
            }
            .semantics { contentDescription = "${deck.name}, ${legend?.title ?: "no legend"}" }
            .padding(top = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            Modifier.size(120.dp, 168.dp).onGloballyPositioned { coords[0] = it }
                .graphicsLayer {
                    alpha = if (hidden) 0f else 1f
                    translationY = -4.dp.toPx() * lift
                    rotationZ = -1.5f * lift
                },
        ) {
            PileStack(deck, legend)
        }
        Spacer(Modifier.height(10.dp))
        BasicText(deck.name, style = RiftType.Title.copy(fontSize = 21.sp, lineHeight = 21.sp, color = Color.White), maxLines = 1, overflow = TextOverflow.Ellipsis)
        BasicText(
            if (r.games > 0) "${r.text} · ${Math.round(r.rate * 100)}%" else "No games yet", Modifier.padding(top = 4.dp),
            style = RiftType.Body.copy(fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.62f)),
        )
        LegalChip(DeckRules.status(deck, index), Modifier.padding(top = 4.dp))
    }
}

/** Two card backs under the legend: the pile. */
@Composable
fun PileStack(deck: Decklist, legend: Card?, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(12.dp)
    Box(modifier.fillMaxSize()) {
        listOf(8f to 3f, 4f to 1.5f).forEach { (d, a) ->
            Box(
                Modifier.fillMaxSize().graphicsLayer { translationX = d.dp.toPx(); translationY = d.dp.toPx(); rotationZ = a }
                    .background(Brush.linearGradient(listOf(Color(0xFF242424), Color(0xFF0B0B0B))), shape)
                    .border(1.dp, Color.White.copy(alpha = 0.14f), shape),
            )
        }
        val density = LocalDensity.current
        ArtBox(
            legend, with(density) { 120.dp.roundToPx() },
            Modifier.fillMaxSize().dropShadow(shape, Shadow(radius = 30.dp, color = Color.Black.copy(alpha = 0.6f), offset = DpOffset(0.dp, 14.dp)))
                .clip(shape),
            alignment = Alignment.Center,
            initial = (legend?.title ?: deck.name).take(1),
        ) {
            Box(Modifier.fillMaxSize().bottomShade(0.55f))
            BasicText(
                "${deck.mainDeck.sumOf { it.count }}",
                Modifier.padding(8.dp).background(Color.Black.copy(alpha = 0.6f), RoundedCornerShape(11.dp)).padding(horizontal = 8.dp, vertical = 2.dp),
                style = RiftType.Title.copy(fontSize = 13.sp, lineHeight = 18.sp, fontWeight = FontWeight.ExtraBold, letterSpacing = 0.04.em, color = Color.White),
            )
            BasicText(
                legend?.name ?: "No legend yet",
                Modifier.align(Alignment.BottomCenter).padding(9.dp),
                style = RiftType.Body.copy(fontSize = 12.sp, lineHeight = 13.sp, fontWeight = FontWeight.Bold, color = Color.White, textAlign = TextAlign.Center),
                maxLines = 2, overflow = TextOverflow.Ellipsis,
            )
            Box(Modifier.fillMaxSize().border(1.dp, Color.White.copy(alpha = 0.2f), shape))
        }
    }
}

@Composable
private fun NewDeckCell(i: Int, onClick: () -> Unit) {
    val t = rememberCellIn(i)
    Column(
        Modifier.fillMaxWidth().height(262.dp).cellIn(t).clickable(remember { MutableInteractionSource() }, indication = null, role = Role.Button, onClick = onClick)
            .semantics { contentDescription = "Build a new deck" }.padding(top = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Column(
            Modifier.size(120.dp, 168.dp).drawBehind {
                drawRoundRect(
                    Color.White.copy(alpha = 0.3f), cornerRadius = CornerRadius(12.dp.toPx()),
                    style = Stroke(1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 4.dp.toPx()))),
                )
            },
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Image(DeckIcons.Plus, null, colorFilter = ColorFilter.tint(Color.White.copy(alpha = 0.75f)))
            BasicText("New deck", Modifier.padding(top = 8.dp), style = RiftType.Body.copy(fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.75f)))
        }
        Spacer(Modifier.height(10.dp))
        BasicText("Build", style = RiftType.Title.copy(fontSize = 21.sp, lineHeight = 21.sp, color = Color.White))
        BasicText("Seven steps on a light rail", Modifier.padding(top = 4.dp), style = RiftType.Body.copy(fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.62f)))
    }
}

private val TileShape = RoundedCornerShape(24.dp)

@Composable
private fun Tile(delayMs: Int, hidden: Boolean, label: String, onClick: (Rect) -> Unit, content: @Composable () -> Unit) {
    val t = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        delay(delayMs.toLong())
        t.animateTo(1f, tween(760, easing = RiftEase))
    }
    val coords = remember { arrayOfNulls<LayoutCoordinates>(1) }
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) 0.97f else 1f, tween(260, easing = RiftEase), label = "press")
    Column(
        Modifier.fillMaxWidth().onGloballyPositioned { coords[0] = it }.cellIn(t)
            .graphicsLayer { alpha = if (hidden) 0f else alpha; scaleX = scale; scaleY = scale }
            .background(Color(0xFF0D0D0D), TileShape).border(1.dp, Color.White.copy(alpha = 0.09f), TileShape)
            .clickable(source, indication = null, role = Role.Button) {
                coords[0]?.takeIf { it.isAttached }?.let { onClick(Rect(it.positionInRoot(), it.size.toSize())) }
            }
            .semantics { contentDescription = label }
            .padding(14.dp),
    ) { content() }
}

@Composable
private fun TileHead(left: String, right: String) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        val style = RiftType.Caption.copy(fontSize = 10.5.sp, letterSpacing = 0.14.em, color = Color.White.copy(alpha = 0.6f))
        BasicText(left, style = style)
        BasicText(right, style = style)
    }
}

/** Win rate across all decks: green arc over a violet ring, record, first/second split and the last five. */
@Composable
private fun WinRateTile(games: List<GameRecord>, hidden: Boolean, onClick: (Rect) -> Unit) {
    val all = Tally.of(games)
    val (first, second) = MatchLog.firstSecond(games)
    Tile(260, hidden, "Win rate across all decks, open the match log", onClick) {
        TileHead("WIN RATE", "${all.games} ${if (all.games == 1) "GAME" else "GAMES"}")
        Row(Modifier.padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            WinRing(all.rate.toFloat(), if (all.games > 0) "${Math.round(all.rate * 100)}%" else "–")
            Spacer(Modifier.width(16.dp))
            Column {
                BasicText(all.text, style = RiftType.Title.copy(fontSize = 32.sp, lineHeight = 32.sp, letterSpacing = 0.03.em, color = Color.White))
                BasicText(
                    if (all.games > 0) "Going first ${first.text} · second ${second.text}" else "Games from the scoreboard show up here.",
                    Modifier.padding(top = 4.dp),
                    style = RiftType.Body.copy(fontSize = 12.5.sp, color = Color.White.copy(alpha = 0.66f)),
                )
                Row(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                    games.take(5).forEach { g -> ResultDot(g.won, 18.dp, 10.sp) }
                }
            }
        }
    }
}

@Composable
private fun WinRing(rate: Float, text: String) {
    val t = remember { Animatable(0f) }
    LaunchedEffect(rate) { t.animateTo(rate, tween(1000, easing = RiftEase)) }
    Box(Modifier.size(84.dp), contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize()) {
            val w = 8.dp.toPx()
            val inset = w / 2 + 3.dp.toPx()
            val arcSize = Size(size.width - inset * 2, size.height - inset * 2)
            drawArc(Violet.copy(alpha = 0.35f), 0f, 360f, false, Offset(inset, inset), arcSize, style = Stroke(w))
            if (t.value > 0f) drawArc(RiftColors.You, -90f, 360f * t.value, false, Offset(inset, inset), arcSize, style = Stroke(w, cap = StrokeCap.Round))
        }
        BasicText(text, style = RiftType.Title.copy(fontSize = 26.sp, lineHeight = 26.sp, color = Color.White))
    }
}

/** W in green, L in violet. */
@Composable
fun ResultDot(won: Boolean, size: Dp, fontSize: TextUnit) {
    Box(Modifier.size(size).background(if (won) RiftColors.You else Violet, CircleShape), contentAlignment = Alignment.Center) {
        BasicText(if (won) "W" else "L", style = RiftType.Title.copy(fontSize = fontSize, lineHeight = fontSize, color = Color.Black))
    }
}

@Composable
private fun LastGamesTile(games: List<GameRecord>, decks: List<Decklist>, hidden: Boolean, onClick: (Rect) -> Unit) {
    Tile(320, hidden, "Last games, open the match log", onClick) {
        TileHead("MATCH LOG", "ALL ${games.size} ›")
        if (games.isEmpty()) {
            BasicText("No games yet.", Modifier.padding(top = 10.dp), style = RiftType.Body.copy(fontSize = 13.sp, color = Color.White.copy(alpha = 0.6f)))
        }
        games.take(3).forEach { g ->
            Row(Modifier.fillMaxWidth().height(38.dp), verticalAlignment = Alignment.CenterVertically) {
                ResultDot(g.won, 22.dp, 11.sp)
                Spacer(Modifier.width(10.dp))
                val deck = decks.firstOrNull { it.id.equals(g.deckId, true) }?.name ?: g.deckName
                BasicText(
                    buildAnnotatedString {
                        append("vs ${opponentShort(g.opponent)}")
                        pushStyle(SpanStyle(color = Color.White.copy(alpha = 0.55f), fontWeight = FontWeight.Medium))
                        append(listOfNotNull(deck, shortDate(g.date)).joinToString(" · ", prefix = " · "))
                        pop()
                    },
                    Modifier.weight(1f),
                    style = RiftType.Body.copy(fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color.White),
                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                )
                MatchLog.score(g)?.let { (a, b) ->
                    BasicText("$a–$b", style = RiftType.Title.copy(fontSize = 17.sp, lineHeight = 17.sp, color = Color.White))
                }
            }
        }
    }
}

/** "Darius" for "Darius - Hand of Noxus"; "Unknown" when nobody picked a legend. */
fun opponentShort(name: String) = name.substringBefore(" - ").substringBefore(",").trim().ifEmpty { "Unknown" }

/** "Oct 19" like the mock. */
fun shortDate(ms: Long): String = SimpleDateFormat("MMM d", Locale.US).format(Date(ms))
