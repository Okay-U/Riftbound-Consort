package pitopia.riftcount.decks

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
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
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.GraphicsLayerScope
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.compose.ui.util.lerp
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.roundToInt
import kotlinx.coroutines.delay
import pitopia.riftcount.data.Decklist
import pitopia.riftcount.data.GameRecord
import pitopia.riftcount.score.OPPONENT
import pitopia.riftcount.score.YOU
import pitopia.riftcount.ui.common.RoundIcon
import pitopia.riftcount.ui.common.softBlur
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

private val Back = CubicBezierEasing(0.2f, 0f, 0f, 1f)
private val PanelBg = Color(0xFF0B0B0B)

/**
 * The match log grows out of the tile that opened it (640ms) and shrinks back into it; deck chips filter it,
 * a game opens its review.
 */
@Composable
fun LogPanel(
    from: Rect,
    shown: Boolean,
    deckId: String?,
    decks: List<Decklist>,
    games: List<GameRecord>,
    onFilter: (String?) -> Unit,
    onClose: () -> Unit,
    onOpenGame: (GameRecord) -> Unit,
) {
    val screen = LocalWindowInfo.current.containerSize
    val t = remember { Animatable(0f) }
    LaunchedEffect(shown) { if (shown) t.animateTo(1f, tween(640, easing = RiftEase)) else t.animateTo(0f, tween(500, easing = Back)) }
    val content = remember { Animatable(0f) }
    LaunchedEffect(shown) { if (shown) content.animateTo(1f, tween(650, 220, RiftEase)) else content.animateTo(0f, tween(180)) }
    Box(Modifier.fillMaxSize()) {
        Box(
            Modifier.layout { measurable, _ ->
                val p = t.value
                val placeable = measurable.measure(
                    Constraints.fixed(lerp(from.width, screen.width.toFloat(), p).roundToInt(), lerp(from.height, screen.height.toFloat(), p).roundToInt()),
                )
                layout(0, 0) { placeable.place(lerp(from.left, 0f, p).roundToInt(), lerp(from.top, 0f, p).roundToInt()) }
            }.graphicsLayer {
                clip = true
                shape = RoundedCornerShape((24 * (1f - t.value)).dp)
                // Closing, the panel dissolves into the tile below as it shrinks, instead of landing as a black box.
                alpha = if (shown) 1f else (t.value / 0.6f).coerceIn(0f, 1f)
            }.background(PanelBg)
                .clickable(remember { MutableInteractionSource() }, indication = null) {},
        )
        val filtered = games.filter { deckId == null || it.deckId.equals(deckId, true) }
        Column(Modifier.fillMaxSize().statusBarsPadding().graphicsLayer { faded(content.value) }) {
            Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 18.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                PanelIcon(DeckIcons.Down, "Collapse", onClose)
                Spacer(Modifier.width(12.dp))
                Column {
                    BasicText((decks.firstOrNull { it.id == deckId }?.name ?: "All decks").uppercase(), style = SmallCaps)
                    BasicText("Match log", style = RiftType.Title.copy(fontSize = 30.sp, lineHeight = 30.sp, color = Color.White))
                }
            }
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).navigationBarsPadding().padding(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 40.dp)) {
                Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(bottom = 12.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    GlowChip("All decks", deckId == null) { onFilter(null) }
                    decks.forEach { d -> GlowChip(d.name, d.id == deckId) { onFilter(d.id) } }
                }
                Column(Modifier.replayOn(deckId)) {
                    val tally = Tally.of(filtered)
                    val (first, second) = MatchLog.firstSecond(filtered)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        SumTile("Record", tally.text)
                        SumTile("Win rate", if (tally.games > 0) "${Math.round(tally.rate * 100)}%" else "–", RiftColors.You)
                    }
                    Spacer(Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        SumTile("Avg game", MatchLog.averageMinutes(filtered)?.let { "$it min" } ?: "–")
                        SumTile("First · second", "${first.text} · ${second.text}")
                    }
                    Spacer(Modifier.height(6.dp))
                    if (filtered.isEmpty()) {
                        BasicText("No games yet. Finished games on the scoreboard land here.", Modifier.padding(top = 18.dp), style = SheetText)
                    }
                    filtered.forEach { g -> GameRow(g, decks, showDeck = deckId == null) { onOpenGame(g) } }
                }
            }
        }
    }
}

private fun GraphicsLayerScope.faded(v: Float) {
    alpha = v
    translationY = 12.dp.toPx() * (1f - v)
    val b = 8.dp.toPx() * (1f - v)
    renderEffect = softBlur(b)
}

/** A filter change replays the list's rise. */
@Composable
private fun Modifier.replayOn(key: Any?): Modifier {
    val t = remember(key) { Animatable(0f) }
    LaunchedEffect(key) { t.animateTo(1f, tween(560, easing = RiftEase)) }
    return graphicsLayer { faded(t.value) }
}

val SmallCaps = RiftType.Caption.copy(letterSpacing = 0.12.em, color = Color.White.copy(alpha = 0.6f))

@Composable
fun PanelIcon(icon: ImageVector, label: String, onClick: () -> Unit) {
    RoundIcon(onClick, label, Modifier.border(1.dp, Color.White.copy(alpha = 0.14f), CircleShape), fill = Color.White.copy(alpha = 0.06f)) {
        Image(icon, null, colorFilter = ColorFilter.tint(Color.White))
    }
}

/** The log's filter chip: green with a glow when on. */
@Composable
fun GlowChip(label: String, on: Boolean, color: Color = RiftColors.You, onClick: () -> Unit) = OnOffChip(label, on, color, onClick = onClick)

@Composable
private fun RowScope.SumTile(label: String, value: String, color: Color = Color.White) {
    val shape = RoundedCornerShape(22.dp)
    Column(
        Modifier.weight(1f).height(88.dp).background(Color.White.copy(alpha = 0.05f), shape).border(1.dp, Color.White.copy(alpha = 0.08f), shape)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        BasicText(label.uppercase(), style = RiftType.Caption.copy(fontSize = 10.5.sp, letterSpacing = 0.14.em, color = Color.White.copy(alpha = 0.6f)))
        BasicText(value, style = RiftType.Title.copy(fontSize = 30.sp, lineHeight = 30.sp, color = color), maxLines = 1)
    }
}

@Composable
private fun GameRow(g: GameRecord, decks: List<Decklist>, showDeck: Boolean, onClick: () -> Unit) {
    val deck = decks.firstOrNull { it.id.equals(g.deckId, true) }?.name ?: g.deckName
    Row(
        Modifier.fillMaxWidth().height(66.dp).clickable(remember { MutableInteractionSource() }, indication = null, role = Role.Button, onClick = onClick)
            .drawBehind { drawRect(Color.White.copy(alpha = 0.07f), Offset(0f, size.height - 1.dp.toPx()), Size(size.width, 1.dp.toPx())) }
            .semantics { contentDescription = "${if (g.won) "Won" else "Lost"} against ${opponentShort(g.opponent)}" }
            .padding(horizontal = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        ResultDot(g.won, 34.dp, 17.sp)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            BasicText("vs ${opponentShort(g.opponent)}", style = RiftType.Body.copy(fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Color.White))
            BasicText(
                listOfNotNull(deck?.takeIf { showDeck }, shortDate(g.date), "${Math.round(g.durationSeconds / 60.0)} min").joinToString(" · "),
                Modifier.padding(top = 2.dp),
                style = RiftType.Body.copy(fontSize = 12.sp, color = Color.White.copy(alpha = 0.58f)), maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
        }
        MatchLog.score(g)?.let { (a, b) -> BasicText("$a–$b", style = RiftType.Title.copy(fontSize = 22.sp, lineHeight = 22.sp, color = Color.White)) }
    }
}

/** One game in full: the result, the race to 8 in two lanes, every point with the score after it. Slides in from the right. */
@Composable
fun GameReview(game: GameRecord, decks: List<Decklist>, shown: Boolean, onBack: () -> Unit, onEdit: () -> Unit) {
    val t = remember { Animatable(0f) }
    LaunchedEffect(shown) { t.animateTo(if (shown) 1f else 0f, tween(620, easing = RiftEase)) }
    val deck = decks.firstOrNull { it.id.equals(game.deckId, true) }?.name ?: game.deckName
    val opp = opponentShort(game.opponent)
    val score = MatchLog.score(game)
    Column(
        Modifier.fillMaxSize().graphicsLayer { translationX = size.width * (1f - t.value) }.background(Color(0xFF050505))
            .clickable(remember { MutableInteractionSource() }, indication = null) {}.statusBarsPadding(),
    ) {
        Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 18.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically) {
            PanelIcon(DeckIcons.Back, "Back", onBack)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                BasicText(longDate(game.date).uppercase(), style = SmallCaps)
                BasicText("vs $opp", style = RiftType.Title.copy(fontSize = 30.sp, lineHeight = 30.sp, color = Color.White), maxLines = 1)
            }
            PanelIcon(DeckIcons.Edit, "Edit game", onEdit)
        }
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).navigationBarsPadding().padding(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 40.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                val result = (if (game.won) "Won" else "Lost") + (score?.let { (a, b) -> " $a–$b" } ?: "")
                SumTile("Result", result, if (game.won) RiftColors.You else Violet)
                SumTile(
                    when (game.startedFirst) {
                        true -> "Went first"
                        false -> "Went second"
                        null -> "Duration"
                    },
                    "${Math.round(game.durationSeconds / 60.0)} min",
                )
            }
            val points = MatchLog.points(game)
            BasicText(listOfNotNull("RACE TO 8", deck?.uppercase()).joinToString(" · "), Modifier.padding(top = 16.dp, bottom = 8.dp), style = SmallCaps)
            val lanes = MatchLog.race(game)
            Column(Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Lane("You", lanes[YOU].orEmpty(), RiftColors.You)
                Lane(opp, lanes[OPPONENT].orEmpty(), Violet)
            }
            BasicText("POINT BY POINT", Modifier.padding(top = 16.dp, bottom = 8.dp), style = SmallCaps)
            if (points.isEmpty()) {
                BasicText("This game was saved without a point log, so only the result is known.", Modifier.padding(top = 6.dp), style = RiftType.Body.copy(fontSize = 14.sp, lineHeight = 21.sp, color = Color.White.copy(alpha = 0.75f)))
            }
            points.forEach { p ->
                Row(
                    Modifier.fillMaxWidth().height(42.dp).drawBehind { drawRect(Color.White.copy(alpha = 0.06f), Offset(0f, size.height - 1.dp.toPx()), Size(size.width, 1.dp.toPx())) },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    BasicText(MatchLog.clock(p.seconds), Modifier.width(46.dp), style = RiftType.Title.copy(fontSize = 14.sp, lineHeight = 14.sp, fontWeight = FontWeight.ExtraBold, color = Color.White.copy(alpha = 0.6f)))
                    val you = p.slot == YOU
                    BasicText(
                        if (you) "You" else opp,
                        Modifier.height(24.dp).background(if (you) RiftColors.You else Violet, RoundedCornerShape(12.dp)).padding(horizontal = 10.dp, vertical = 5.dp),
                        style = RiftType.Body.copy(fontSize = 11.sp, lineHeight = 14.sp, fontWeight = FontWeight.Bold, color = Color.Black),
                    )
                    BasicText(
                        kindLabel(p.kind, p.delta), Modifier.weight(1f).padding(start = 10.dp),
                        style = RiftType.Body.copy(fontSize = 13.5.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.8f)),
                    )
                    BasicText("${p.you}–${p.them}", style = RiftType.Title.copy(fontSize = 18.sp, lineHeight = 18.sp, color = Color.White))
                }
            }
        }
    }
}

private fun kindLabel(kind: String, delta: Int) = when (kind) {
    "conquer" -> "Conquer"
    "hold" -> "Hold"
    else -> if (delta < 0) "Fix $delta" else "Effect +$delta"
}

/** Eight steps per player; a conquer lights fully, a hold softer (the mock). */
@Composable
private fun Lane(name: String, points: List<String>, color: Color) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        BasicText(name, Modifier.width(62.dp), style = RiftType.Body.copy(fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.7f)), maxLines = 1, overflow = TextOverflow.Ellipsis)
        Spacer(Modifier.width(10.dp))
        Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            repeat(8) { i ->
                val kind = points.getOrNull(i)
                val pop = remember { Animatable(0f) }
                LaunchedEffect(Unit) {
                    delay(200L + i * 70L)
                    pop.animateTo(1f, tween(520, easing = RiftEase))
                }
                Box(
                    Modifier.weight(1f).height(22.dp).graphicsLayer { alpha = pop.value; scaleX = 0.6f + 0.4f * pop.value; scaleY = scaleX }
                        .background(
                            when (kind) {
                                null -> Color.White.copy(alpha = 0.06f)
                                "conquer" -> color
                                else -> color.copy(alpha = 0.6f)
                            },
                            RoundedCornerShape(6.dp),
                        ),
                )
            }
        }
    }
}

/** "Wed, Oct 22 · 21:40". */
fun longDate(ms: Long): String = SimpleDateFormat("EEE, MMM d · HH:mm", Locale.US).format(Date(ms))
