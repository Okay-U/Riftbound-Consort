package pitopia.riftcount.cards

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.drag
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import kotlin.math.abs
import kotlin.math.roundToInt
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.Sheet
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftType

private val LabelStyle get() = RiftType.Caption.copy(letterSpacing = 0.14.em, color = Color.White.copy(alpha = 0.66f))

/** Type, series and rarity chips, energy/power/might ranges; the grid behind follows live. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun FilterSheet(filters: CardFilters, onChange: (CardFilters) -> Unit, store: CardStore, count: Int, onDismiss: () -> Unit) {
    val types = remember(store.revision) { CardQuery.options(CardFilters.knownTypes, store.cards.map { it.type }, CardFilters.tokenParent.keys) }
    val rarities = remember(store.revision) { CardQuery.options(CardFilters.knownRarities, store.cards.map { it.rarity }) }
    Sheet("Filter cards", onDismiss) { close ->
        Row(Modifier.fillMaxWidth().padding(bottom = 4.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            BasicText("Filter cards", style = RiftType.Body.copy(fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color.White))
            LinkButton("Reset", {
                onChange(CardFilters(domains = filters.domains))
            })
        }
        ChipSection("Type", types, filters.types, gems = false) { onChange(filters.copy(types = filters.types.toggle(it))) }
        ChipSection("Series", CardFilters.knownSeries, filters.series, gems = false) { onChange(filters.copy(series = filters.series.toggle(it))) }
        ChipSection("Rarity", rarities, filters.rarities, gems = true) { onChange(filters.copy(rarities = filters.rarities.toggle(it))) }
        RangeRow("Energy", filters.energy, CardFilters.ENERGY_CAP) { onChange(filters.copy(energy = it)) }
        RangeRow("Power", filters.power, CardFilters.POWER_CAP) { onChange(filters.copy(power = it)) }
        RangeRow("Might", filters.might, CardFilters.MIGHT_CAP) { onChange(filters.copy(might = it)) }
        val shape = RoundedCornerShape(27.dp)
        Pressable(
            close,
            Modifier.padding(top = 20.dp).fillMaxWidth().height(54.dp)
                .dropShadow(shape, Shadow(radius = 22.dp, color = RiftColors.You.copy(alpha = 0.35f)))
                .background(RiftColors.You, shape),
            pressedScale = 0.97f,
        ) {
            BasicText(
                when (count) {
                    0 -> "No cards match"
                    1 -> "Show 1 card"
                    else -> "Show $count cards"
                },
                style = RiftType.Body.copy(fontSize = 15.sp, fontWeight = FontWeight.Bold, color = Color.Black),
            )
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ChipSection(label: String, options: List<String>, on: Set<String>, gems: Boolean, onToggle: (String) -> Unit) {
    Column(Modifier.padding(top = 14.dp)) {
        BasicText(label.uppercase(), Modifier.padding(bottom = 8.dp), style = LabelStyle)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            options.forEach { o -> Chip(o, o in on, if (gems) CardStyle.rarityColor(o) else null) { onToggle(o) } }
        }
    }
}

@Composable
private fun Chip(label: String, on: Boolean, gem: Color?, onClick: () -> Unit) {
    val t by animateFloatAsState(if (on) 1f else 0f, tween(260), label = "chip")
    val shape = RoundedCornerShape(18.dp)
    Pressable(
        onClick,
        Modifier.height(36.dp)
            .dropShadow(shape, Shadow(radius = 16.dp, color = RiftColors.You.copy(alpha = 0.45f * t)))
            .background(lerp(Color.White.copy(alpha = 0.05f), RiftColors.You, t), shape)
            .border(1.dp, lerp(Color.White.copy(alpha = 0.16f), RiftColors.You, t), shape)
            .padding(horizontal = 14.dp)
            .semantics { selected = on },
        pressedScale = 0.95f,
        role = Role.Checkbox,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (gem != null) {
                Gem(gem, 6.dp)
                Spacer(Modifier.width(7.dp))
            }
            BasicText(label, style = RiftType.Body.copy(fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = lerp(Color.White, Color.Black, t)))
        }
    }
}

/** Two-thumb slider on whole numbers; the thumb nearer the finger moves, a tap jumps it there. */
@Composable
private fun RangeRow(label: String, range: IntRange, cap: Int, onChange: (IntRange) -> Unit) {
    val full = range.first == 0 && range.last == cap
    val text = when {
        full -> "Any"
        range.first == range.last -> "${range.first}"
        else -> "${range.first} – ${range.last}"
    }
    val current by rememberUpdatedState(range)
    val change by rememberUpdatedState(onChange)
    Column(Modifier.padding(top = 14.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            BasicText(label.uppercase(), style = LabelStyle)
            BasicText(text, style = RiftType.Title.copy(fontSize = 16.sp, lineHeight = 18.sp, fontWeight = FontWeight.ExtraBold, letterSpacing = 0.06.em, fontFeatureSettings = "tnum", color = Color.White))
        }
        Box(
            Modifier.padding(horizontal = 14.dp).fillMaxWidth().height(34.dp)
                .semantics { contentDescription = "$label $text" }
                .pointerInput(cap) {
                    awaitEachGesture {
                        val down = awaitFirstDown()
                        val unit = size.width / cap.toFloat()
                        val start = current
                        val v = down.position.x / unit
                        // Thumbs on one value: the first move decides which one the finger takes.
                        var end: Int? = when {
                            start.first == start.last && abs(v - start.first) < 0.6f -> null
                            abs(v - start.first) <= abs(v - start.last) -> 0
                            else -> 1
                        }
                        fun move(x: Float) {
                            val which = end ?: return
                            val raw = (x / unit).roundToInt()
                            val r = current
                            val next = if (which == 0) raw.coerceIn(0, r.last)..r.last else r.first..raw.coerceIn(r.first, cap)
                            if (next != r) change(next)
                        }
                        move(down.position.x)
                        down.consume()
                        drag(down.id) { c ->
                            if (end == null) end = if (c.position.x < down.position.x) 0 else 1
                            move(c.position.x)
                            c.consume()
                        }
                    }
                }
                .drawBehind {
                    val unit = size.width / cap
                    val cy = 17.dp.toPx()
                    val x0 = range.first * unit
                    val x1 = range.last * unit
                    val line = 4.dp.toPx()
                    drawRoundRect(Color.White.copy(alpha = 0.14f), Offset(0f, cy - line / 2), Size(size.width, line), CornerRadius(line / 2))
                    drawRoundRect(RiftColors.You.copy(alpha = 0.22f), Offset(x0, cy - line * 1.25f), Size(x1 - x0, line * 2.5f), CornerRadius(line * 1.25f))
                    drawRoundRect(RiftColors.You, Offset(x0, cy - line / 2), Size(x1 - x0, line), CornerRadius(line / 2))
                    for (i in 0..cap) {
                        val lit = !full && i in range
                        val c = Offset(i * unit, cy)
                        if (lit) drawCircle(RiftColors.You.copy(alpha = 0.35f), 5.dp.toPx(), c)
                        drawCircle(if (lit) RiftColors.You else Color.White.copy(alpha = 0.28f), 3.dp.toPx(), c)
                    }
                    listOf(x0, x1).forEach { x ->
                        drawCircle(Color.Black.copy(alpha = 0.35f), 15.dp.toPx(), Offset(x, cy + 2.dp.toPx()))
                        drawCircle(RiftColors.You.copy(alpha = 0.25f), 18.dp.toPx(), Offset(x, cy))
                        drawCircle(Color.White, 14.dp.toPx(), Offset(x, cy))
                    }
                },
        )
    }
}
