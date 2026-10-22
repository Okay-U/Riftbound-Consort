package pitopia.riftcount.decks

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import kotlin.math.roundToInt
import pitopia.riftcount.cards.Card
import pitopia.riftcount.cards.CardStyle
import pitopia.riftcount.data.DeckRules
import pitopia.riftcount.data.DecklistEntry
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.Stepper
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

/** "Fury · 5 energy · 5 might". */
fun unitLine(c: Card) = listOfNotNull(
    c.domains.joinToString(" · ").ifEmpty { null },
    c.attributes?.energy?.let { "$it energy" },
    c.attributes?.might?.let { "$it might" },
).joinToString(" · ")

@Composable
fun SmallButton(text: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(17.dp)
    Pressable(onClick, modifier.height(34.dp).border(1.dp, Color.White.copy(alpha = 0.18f), shape).padding(horizontal = 14.dp), pressedScale = 0.95f) {
        BasicText(text, style = RiftType.Body.copy(fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold, color = Color.White), maxLines = 1)
    }
}

/** A small card (54 × 76) with its cost, as the champion row and the builder show it. */
@Composable
fun Mini(card: Card?, modifier: Modifier = Modifier) {
    val density = LocalDensity.current
    val shape = RoundedCornerShape(8.dp)
    ArtBox(card, with(density) { 108.dp.roundToPx() }, modifier.size(54.dp, 76.dp).clip(shape), alignment = Alignment.Center, initialSize = 40.sp) {
        card?.attributes?.energy?.let {
            BasicText(
                "$it",
                Modifier.padding(5.dp).size(20.dp).background(Color.Black.copy(alpha = 0.7f), CircleShape),
                style = RiftType.Title.copy(fontSize = 13.sp, lineHeight = 20.sp, color = Color.White, textAlign = TextAlign.Center),
            )
        }
        Box(Modifier.fillMaxSize().border(1.dp, Color.White.copy(alpha = 0.16f), shape))
    }
}

/** The mock's `.crow`: energy in the card's colour, name, type line with SIG/CHAMP tags, stepper. */
@Composable
fun CardRow(entry: DecklistEntry, card: Card?, chosen: Boolean, modifier: Modifier = Modifier, canAdd: Boolean, onMinus: () -> Unit, onPlus: () -> Unit, count: Int = entry.count) {
    Row(
        modifier.fillMaxWidth().height(56.dp).drawBehind { drawRect(Color.White.copy(alpha = 0.06f), Offset(0f, size.height - 1.dp.toPx()), Size(size.width, 1.dp.toPx())) },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        BasicText(
            card?.attributes?.energy?.toString() ?: "–",
            Modifier.width(28.dp),
            style = RiftType.Title.copy(fontSize = 24.sp, lineHeight = 24.sp, color = CardStyle.domainColor(card?.domains?.firstOrNull()), textAlign = TextAlign.Center),
        )
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            BasicText(card?.name ?: entry.cardName, style = RiftType.Body.copy(fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Color.White), maxLines = 1, overflow = TextOverflow.Ellipsis)
            Row(Modifier.padding(top = 2.dp), verticalAlignment = Alignment.CenterVertically) {
                BasicText(
                    card?.let(::typeLine) ?: "Not in the card list",
                    style = RiftType.Body.copy(fontSize = 11.5.sp, color = Color.White.copy(alpha = 0.58f)), maxLines = 1,
                )
                if (card?.isSignature == true) Tag("SIG", Color(0xFFC08BFF))
                if (chosen) Tag("CHAMP", RiftColors.You)
            }
        }
        Stepper(count, onMinus, onPlus, card?.title ?: entry.cardName, plus = canAdd, button = 32.dp)
    }
}

/** "Unit · 1 power · 3 might" (might only for units, like the mock). */
fun typeLine(c: Card) = listOfNotNull(
    if (c.isChampion) "Champion" else CardStyle.kind(c),
    c.attributes?.power?.takeIf { it > 0 }?.let { "$it power" },
    c.attributes?.might?.takeIf { c.type.equals("unit", true) }?.let { "$it might" },
).joinToString(" · ")

@Composable
private fun Tag(text: String, color: Color) {
    BasicText(
        text,
        Modifier.padding(start = 6.dp).background(color.copy(alpha = 0.17f), RoundedCornerShape(5.dp)).padding(horizontal = 6.dp, vertical = 1.dp),
        style = RiftType.Caption.copy(fontSize = 9.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.1.em, color = color),
    )
}

/** The mock's segmented control with the sliding white knob (Main/Side/Runes, Set/Energy/Type…). */
@Composable
fun Segmented(labels: List<String>, selected: Int, modifier: Modifier = Modifier, height: Dp = 44.dp, onPick: (Int) -> Unit) {
    val x by animateFloatAsState(selected.toFloat(), tween(520, easing = RiftEase), label = "seg")
    val shape = RoundedCornerShape(height / 2)
    BoxWithConstraints(
        modifier.fillMaxWidth().height(height).background(Color.White.copy(alpha = 0.06f), shape).border(1.dp, Color.White.copy(alpha = 0.1f), shape).padding(3.dp),
    ) {
        val w = maxWidth / labels.size
        Box(Modifier.offset { IntOffset((x * w.toPx()).roundToInt(), 0) }.size(w, maxHeight).background(Color.White, RoundedCornerShape((height - 6.dp) / 2)))
        Row(Modifier.fillMaxSize()) {
            labels.forEachIndexed { i, label ->
                val on = i == selected
                val ink by animateColorAsState(if (on) Color.Black else Color.White.copy(alpha = 0.8f), tween(300), label = "ink")
                Box(
                    Modifier.weight(1f).fillMaxSize().clickable(remember { MutableInteractionSource() }, null, role = Role.Tab) { onPick(i) }
                        .semantics { contentDescription = label },
                    contentAlignment = Alignment.Center,
                ) {
                    BasicText(label, style = RiftType.Body.copy(fontSize = 13.5.sp, fontWeight = FontWeight.SemiBold, fontFeatureSettings = "tnum", color = ink), maxLines = 1)
                }
            }
        }
    }
}

/** Rune rows for the legend's domains, the 12 pips and the total (detail and builder). */
@Composable
fun RunePool(domains: List<String>, count: (String) -> Int, total: Int, onStep: (String, Int) -> Unit) {
    if (domains.isEmpty()) {
        BasicText("Pick a legend first: its domains decide the runes.", Modifier.padding(vertical = 18.dp), style = RiftType.Body.copy(fontSize = 13.5.sp, color = Color.White.copy(alpha = 0.66f)))
        return
    }
    domains.forEach { d ->
        val n = count(d)
        val color = CardStyle.domainColor(d)
        Row(
            Modifier.fillMaxWidth().height(64.dp).drawBehind { drawRect(Color.White.copy(alpha = 0.06f), Offset(0f, size.height - 1.dp.toPx()), Size(size.width, 1.dp.toPx())) },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                Modifier.size(40.dp).dropShadow(CircleShape, Shadow(radius = 16.dp, color = color.copy(alpha = 0.53f))).background(color, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Image(painterResource(CardStyle.glyph(d)), null, Modifier.size(20.dp), colorFilter = ColorFilter.tint(Color.Black))
            }
            BasicText("$d Rune", Modifier.weight(1f).padding(start = 12.dp), style = RiftType.Body.copy(fontSize = 15.5.sp, fontWeight = FontWeight.SemiBold, color = Color.White))
            Stepper(n, { onStep(d, -1) }, { onStep(d, +1) }, "$d rune", plus = total < DeckRules.RUNES, button = 32.dp)
        }
    }
    val pips = domains.flatMap { d -> List(count(d)) { d } }
    Row(Modifier.fillMaxWidth().padding(top = 16.dp, bottom = 6.dp), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        repeat(DeckRules.RUNES) { i ->
            val d = pips.getOrNull(i)
            val c = d?.let(CardStyle::domainColor)
            val bg by animateColorAsState(c ?: Color.White.copy(alpha = 0.1f), tween(400), label = "pip")
            Box(
                Modifier.weight(1f).height(10.dp).let { m -> if (c != null) m.dropShadow(RoundedCornerShape(5.dp), Shadow(radius = 10.dp, color = c.copy(alpha = 0.6f))) else m }
                    .background(bg, RoundedCornerShape(5.dp)),
            )
        }
    }
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        val style = RiftType.Body.copy(fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.66f))
        BasicText("Rune pool", style = style)
        BasicText("$total / ${DeckRules.RUNES}", style = style)
    }
}
