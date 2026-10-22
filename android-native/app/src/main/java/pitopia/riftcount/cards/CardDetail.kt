package pitopia.riftcount.cards

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
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.navigationBarsPadding
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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.BlurEffect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.compose.ui.util.lerp
import kotlin.math.min
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.RoundIcon
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

private val RulesStyle get() = RiftType.Body.copy(fontSize = 15.5.sp, lineHeight = 23.sp, color = Color.White)

/**
 * The card opened from the grid: the tile flies to the top and grows (680ms), the frame fades off the art,
 * then the text rises in, step by step. [progress] is the flight, [shown] false plays everything back.
 */
@Composable
fun CardDetail(
    card: Card,
    from: Rect,
    progress: () -> Float,
    shown: Boolean,
    tilePx: Int,
    erratum: Erratum?,
    inDecks: Int,
    onClose: () -> Unit,
    onAdd: () -> Unit,
) {
    val density = LocalDensity.current
    val screen = LocalWindowInfo.current.containerSize
    val top = WindowInsets.statusBars.getTop(density)
    val bottom = WindowInsets.navigationBars.getBottom(density)
    val heroW = min(with(density) { 236.dp.toPx() }, screen.width * 0.573f)
    val heroX = (screen.width - heroW) / 2
    val heroY = top + with(density) { 58.dp.toPx() }
    val bodyTop = with(density) { (heroY + heroW / CARD_ASPECT).toDp() + 10.dp }
    val domain = card.domains.firstOrNull { !it.equals("colorless", true) }
    val color = CardStyle.domainColor(domain)
    val backdrop = rememberShown(shown, inMs = 420, outMs = 420)
    val glow = rememberShown(shown, inMs = 900, outMs = 420)

    Box(Modifier.fillMaxSize()) {
        Box(
            Modifier.fillMaxSize().graphicsLayer { alpha = backdrop.value }.background(Color.Black.copy(alpha = 0.94f))
                .clickable(remember { MutableInteractionSource() }, indication = null) {},
        )
        Box(
            Modifier.fillMaxSize().graphicsLayer { alpha = glow.value }.drawBehind {
                // radial-gradient(closest-side) over 160% × 62% of the screen, from 14% above it.
                val c = Offset(size.width / 2, size.height * 0.17f)
                val ry = size.height * 0.31f
                scale(size.width * 0.8f / ry, 1f, pivot = c) {
                    drawCircle(Brush.radialGradient(listOf(color.copy(alpha = 0.25f), Color.Transparent), c, ry), ry, c)
                }
            },
        )
        Reveal(shown, 0, Modifier.statusBarsPadding().padding(start = 16.dp, end = 16.dp, top = 8.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                RoundIcon(onClose, "Back to cards", Modifier.border(1.dp, Color.White.copy(alpha = 0.14f), CircleShape), fill = Color.White.copy(alpha = 0.06f)) {
                    Image(CardIcons.Back, null, colorFilter = ColorFilter.tint(Color.White))
                }
                BasicText(setLine(card).uppercase(), style = RiftType.Caption.copy(fontSize = 11.sp, letterSpacing = 0.14.em, color = Color.White.copy(alpha = 0.72f)))
            }
        }
        Hero(card, from, progress, heroX, heroY, heroW, tilePx, erratum != null)
        Column(
            Modifier.fillMaxSize().padding(top = bodyTop, bottom = with(density) { bottom.toDp() } + 88.dp)
                .fadeEdges(12.dp, 22.dp).verticalScroll(rememberScrollState())
                .padding(start = 22.dp, end = 22.dp, top = 4.dp, bottom = 24.dp),
        ) {
            Reveal(shown, 1) { NameBlock(card) }
            val stats = statsOf(card)
            if (stats.isNotEmpty()) Reveal(shown, 2, Modifier.padding(top = 16.dp)) { StatsRow(stats) }
            erratum?.let { Reveal(shown, 2, Modifier.padding(top = 16.dp)) { ErrataBox(it, domain) } }
            val rules = remember(card) { CardText.parse(card.text?.rich?.takeIf { it.isNotBlank() } ?: card.text?.plain.orEmpty(), domain) }
            if (rules.isNotEmpty()) Reveal(shown, 3, Modifier.padding(top = 16.dp)) { RulesText(rules, RulesStyle) }
            card.text?.flavour?.takeIf { it.isNotBlank() }?.let { Reveal(shown, 3, Modifier.padding(top = 16.dp)) { Flavour(it, color) } }
            Reveal(shown, 4, Modifier.padding(top = 18.dp)) { Meta(card) }
        }
        Reveal(shown, 2, Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(start = 16.dp, end = 16.dp, bottom = 18.dp)) {
            DetailBar(inDecks, onAdd)
        }
    }
}

/** The tile itself, scaled from its place in the grid; the bigger image replaces the tile's once loaded. */
@Composable
private fun Hero(card: Card, from: Rect, progress: () -> Float, toX: Float, toY: Float, toW: Float, tilePx: Int, errata: Boolean) {
    val density = LocalDensity.current
    val small by rememberCardArt(card, tilePx)
    val big by rememberCardArt(card, toW.toInt())
    CardFace(
        card, errata, big ?: small,
        Modifier.size(with(density) { from.width.toDp() }, with(density) { from.height.toDp() })
            .graphicsLayer {
                val p = progress()
                transformOrigin = TransformOrigin(0f, 0f)
                translationX = lerp(from.left, toX, p)
                translationY = lerp(from.top, toY, p)
                scaleX = lerp(1f, toW / from.width, p)
                scaleY = scaleX
            }
            .semantics { contentDescription = card.media?.accessibilityText ?: card.name },
        labels = { 1f - progress() },
    )
}

@Composable
private fun NameBlock(card: Card) {
    val text = buildAnnotatedString {
        withStyle(SpanStyle(fontFamily = RiftType.Display, fontWeight = FontWeight.Black, fontSize = 34.sp, letterSpacing = 0.02.em)) { append(card.title) }
        card.subtitle?.let {
            append("  ")
            withStyle(SpanStyle(fontFamily = RiftType.Text, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, color = Color.White.copy(alpha = 0.78f))) { append(it) }
        }
    }
    Column {
        BasicText(text, style = RiftType.Body.copy(lineHeight = 36.sp, color = Color.White))
        Row(Modifier.padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            card.domains.forEach { d ->
                Image(painterResource(CardStyle.glyph(d)), null, Modifier.padding(end = 8.dp).size(16.dp), colorFilter = ColorFilter.tint(CardStyle.domainColor(d)))
            }
            val type = if (card.isChampion) "Champion unit" else CardStyle.kind(card)
            val caps = RiftType.Caption.copy(fontSize = 12.sp, letterSpacing = 0.1.em, color = Color.White.copy(alpha = 0.76f))
            BasicText((listOf(type) + card.domains).joinToString(" · ").uppercase(), style = caps)
            if (card.rarity.isNotEmpty()) {
                Gem(CardStyle.rarityColor(card.rarity), 6.dp, Modifier.padding(start = 10.dp, end = 8.dp))
                BasicText(card.rarity.uppercase(), style = caps)
            }
            if (card.isPreview) {
                BasicText(
                    "PREVIEW",
                    Modifier.padding(start = 10.dp).background(Color.White.copy(alpha = 0.16f), RoundedCornerShape(4.dp)).padding(horizontal = 6.dp, vertical = 2.dp),
                    style = caps.copy(fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Color.White),
                )
            }
        }
    }
}

/** Energy, power and might; none for legends, battlefields and runes. Gear gives its might as a bonus. */
private fun statsOf(card: Card): List<Pair<String, String>> {
    val a = card.attributes ?: return emptyList()
    return listOfNotNull(
        a.energy?.let { "$it" to "Energy" },
        a.power?.let { "$it" to "Power" },
        a.might?.let { (if (card.type.equals("gear", true)) "+$it" else "$it") to "Might" },
    )
}

@Composable
private fun StatsRow(stats: List<Pair<String, String>>) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        stats.forEach { (v, k) -> StatTile(v, k) }
        repeat(3 - stats.size) { Spacer(Modifier.weight(1f)) }
    }
}

@Composable
private fun RowScope.StatTile(value: String, key: String) {
    val shape = RoundedCornerShape(18.dp)
    Column(
        Modifier.weight(1f).height(64.dp).background(Color.White.copy(alpha = 0.06f), shape).border(1.dp, Color.White.copy(alpha = 0.1f), shape),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        BasicText(value, style = RiftType.Title.copy(fontSize = 30.sp, lineHeight = 30.sp, color = Color.White))
        BasicText(key.uppercase(), style = RiftType.Caption.copy(fontSize = 10.sp, letterSpacing = 0.14.em, color = Color.White.copy(alpha = 0.66f)))
    }
}

/** Riot's corrected wording above the printed one: at a table the correction is what applies. */
@Composable
private fun ErrataBox(e: Erratum, domain: String?) {
    val shape = RoundedCornerShape(18.dp)
    val uri = LocalUriHandler.current
    Column(
        Modifier.fillMaxWidth().background(RiftColors.Gold.copy(alpha = 0.08f), shape).border(1.dp, RiftColors.Gold.copy(alpha = 0.32f), shape)
            .padding(horizontal = 16.dp, vertical = 14.dp),
    ) {
        BasicText(
            listOfNotNull("Errata · official text", e.set).joinToString(" · ").uppercase(),
            style = RiftType.Caption.copy(fontWeight = FontWeight.Bold, letterSpacing = 0.14.em, color = RiftColors.Gold),
        )
        RulesText(remember(e) { CardText.parse(e.newText, domain) }, RulesStyle.copy(fontSize = 15.sp, lineHeight = 22.sp), Modifier.padding(top = 8.dp, bottom = 6.dp), gap = 6.dp)
        e.oldText?.takeIf { it.isNotBlank() }?.let { old ->
            RulesText(
                remember(e) { CardText.parse("Printed: $old", domain) },
                RiftType.Body.copy(fontSize = 13.sp, lineHeight = 18.sp, fontWeight = FontWeight.Normal, color = Color.White.copy(alpha = 0.6f), textDecoration = TextDecoration.LineThrough),
                gap = 4.dp,
            )
        }
        e.note?.takeIf { it.isNotBlank() }?.let {
            BasicText(it, Modifier.padding(top = 8.dp), style = RiftType.Body.copy(fontSize = 13.sp, lineHeight = 18.sp, color = Color.White.copy(alpha = 0.7f)))
        }
        // Only Riot's own pages: the link comes from the feed.
        e.source.takeIf { it.startsWith("https://") }?.let { url ->
            LinkButton("Official errata", { uri.openUri(url) }, Modifier.padding(top = 4.dp), color = RiftColors.Gold)
        }
    }
}

@Composable
private fun Flavour(text: String, color: Color) {
    BasicText(
        text,
        Modifier.fillMaxWidth().drawBehind { drawRect(color, size = Size(2.dp.toPx(), size.height)) }.padding(start = 14.dp, top = 2.dp, bottom = 2.dp),
        style = RiftType.Body.copy(fontSize = 14.5.sp, lineHeight = 21.75.sp, fontStyle = FontStyle.Italic, fontWeight = FontWeight.Normal, color = Color.White.copy(alpha = 0.74f)),
    )
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Meta(card: Card) {
    val style = RiftType.Body.copy(fontSize = 12.5.sp, color = Color.White.copy(alpha = 0.62f))
    Column {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            BasicText("Art by ${card.media?.artist ?: "Riot Games"}", Modifier.weight(1f, fill = false), style = style)
            card.publicCode?.let { BasicText(it, Modifier.padding(start = 10.dp), style = style) }
        }
        val tags = card.tags.orEmpty()
        if (tags.isNotEmpty()) {
            FlowRow(Modifier.padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                tags.forEach { tag ->
                    BasicText(
                        tag,
                        Modifier.height(26.dp).border(1.dp, Color.White.copy(alpha = 0.14f), RoundedCornerShape(13.dp)).padding(horizontal = 10.dp, vertical = 5.dp),
                        style = RiftType.Body.copy(fontSize = 11.sp, lineHeight = 14.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.06.em, color = Color.White.copy(alpha = 0.8f)),
                    )
                }
            }
        }
    }
}

@Composable
private fun DetailBar(inDecks: Int, onAdd: () -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
        val pill = RoundedCornerShape(28.dp)
        Column(
            Modifier.height(56.dp).background(Color.White.copy(alpha = 0.06f), pill).border(1.dp, Color.White.copy(alpha = 0.12f), pill)
                .padding(horizontal = 16.dp).semantics(mergeDescendants = true) {},
            verticalArrangement = Arrangement.Center,
        ) {
            BasicText("$inDecks", style = RiftType.Title.copy(fontSize = 20.sp, lineHeight = 20.sp, color = Color.White))
            BasicText(
                (if (inDecks == 1) "deck" else "decks").uppercase(),
                style = RiftType.Caption.copy(letterSpacing = 0.1.em, color = Color.White.copy(alpha = 0.7f)),
            )
        }
        Pressable(
            onAdd,
            Modifier.weight(1f).height(56.dp).dropShadow(pill, Shadow(radius = 26.dp, color = RiftColors.You.copy(alpha = 0.45f)))
                .background(RiftColors.You, pill),
            pressedScale = 0.96f,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Image(CardIcons.Plus, null, colorFilter = ColorFilter.tint(Color.Black))
                Spacer(Modifier.width(8.dp))
                BasicText("Add to deck", style = RiftType.Body.copy(fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color.Black))
            }
        }
    }
}

private fun setLine(card: Card) =
    listOfNotNull(card.set?.label, card.publicCode?.substringBefore('/')).joinToString(" · ")

/** 0 → 1 over [inMs] when [shown] turns true, back over [outMs]; starts hidden so the first frame animates. */
@Composable
private fun rememberShown(shown: Boolean, inMs: Int, outMs: Int, delayMs: Int = 0): Animatable<Float, *> {
    val t = remember { Animatable(0f) }
    LaunchedEffect(shown) { t.animateTo(if (shown) 1f else 0f, if (shown) tween(inMs, delayMs, RiftEase) else tween(outMs)) }
    return t
}

/** The mock's `.fade` steps: up 14dp out of an 8dp blur, 120ms apart; all leave at once in 220ms. */
@Composable
private fun Reveal(shown: Boolean, step: Int, modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    val t = rememberShown(shown, inMs = 700, outMs = 220, delayMs = if (step == 0) 0 else 20 + step * 100)
    Box(
        modifier.graphicsLayer {
            val v = t.value
            alpha = v
            translationY = 14.dp.toPx() * (1f - v)
            val blur = 8.dp.toPx() * (1f - v)
            renderEffect = if (blur > 0.5f) BlurEffect(blur, blur) else null
        },
    ) { content() }
}

/** Text scrolls out under soft edges (mask 12dp at the top, 22dp at the bottom). */
private fun Modifier.fadeEdges(top: Dp, bottom: Dp) = graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
    .drawWithContent {
        drawContent()
        val h = size.height
        drawRect(
            Brush.verticalGradient(0f to Color.Transparent, top.toPx() / h to Color.Black, 1f - bottom.toPx() / h to Color.Black, 1f to Color.Transparent),
            blendMode = BlendMode.DstIn,
        )
    }
