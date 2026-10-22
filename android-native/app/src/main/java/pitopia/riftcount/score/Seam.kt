package pitopia.riftcount.score

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
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
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import pitopia.riftcount.ui.common.Pill
import pitopia.riftcount.ui.common.RoundIcon
import pitopia.riftcount.ui.common.ScoreIcons
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

/**
 * The pill on the territory line: dice, undo, game and clock, restart, end. In the duel: die type, roll, close.
 * With a PlayRiftbound pairing ([link]) not yet started it shows the table and opponent with Start match;
 * once started, the round and table, and End becomes Report.
 */
@Composable
fun Seam(c: ScoreController, link: TableLink?, modifier: Modifier = Modifier) {
    val s = c.state
    val d = c.duel
    val gone = s.showSummary || (d != null && d.winner >= 0 && !s.isDuel)
    val live = link?.takeIf { it.tag == s.liveTag }
    val waiting = link?.takeIf { s.isDuel && it.reportable && it.tag != s.liveTag }
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
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                if (duelSet && d != null) {
                    DieTypeSwitch(d.type, enabled = !d.busy && !gone) { c.duelType(it) }
                    Pill(if (s.isDuel) "Roll both" else "Roll all", { c.rollAll() }, Modifier.height(42.dp), fill = Color.White.copy(alpha = 0.13f), enabled = d.canRollAll && !gone)
                    RoundIcon({ c.closeDuel() }, "Back to the scoreboard", enabled = !gone) { SeamIcon(ScoreIcons.Close) }
                } else {
                    RoundIcon({ c.openDuel() }, "Roll who goes first", fill = RiftColors.You.copy(alpha = 0.14f), enabled = !gone) {
                        SeamIcon(ScoreIcons.Dice, RiftColors.You)
                    }
                    RoundIcon({ c.undo() }, "Undo last point", enabled = s.canUndo && !gone) { SeamIcon(ScoreIcons.Undo) }
                    ClockBox(
                        s, live?.tag, waiting,
                        onTap = { if (waiting != null) c.startLive(waiting) else if (s.isDuel) c.toggleFormat() else c.toggleClock() },
                        onLongPress = { c.toggleClock() },
                    )
                    // Waiting for Start match, the table and opponent need the room; restart comes back with the match.
                    if (waiting == null) RoundIcon({ c.askRestart() }, "Restart this game", enabled = !s.gameOver && !gone) { SeamIcon(ScoreIcons.Restart) }
                    if (s.isDuel) {
                        Box(Modifier.size(1.dp, 26.dp).background(Color.White.copy(alpha = 0.16f)))
                        if (waiting != null) {
                            Pill("Start match", { c.startLive(waiting) }, Modifier.height(42.dp), fill = RiftColors.You, ink = Color.Black, enabled = !gone)
                        } else {
                            Pill(
                                if (live?.reportable == true) "Report" else "End", { c.openPicker(ending = true) }, Modifier.height(42.dp),
                                fill = Color.White.copy(alpha = 0.13f), enabled = !gone && (s.isSeries || !s.gameOver),
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SeamIcon(icon: androidx.compose.ui.graphics.vector.ImageVector, tint: Color = Color.White) =
    Image(icon, contentDescription = null, colorFilter = ColorFilter.tint(tint))

/**
 * The game and the match clock. Tap switches casual ↔ best of three (one ↔ three games in a live match),
 * long press pauses the clock. Before a live match starts: its table and opponent, and tap starts it.
 */
@Composable
private fun ClockBox(s: ScoreState, tag: String?, waiting: TableLink?, onTap: () -> Unit, onLongPress: () -> Unit) {
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    // Redraw exactly when the shown second changes, not on a fixed tick (as iOS does).
    LaunchedEffect(s.clock) {
        now = System.currentTimeMillis()
        while (s.clock.isRunning) {
            delay(1000 - s.clock.elapsedMs(System.currentTimeMillis()) % 1000 + 5)
            now = System.currentTimeMillis()
        }
    }
    val text = clockText(s.clock.elapsedSeconds(now))
    val paused = !s.clock.isRunning && s.clock.accumulatedMs > 0
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) 0.94f else 1f, tween(250, easing = RiftEase), label = "press")
    val label = when {
        waiting != null -> waiting.table?.let { "TABLE $it" } ?: waiting.tag.uppercase()
        paused -> "PAUSED"
        tag != null -> tag.uppercase()
        !s.isDuel -> "${s.players.size} PLAYERS"
        s.isSeries -> "BO${s.bestOf} · GAME ${s.gameNo}"
        else -> "GAME ${s.gameNo}"
    }
    val tapLabel = when {
        waiting != null -> "Start the live match"
        !s.isDuel -> if (s.clock.isRunning) "Pause the clock" else "Start the clock"
        s.liveTag != null -> if (s.bestOf == 1) "Play best of three" else "Play best of one"
        else -> if (s.isSeries) "Play casual games" else "Play best of three"
    }
    Box(
        Modifier.widthIn(min = 72.dp, max = 132.dp)
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .combinedClickable(
                source, indication = null, role = Role.Button, onClickLabel = tapLabel,
                onLongClickLabel = if (s.clock.isRunning) "Pause the clock" else "Start the clock",
                onLongClick = onLongPress, hapticFeedbackEnabled = false, onClick = onTap,
            )
            .semantics { contentDescription = if (waiting != null) "$label, ${waiting.opponent ?: ""}" else "$label, match clock $text" + if (paused) ", paused" else "" },
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            BasicText(
                label,
                style = TextStyle(fontFamily = RiftType.Text, fontWeight = FontWeight.SemiBold, fontSize = 10.sp, letterSpacing = 0.14.em, color = if (paused && waiting == null) RiftColors.Gold else Color.White.copy(alpha = 0.72f)),
                maxLines = 1,
            )
            BasicText(
                if (waiting != null) "vs ${waiting.opponent ?: "?"}" else text,
                style = RiftType.Body.copy(fontWeight = FontWeight.SemiBold, fontSize = if (waiting != null) 14.sp else 16.sp, lineHeight = 18.sp, fontFeatureSettings = "tnum", color = Color.White),
                maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
        }
    }
}
