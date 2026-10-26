package pitopia.riftcount.score

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.Placeable
import androidx.compose.ui.layout.SubcomposeLayout
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import pitopia.riftcount.ui.common.Pill
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.RoundIcon
import pitopia.riftcount.ui.common.ScoreIcons
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

/**
 * The pill on the territory line: dice, undo and Reset Score (reset, won, lost). In the duel: die type,
 * roll, close. Match mode ([match]) adds the PlayRiftbound check and the event line (event before round 1, bye,
 * reported round), or for a pairing its round, table, opponent or round clock with a green Report.
 */
@Composable
fun Seam(c: ScoreController, match: MatchInfo?, modifier: Modifier = Modifier) {
    val s = c.state
    val d = c.duel
    val gone = d != null && d.winner >= 0 && !s.isDuel
    val link = match?.link
    val line = match?.line?.takeIf { link == null }
    // The centre always leads to the event, after a question: a slip must not take the scoreboard away.
    var asking by remember { mutableStateOf(false) }
    val event = match?.event
    if (asking && event != null) OpenEventDialog(event, onStay = { asking = false }) { asking = false; match.openEvent() }
    val ask = if (event != null && !gone) ({ asking = true }) else null
    // The pairing as it was tapped: the dialog stays while the strip refreshes under it.
    var reporting by remember { mutableStateOf<TableLink?>(null) }
    reporting?.let { it.report { reporting = null } }
    val shown by animateFloatAsState(if (gone) 0f else 1f, tween(500, easing = RiftEase), label = "seam")
    val shape = RoundedCornerShape(50)
    Box(
        modifier
            .graphicsLayer { alpha = shown; scaleX = 0.85f + 0.15f * shown; scaleY = 0.85f + 0.15f * shown }
            .background(Color(0xEB080808), shape)
            .border(1.dp, Color.White.copy(alpha = 0.18f), shape)
            .padding(6.dp),
    ) {
        AnimatedContent(
            targetState = d != null,
            transitionSpec = { (fadeIn(tween(420, easing = RiftEase)) + scaleIn(tween(420, easing = RiftEase), initialScale = 0.7f)).togetherWith(fadeOut(tween(120))) },
            label = "seamSet",
        ) { duelSet ->
            val board: @Composable (String) -> Unit = { reset ->
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    RoundIcon({ c.openDuel() }, "Roll who goes first", fill = RiftColors.You.copy(alpha = 0.14f), enabled = !gone) {
                        SeamIcon(ScoreIcons.Dice, RiftColors.You)
                    }
                    RoundIcon({ c.undo() }, "Undo last point", enabled = s.canUndo && !gone) { SeamIcon(ScoreIcons.Undo) }
                    when {
                        link != null -> ClockBox(link, onOpen = ask)
                        line != null -> LineBox(line, onOpen = ask)
                    }
                    // Reset, won or lost behind words, so it never passes for Undo (Okay, 2026-10-26: text, not a flag).
                    Pill(reset, { c.openGameMenu() }, Modifier.height(42.dp), enabled = !s.gameOver && !gone)
                    when {
                        link != null -> {
                            Divider()
                            Pill("Report", { reporting = link }, Modifier.height(42.dp), fill = RiftColors.You, ink = Color.Black, enabled = !gone)
                        }
                        match != null -> {
                            Divider()
                            CheckButton(match, enabled = !gone)
                        }
                    }
                }
            }
            if (duelSet && d != null) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    DieTypeSwitch(d.type, enabled = !d.busy && !gone) { c.duelType(it) }
                    Pill(if (s.isDuel) "Roll both" else "Roll all", { c.rollAll() }, Modifier.height(42.dp), fill = Color.White.copy(alpha = 0.13f), enabled = d.canRollAll && !gone)
                    RoundIcon({ c.closeDuel() }, "Back to the scoreboard", enabled = !gone) { SeamIcon(ScoreIcons.Close) }
                }
            } else {
                // "Reset Score", or "Reset" where a pairing leaves no room for it (narrow phones).
                FirstThatFits({ board("Reset Score") }, { board("Reset") })
            }
        }
    }
}

/** The first of [choices] whose natural width fits (iOS `ViewThatFits`); the last one otherwise. */
@Composable
private fun FirstThatFits(vararg choices: @Composable () -> Unit) {
    SubcomposeLayout { constraints ->
        var shown = emptyList<Placeable>()
        for ((i, choice) in choices.withIndex()) {
            val last = i == choices.lastIndex
            shown = subcompose(i, choice).map { it.measure(constraints.copy(minWidth = 0, maxWidth = if (last) constraints.maxWidth else Constraints.Infinity)) }
            if (last || shown.maxOf { it.width } <= constraints.maxWidth) break
        }
        layout(shown.maxOf { it.width }, shown.maxOf { it.height }) { shown.forEach { it.place(0, 0) } }
    }
}

@Composable
private fun SeamIcon(icon: androidx.compose.ui.graphics.vector.ImageVector, tint: Color = Color.White) =
    Image(icon, contentDescription = null, colorFilter = ColorFilter.tint(tint))

@Composable
private fun Divider() = Box(Modifier.size(1.dp, 26.dp).background(Color.White.copy(alpha = 0.16f)))

/** The trophy: asks PlayRiftbound for the pairing now (they go up between rounds); it breathes while it looks. */
@Composable
private fun CheckButton(match: MatchInfo, enabled: Boolean) {
    val breath = if (match.checking) {
        rememberInfiniteTransition(label = "check").animateFloat(1f, 0.35f, infiniteRepeatable(tween(600), RepeatMode.Reverse), label = "breath").value
    } else {
        1f
    }
    RoundIcon(match.check, "Look for your PlayRiftbound match", fill = RiftColors.You.copy(alpha = 0.14f), enabled = enabled && !match.checking) {
        Image(ScoreIcons.Trophy, contentDescription = null, Modifier.graphicsLayer { alpha = breath }, colorFilter = ColorFilter.tint(RiftColors.You))
    }
}

/** The event before round 1, a bye or a reported round; a tap asks to open the event. */
@Composable
private fun LineBox(line: EventLine, onOpen: (() -> Unit)?) {
    Pressable(onOpen ?: {}, Modifier.widthIn(min = 72.dp, max = 140.dp), enabled = onOpen != null, label = "Open the event") {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            BasicText(
                line.label.uppercase(),
                style = TextStyle(fontFamily = RiftType.Text, fontWeight = FontWeight.SemiBold, fontSize = 10.sp, letterSpacing = 0.14.em, color = RiftColors.You),
                maxLines = 1,
            )
            BasicText(
                line.text,
                style = RiftType.Body.copy(fontWeight = FontWeight.SemiBold, fontSize = 14.sp, lineHeight = 18.sp, color = Color.White),
                maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

/**
 * The pairing: round and table over the round's countdown ([TableLink.roundEndsAt], the organiser's clock; gold
 * once over), or over the opponent's name before the round clock runs. A tap asks to open the event.
 */
@Composable
private fun ClockBox(link: TableLink, onOpen: (() -> Unit)?) {
    val caps = TextStyle(fontFamily = RiftType.Text, fontWeight = FontWeight.SemiBold, fontSize = 10.sp, letterSpacing = 0.14.em, color = Color.White.copy(alpha = 0.72f))
    val round = link.roundEndsAt
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    // Redraw exactly when the shown second changes, not on a fixed tick (as iOS does).
    LaunchedEffect(round) {
        now = System.currentTimeMillis()
        while (round != null) {
            delay((round - System.currentTimeMillis()).mod(1000L) + 5)
            now = System.currentTimeMillis()
        }
    }
    val left = round?.let { ((it - now) / 1000).toInt() }
    val over = left != null && left < 0
    val text = when {
        left == null -> "vs ${link.opponent ?: "?"}"
        over -> "+" + clockText(-left)
        else -> clockText(left)
    }
    val label = link.tag.uppercase()
    Pressable(
        onOpen ?: {},
        Modifier.widthIn(min = 72.dp, max = 120.dp).semantics {
            contentDescription = "$label, " + when {
                left == null -> text
                over -> "round over by $text"
                else -> "$text left in the round"
            }
        },
        enabled = onOpen != null, label = "Open the event",
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            BasicText(label, style = caps, maxLines = 1)
            BasicText(
                text,
                style = RiftType.Body.copy(
                    fontWeight = FontWeight.SemiBold, fontSize = if (left == null) 14.sp else 16.sp, lineHeight = 18.sp, fontFeatureSettings = "tnum",
                    color = if (over) RiftColors.Gold else Color.White,
                ),
                maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
        }
    }
}
