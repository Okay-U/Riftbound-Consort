package pitopia.riftcount.decks

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
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
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.BlurEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.layout
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.toSize
import androidx.compose.ui.util.lerp
import kotlin.math.roundToInt
import kotlinx.coroutines.delay
import pitopia.riftcount.cards.Card
import pitopia.riftcount.cards.CardStyle
import pitopia.riftcount.data.DeckRules
import pitopia.riftcount.data.Decklist
import pitopia.riftcount.data.DecklistEntry
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.RoundIcon
import pitopia.riftcount.ui.common.Stepper
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

/** What the detail's buttons open. */
enum class DeckTool { Hand, Odds, Stats, Log, Export, Champion, Fields, Menu, Issues }

private val FlyBack = CubicBezierEasing(0.5f, 0f, 0.75f, 0f)
private val HeroHeight = 250.dp

/**
 * An open deck: the legend card grows from its pile into the banner (700ms), the champion and the three
 * battlefields fly out of the pile into their places, the rest rises in step by step.
 */
@Composable
fun DeckDetail(
    deck: Decklist,
    index: Map<String, Card>,
    pool: List<Card>,
    record: Tally,
    from: Rect,
    shown: Boolean,
    progress: () -> Float,
    onClose: () -> Unit,
    onChange: (Decklist) -> Unit,
    onTool: (DeckTool, Rect?) -> Unit,
) {
    val legend = deck.legend?.let { index[it.cardId] }
    val champion = deck.champion?.let { index[it.cardId] }
    val density = LocalDensity.current
    val screen = LocalWindowInfo.current.containerSize
    val heroPx = with(density) { (HeroHeight + WindowInsets.statusBars.getTop(this).toDp()).toPx() }
    val atHero by remember { derivedStateOf { shown && progress() >= 0.999f } }
    val backdrop by animateFloatAsState(if (shown) 1f else 0f, tween(420), label = "backdrop")
    val now = { System.currentTimeMillis() }

    Box(Modifier.fillMaxSize()) {
        Box(
            Modifier.fillMaxSize().graphicsLayer { alpha = backdrop }.background(Color.Black)
                .clickable(remember { MutableInteractionSource() }, indication = null) {},
        )
        // The morph: the pile's top card becomes the banner; layout-sized so the art crops instead of stretching.
        if (!atHero) {
            ArtBox(
                legend, screen.width, previewWidthPx = with(density) { 120.dp.roundToPx() },
                modifier = Modifier.layout { measurable, _ ->
                    val p = progress()
                    val w = lerp(from.width, screen.width.toFloat(), p).roundToInt()
                    val h = lerp(from.height, heroPx, p).roundToInt()
                    val placeable = measurable.measure(Constraints.fixed(w, h))
                    layout(0, 0) { placeable.place(lerp(from.left, 0f, p).roundToInt(), lerp(from.top, 0f, p).roundToInt()) }
                }.graphicsLayer {
                    clip = true
                    shape = RoundedCornerShape((12 * (1f - progress())).dp)
                },
                alignment = ArtTop,
                initial = (legend?.title ?: deck.name).take(1),
            ) { Box(Modifier.fillMaxSize().bottomShade(0.3f)) }
        }
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).navigationBarsPadding().padding(bottom = 40.dp)) {
            Hero(deck, legend, with(density) { heroPx.toDp() }, atHero, shown, index, onClose, onTool)
            Tools(shown, record, onTool)
            ChampionBlock(deck, champion, from, shown, index, onTool)
            FieldsBlock(deck, index, from, shown, onTool)
            PileTabs(deck, legend, index, pool, shown, onChange, now)
        }
    }
}

@Composable
private fun Hero(
    deck: Decklist,
    legend: Card?,
    height: Dp,
    atHero: Boolean,
    shown: Boolean,
    index: Map<String, Card>,
    onClose: () -> Unit,
    onTool: (DeckTool, Rect?) -> Unit,
) {
    val screen = LocalWindowInfo.current.containerSize
    Box(Modifier.fillMaxWidth().height(height)) {
        if (atHero) {
            val density = LocalDensity.current
            ArtBox(legend, screen.width, Modifier.fillMaxSize(), alignment = ArtTop, initial = (legend?.title ?: deck.name).take(1), previewWidthPx = with(density) { 120.dp.roundToPx() }) {
                Box(Modifier.fillMaxSize().bottomShade(0.3f))
            }
        }
        Column(Modifier.fillMaxSize().statusBarsPadding().padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 18.dp)) {
            Rise(shown, 220) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    DarkIcon(DeckIcons.Back, "Back to the table", onClose)
                    Spacer(Modifier.weight(1f))
                    DarkIcon(DeckIcons.Edit, "Rename, edit or delete the deck") { onTool(DeckTool.Menu, null) }
                    Spacer(Modifier.width(8.dp))
                    DarkIcon(DeckIcons.Export, "Export as text") { onTool(DeckTool.Export, null) }
                }
            }
            Spacer(Modifier.weight(1f))
            Rise(shown, 320) {
                Column {
                    BasicText(deck.name, style = RiftType.Title.copy(fontSize = 44.sp, lineHeight = 40.sp, color = Color.White), maxLines = 2, overflow = TextOverflow.Ellipsis)
                    Row(Modifier.padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                        BasicText(
                            (legend?.title ?: "No legend").uppercase(),
                            style = RiftType.Caption.copy(fontSize = 11.5.sp, letterSpacing = 0.12.em, color = Color.White.copy(alpha = 0.85f)),
                        )
                        Spacer(Modifier.width(10.dp))
                        // iOS lists what makes a deck illegal; here the chip opens that list.
                        Pressable({ onTool(DeckTool.Issues, null) }, label = "What the deck still needs", pressedScale = 0.95f) {
                            LegalChip(DeckRules.status(deck, index), onDark = true)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DarkIcon(icon: ImageVector, label: String, onClick: () -> Unit) {
    RoundIcon(onClick, label, Modifier.border(1.dp, Color.White.copy(alpha = 0.2f), CircleShape), fill = Color.Black.copy(alpha = 0.45f)) {
        Image(icon, null, colorFilter = ColorFilter.tint(Color.White))
    }
}

@Composable
private fun Tools(shown: Boolean, record: Tally, onTool: (DeckTool, Rect?) -> Unit) {
    Rise(shown, 320) {
        Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 4.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Tool("Draw hand", DeckIcons.Hand) { onTool(DeckTool.Hand, null) }
            Tool("Odds", DeckIcons.Odds) { onTool(DeckTool.Odds, null) }
            Tool("Stats", DeckIcons.Stats) { onTool(DeckTool.Stats, null) }
            Tool(if (record.games > 0) record.text else "History", DeckIcons.Clock, measured = true) { onTool(DeckTool.Log, it) }
        }
    }
}

@Composable
private fun RowScope.Tool(label: String, icon: ImageVector, measured: Boolean = false, onClick: (Rect?) -> Unit) {
    val bounds = remember { arrayOf<Rect?>(null) }
    Pressable(
        { onClick(bounds[0]) },
        Modifier.weight(1f).let { m -> if (measured) m.onGloballyPositioned { bounds[0] = Rect(it.positionInRoot(), it.size.toSize()) } else m },
        pressedScale = 0.95f,
        label = label,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Box(
                Modifier.size(58.dp).background(Color.White.copy(alpha = 0.06f), CircleShape).border(1.dp, Color.White.copy(alpha = 0.14f), CircleShape),
                contentAlignment = Alignment.Center,
            ) { Image(icon, null, colorFilter = ColorFilter.tint(Color.White)) }
            BasicText(label, Modifier.padding(top = 7.dp), style = RiftType.Body.copy(fontSize = 11.5.sp, fontWeight = FontWeight.SemiBold, color = Color.White), maxLines = 1)
        }
    }
}

/** The mock's `.blk`: a soft panel that fades in after the content (600ms, 300ms late). */
@Composable
private fun Block(shown: Boolean, content: @Composable () -> Unit) {
    val t by animateFloatAsState(if (shown) 1f else 0f, tween(600, delayMillis = if (shown) 300 else 0), label = "block")
    val shape = RoundedCornerShape(22.dp)
    Column(
        Modifier.padding(start = 16.dp, end = 16.dp, top = 16.dp).fillMaxWidth()
            .background(Color.White.copy(alpha = 0.04f * t), shape).border(1.dp, Color.White.copy(alpha = 0.08f * t), shape)
            .padding(horizontal = 16.dp, vertical = 14.dp),
    ) { content() }
}

@Composable
private fun BlockLabel(text: String, modifier: Modifier = Modifier) =
    BasicText(text.uppercase(), modifier, style = RiftType.Caption.copy(letterSpacing = 0.14.em, color = Color.White.copy(alpha = 0.62f)))

@Composable
private fun ChampionBlock(deck: Decklist, champion: Card?, from: Rect, shown: Boolean, index: Map<String, Card>, onTool: (DeckTool, Rect?) -> Unit) {
    Block(shown) {
        Rise(shown, 420) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                BlockLabel("Chosen champion")
                champion?.let { BlockLabel("${DeckRules.copies(deck, it, index)} of ${DeckRules.COPY_LIMIT} copies") }
            }
        }
        Row(Modifier.padding(top = 10.dp), verticalAlignment = Alignment.CenterVertically) {
            Mini(champion, Modifier.fly(from, shown, 0, -7f))
            Spacer(Modifier.width(14.dp))
            Rise(shown, 420, Modifier.weight(1f)) {
                Column {
                    BasicText(
                        champion?.name ?: deck.champion?.cardName ?: "No champion yet",
                        style = RiftType.Body.copy(fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color.White), maxLines = 2,
                    )
                    champion?.let { BasicText(unitLine(it), Modifier.padding(top = 2.dp), style = RiftType.Body.copy(fontSize = 12.5.sp, color = Color.White.copy(alpha = 0.62f))) }
                }
            }
            Rise(shown, 420) { SmallButton(if (champion == null) "Pick" else "Swap") { onTool(DeckTool.Champion, null) } }
        }
    }
}

@Composable
private fun FieldsBlock(deck: Decklist, index: Map<String, Card>, from: Rect, shown: Boolean, onTool: (DeckTool, Rect?) -> Unit) {
    Block(shown) {
        Rise(shown, 420) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                BlockLabel("Battlefields")
                SmallButton("Edit · ${deck.battlefields.size} / ${DeckRules.BATTLEFIELDS}", Modifier.height(28.dp)) { onTool(DeckTool.Fields, null) }
            }
        }
        Row(Modifier.padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            for (i in 0 until DeckRules.BATTLEFIELDS) {
                val entry = deck.battlefields.getOrNull(i)
                FieldTile(entry, entry?.let { index[it.cardId] }, Modifier.weight(1f).fly(from, shown, i + 1, if ((i + 1) % 2 == 1) 7f else -7f))
            }
        }
    }
}

@Composable
private fun FieldTile(entry: DecklistEntry?, card: Card?, modifier: Modifier) {
    val shape = RoundedCornerShape(12.dp)
    if (entry == null) {
        Box(
            modifier.height(58.dp).drawBehind {
                drawRoundRect(
                    Color.White.copy(alpha = 0.2f), cornerRadius = CornerRadius(12.dp.toPx()),
                    style = Stroke(1.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 4.dp.toPx()))),
                )
            },
            contentAlignment = Alignment.Center,
        ) { BasicText("Empty", style = RiftType.Body.copy(fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.4f))) }
        return
    }
    val density = LocalDensity.current
    ArtBox(card, with(density) { 240.dp.roundToPx() }, modifier.height(58.dp).clip(shape), alignment = Alignment.Center, initial = "") {
        Box(Modifier.fillMaxSize().bottomShade(0.2f))
        BasicText(
            card?.name ?: entry.cardName,
            Modifier.align(Alignment.BottomStart).padding(8.dp),
            style = RiftType.Body.copy(fontSize = 11.sp, lineHeight = 12.6.sp, fontWeight = FontWeight.SemiBold, color = Color.White),
            maxLines = 2, overflow = TextOverflow.Ellipsis,
        )
        Box(Modifier.fillMaxSize().border(1.dp, Color.White.copy(alpha = 0.12f), shape))
    }
}

/**
 * The mock's fly-out: from the pile (scaled to its size, turned ±7°, invisible) into place, 780ms, 70ms apart;
 * back into the pile with an ease-in when the deck closes.
 */
@Composable
private fun Modifier.fly(pile: Rect, shown: Boolean, i: Int, rotation: Float): Modifier {
    val t = remember { Animatable(0f) }
    LaunchedEffect(shown) {
        if (shown) {
            delay(90L + i * 70L)
            t.animateTo(1f, tween(780, easing = RiftEase))
        } else {
            delay((3 - i) * 40L)
            t.animateTo(0f, tween(520, easing = FlyBack))
        }
    }
    val bounds = remember { arrayOf(Rect.Zero) }
    return onGloballyPositioned { bounds[0] = Rect(it.positionInRoot(), it.size.toSize()) }.graphicsLayer {
        val v = t.value
        val b = bounds[0]
        if (b.width > 0f) {
            val s = (pile.width / b.width).coerceIn(0.3f, 2.4f)
            translationX = (pile.center.x - b.center.x) * (1f - v)
            translationY = (pile.center.y - b.center.y) * (1f - v)
            scaleX = lerp(s, 1f, v)
            scaleY = scaleX
            rotationZ = rotation * (1f - v)
        }
        alpha = (v * 3f).coerceIn(0f, 1f)
    }
}

@Composable
private fun PileTabs(deck: Decklist, legend: Card?, index: Map<String, Card>, pool: List<Card>, shown: Boolean, onChange: (Decklist) -> Unit, now: () -> Long) {
    var tab by remember { mutableIntStateOf(0) }
    var tabKey by remember { mutableIntStateOf(0) }
    val runes = deck.runes.sumOf { it.count }
    Rise(shown, 520) {
        Segmented(
            listOf("Main ${deck.mainDeck.sumOf { it.count }}", "Side ${deck.sideDeck.sumOf { it.count }}", "Runes $runes"), tab,
            Modifier.padding(start = 16.dp, end = 16.dp, top = 18.dp, bottom = 6.dp),
        ) {
            if (it != tab) {
                tab = it
                tabKey++
            }
        }
    }
    val domains = legend?.domains.orEmpty().filterNot { it.equals("colorless", true) }
    Column(Modifier.padding(horizontal = 16.dp).rowsIn(tabKey)) {
        when (tab) {
            0, 1 -> {
                val pile = if (tab == 0) Pile.Main else Pile.Side
                val rows = DeckEdits.entries(deck, pile).sortedWith(compareBy({ index[it.cardId]?.attributes?.energy ?: 99 }, { it.cardName.lowercase() }))
                if (rows.isEmpty()) {
                    BasicText(
                        if (tab == 0) "No cards yet. Add them in the builder (pencil above) or from the Cards tab." else "No sideboard. It holds 0 or 10 cards.",
                        Modifier.padding(vertical = 18.dp),
                        style = RiftType.Body.copy(fontSize = 13.5.sp, lineHeight = 19.sp, color = Color.White.copy(alpha = 0.66f)),
                    )
                }
                rows.forEachIndexed { i, e ->
                    val card = index[e.cardId]
                    CardRow(
                        e, card, deck.champion?.cardId == e.cardId, Modifier.rowIn(shown, i, tabKey),
                        canAdd = card != null && DeckEdits.canAdd(deck, pile, card, index),
                        onMinus = { onChange(DeckEdits.step(deck, pile, e, -1, now())) },
                        onPlus = { onChange(DeckEdits.step(deck, pile, e, +1, now())) },
                    )
                }
            }
            else -> RunePool(domains, { DeckEdits.runeCount(deck, it, index) }, runes) { d, delta ->
                onChange(DeckEdits.rune(deck, d, delta, pool, index, now()))
            }
        }
    }
}

/** Rows slide in from the left after the deck opened, 35ms apart. */
@Composable
private fun Modifier.rowIn(shown: Boolean, i: Int, tabKey: Int): Modifier {
    val t = remember { Animatable(if (tabKey > 0) 1f else 0f) }
    LaunchedEffect(shown) {
        if (shown) t.animateTo(1f, tween(700, delayMillis = if (tabKey == 0) 560 + minOf(i, 12) * 35 else 0, easing = RiftEase)) else t.animateTo(0f, tween(160))
    }
    return graphicsLayer {
        alpha = t.value
        translationX = -14.dp.toPx() * (1f - t.value)
    }
}

/** A tab change replays the list's rise (the mock's rowsA/rowsB). */
@Composable
private fun Modifier.rowsIn(key: Int): Modifier {
    val t = remember(key) { Animatable(if (key == 0) 1f else 0f) }
    LaunchedEffect(key) { t.animateTo(1f, tween(600, easing = RiftEase)) }
    return graphicsLayer {
        val v = t.value
        alpha = v
        translationY = 10.dp.toPx() * (1f - v)
        val b = 6.dp.toPx() * (1f - v)
        renderEffect = if (b > 0.5f) BlurEffect(b, b) else null
    }
}
