package pitopia.riftcount.settings

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import pitopia.riftcount.data.Prefs
import pitopia.riftcount.score.OPPONENT
import pitopia.riftcount.score.PlayerColors
import pitopia.riftcount.score.SeatShade
import pitopia.riftcount.score.Swatch
import pitopia.riftcount.score.YOU
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.Rise
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftType

/** The seats of the scoreboard with what Settings calls them. */
private fun seats(players: Int): List<Pair<Int, String>> =
    if (players == 2) listOf(YOU to "You", OPPONENT to "Opponent") else List(4) { it to "Player ${it + 1}" }

/** "Rift Green vs Rift Violet" under the Player colors row. */
fun colorsSummary(players: Int): String =
    if (players == 2) "${PlayerColors.forSlot(YOU, 2).name} vs ${PlayerColors.forSlot(OPPONENT, 2).name}" else "One color per seat"

/** The colour dots on the Player colors row. */
@Composable
fun ColorDots(players: Int) {
    val slots = if (players == 2) listOf(YOU, OPPONENT) else listOf(0, 1, 2, 3)
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        slots.forEach { slot ->
            val c = PlayerColors.forSlot(slot, players).color
            Box(Modifier.size(22.dp).background(c, CircleShape).border(2.dp, Color.Black.copy(alpha = 0.4f), CircleShape))
        }
    }
}

/**
 * Player colors: a live preview of the table, then a palette per seat. Taking a colour another seat has
 * swaps the two (iOS `ColorSettingsSheet`); picks are saved as `colorIdx_<slot>`.
 */
@Composable
fun ColorsPage(players: Int, onToast: (String) -> Unit, onChange: () -> Unit) {
    var picks by remember(players) { mutableStateOf(List(players) { PlayerColors.forSlot(it, players) }) }
    fun pick(slot: Int, sw: Swatch) {
        if (picks[slot].index == sw.index) return
        val other = picks.indexOfFirst { it.index == sw.index }
        picks = pickColor(picks, slot, sw)
        Prefs.put("colorIdx_$slot", sw.index)
        onChange()
        if (other >= 0) {
            Prefs.put("colorIdx_$other", picks[other].index)
            onToast("Swapped colors")
        }
    }
    val colors = picks.map { animateColorAsState(it.color, tween(500), label = "seat").value }
    Column {
        Rise(true, 0, Modifier.padding(top = 6.dp)) {
            if (players == 2) DuelPreview(colors[YOU], colors[OPPONENT]) else TablePreview(colors)
        }
        seats(players).forEachIndexed { i, (slot, name) ->
            Rise(true, 60 + i * 60, Modifier.padding(top = 22.dp)) {
                Column {
                    SectionHead(if (players == 2 && slot == YOU) "Your color" else "$name color")
                    SwatchGrid(picks[slot]) { pick(slot, it) }
                    BasicText(
                        "$name · ${picks[slot].name}",
                        Modifier.fillMaxWidth().padding(top = 8.dp),
                        style = RiftType.Body.copy(fontSize = 12.5.sp, color = Color.White.copy(alpha = 0.66f), textAlign = TextAlign.Center),
                    )
                }
            }
        }
    }
}

/** [sw] for [slot]; a seat that had it takes [slot]'s old colour, so no two seats share one. */
internal fun pickColor(picks: List<Swatch>, slot: Int, sw: Swatch): List<Swatch> {
    val other = picks.indexOfFirst { it.index == sw.index }
    return picks.mapIndexed { i, s -> if (i == slot) sw else if (i == other) picks[slot] else s }
}

private val PreviewShape = RoundedCornerShape(26.dp)
private val SeatLabel = RiftType.Caption.copy(fontSize = 10.5.sp, letterSpacing = 0.14.em, color = Color.White.copy(alpha = 0.75f))

/** The mock's preview: both halves in their colours as on the board (colour model C), the glowing line in yours. */
@Composable
private fun DuelPreview(you: Color, opp: Color) {
    Box(Modifier.fillMaxWidth().height(200.dp).clip(PreviewShape).background(RiftColors.Page).border(1.dp, Color.White.copy(alpha = 0.1f), PreviewShape)) {
        val line = SeatShade.lift(you)
        Box(Modifier.fillMaxWidth().height(100.dp).background(SeatShade.deep(opp)))
        Box(Modifier.fillMaxWidth().height(100.dp).offset(y = 100.dp).background(SeatShade.deep(you)))
        Box(Modifier.fillMaxWidth().height(2.dp).offset(y = 99.dp).dropShadow(RectangleShape, Shadow(16.dp, line, spread = 2.dp)).background(line))
        BasicText("OPPONENT", Modifier.padding(start = 16.dp, top = 12.dp), style = SeatLabel)
        BasicText("YOU", Modifier.align(Alignment.BottomStart).padding(start = 16.dp, bottom = 12.dp), style = SeatLabel)
        PreviewNumber("5", SeatShade.lift(opp), Modifier.align(Alignment.TopCenter).padding(top = 18.dp).graphicsLayer { rotationZ = 180f })
        PreviewNumber("6", SeatShade.lift(you), Modifier.align(Alignment.BottomCenter).padding(bottom = 18.dp))
    }
}

/** Four seats like the 4-player scoreboard: the far row turned around. */
@Composable
private fun TablePreview(colors: List<Color>) {
    Column(Modifier.fillMaxWidth().height(200.dp).clip(PreviewShape).background(RiftColors.Page).border(1.dp, Color.White.copy(alpha = 0.1f), PreviewShape)) {
        listOf(listOf(0, 1), listOf(2, 3)).forEachIndexed { row, slots ->
            Row(Modifier.weight(1f).fillMaxWidth().graphicsLayer { rotationZ = if (row == 0) 180f else 0f }) {
                (if (row == 0) slots.reversed() else slots).forEach { slot ->
                    Box(Modifier.weight(1f).fillMaxHeight().background(SeatShade.deep(colors[slot]))) {
                        BasicText("P${slot + 1}", Modifier.padding(start = 12.dp, top = 10.dp), style = SeatLabel)
                        PreviewNumber("${slot + 3}", SeatShade.lift(colors[slot]), Modifier.align(Alignment.Center), 48.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun PreviewNumber(text: String, color: Color, modifier: Modifier, size: TextUnit = 64.sp) {
    BasicText(text, modifier, style = RiftType.Title.copy(fontSize = size, lineHeight = size, color = color))
}

/** Four columns of 54dp swatches; the chosen one gets a ring in its colour and a check. */
@Composable
private fun SwatchGrid(chosen: Swatch, onPick: (Swatch) -> Unit) {
    Column(Modifier.padding(top = 4.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        PlayerColors.offered.chunked(4).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { sw -> SwatchButton(sw, sw.index == chosen.index, Modifier.weight(1f)) { onPick(sw) } }
            }
        }
    }
}

private val SwatchShape = RoundedCornerShape(18.dp)

@Composable
private fun SwatchButton(sw: Swatch, on: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val ring by animateFloatAsState(if (on) 1f else 0f, tween(400), label = "ring")
    val page = RiftColors.Page
    Pressable(
        onClick,
        modifier.height(54.dp)
            .semantics { contentDescription = sw.name; selected = on }
            .dropShadow(SwatchShape, Shadow(18.dp, sw.color.copy(alpha = ring)))
            .drawBehind {
                if (ring > 0f) {
                    // box-shadow: 0 0 0 3px page, 0 0 0 5px colour
                    outset(5.dp.toPx(), sw.color.copy(alpha = ring))
                    outset(3.dp.toPx(), page)
                }
            }
            .background(sw.color, SwatchShape),
    ) {
        if (on) Image(SettingsIcons.Check, null, colorFilter = ColorFilter.tint(sw.ink))
    }
}

private fun DrawScope.outset(by: Float, color: Color) {
    drawRoundRect(color, Offset(-by, -by), Size(size.width + by * 2, size.height + by * 2), CornerRadius(18.dp.toPx() + by))
}
