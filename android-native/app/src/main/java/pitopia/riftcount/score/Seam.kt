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
import androidx.compose.runtime.mutableStateOf
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
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.RoundIcon
import pitopia.riftcount.ui.common.ScoreIcons
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

/**
 * The pill on the territory line: dice, undo, restart. In the duel: die type, roll, close. Casual play counts
 * nothing more; match mode ([match]) adds the PlayRiftbound check, the event line (event before round 1, bye,
 * reported round), and for a pairing its table and opponent with Start match. A started live match shows its
 * round, table and clock, with Report or End.
 */
@Composable
fun Seam(c: ScoreController, match: MatchInfo?, modifier: Modifier = Modifier) {
    val s = c.state
    val d = c.duel
    val gone = s.showSummary || (d != null && d.winner >= 0 && !s.isDuel)
    val link = match?.link
    val live = link?.takeIf { it.tag == s.liveTag }
    val waiting = link?.takeIf { s.isDuel && it.reportable && it.tag != s.liveTag }
    val line = match?.line?.takeIf { s.liveTag == null && waiting == null }
    // The centre always leads to the event, after a question: a slip must not take the scoreboard away.
    var asking by remember { mutableStateOf(false) }
    val event = match?.event
    if (asking && event != null) OpenEventDialog(event, onStay = { asking = false }) { asking = false; match.openEvent() }
    val ask = if (event != null && !gone) ({ asking = true }) else null
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
                    when {
                        waiting != null || s.liveTag != null ->
                            ClockBox(s, waiting, live?.roundEndsAt, onOpen = ask, onClock = c::toggleClock)
                        line != null -> LineBox(line, onOpen = ask)
                    }
                    // Waiting for Start match, the table and opponent need the room; restart comes back with the match.
                    if (waiting == null) RoundIcon({ c.askRestart() }, "Restart this game", enabled = !s.gameOver && !gone) { SeamIcon(ScoreIcons.Restart) }
                    when {
                        waiting != null -> {
                            Divider()
                            Pill("Start match", { c.startLive(waiting) }, Modifier.height(42.dp), fill = RiftColors.You, ink = Color.Black, enabled = !gone)
                        }
                        s.isSeries -> {
                            Divider()
                            Pill(if (live?.reportable == true) "Report" else "End", { c.openPicker(ending = true) }, Modifier.height(42.dp), fill = Color.White.copy(alpha = 0.13f), enabled = !gone)
                        }
                        match != null -> {
                            Divider()
                            CheckButton(match, enabled = !gone)
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
 * Before a live match: its table and opponent (Start match beside it starts it). During it: round and table
 * over the round's countdown ([roundEnd], the organiser's clock; gold once over), or the match clock where
 * the round has none, which a long press pauses. A tap asks to open the event. Casual play shows no clock.
 */
@Composable
private fun ClockBox(s: ScoreState, waiting: TableLink?, roundEnd: Long?, onOpen: (() -> Unit)?, onClock: () -> Unit) {
    val caps = TextStyle(fontFamily = RiftType.Text, fontWeight = FontWeight.SemiBold, fontSize = 10.sp, letterSpacing = 0.14.em, color = Color.White.copy(alpha = 0.72f))
    val tag = s.liveTag
    val round = roundEnd.takeIf { waiting == null }
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    // Redraw exactly when the shown second changes, not on a fixed tick (as iOS does).
    LaunchedEffect(s.clock, round) {
        now = System.currentTimeMillis()
        while (round != null || s.clock.isRunning) {
            val ms = if (round != null) (round - System.currentTimeMillis()).mod(1000L) else 1000 - s.clock.elapsedMs(System.currentTimeMillis()) % 1000
            delay(ms + 5)
            now = System.currentTimeMillis()
        }
    }
    val left = round?.let { ((it - now) / 1000).toInt() }
    val over = left != null && left < 0
    val text = when {
        left == null -> clockText(s.clock.elapsedSeconds(now))
        over -> "+" + clockText(-left)
        else -> clockText(left)
    }
    val paused = waiting == null && round == null && !s.clock.isRunning && s.clock.accumulatedMs > 0
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) 0.94f else 1f, tween(250, easing = RiftEase), label = "press")
    val label = when {
        waiting != null -> waiting.table?.let { "TABLE $it" } ?: waiting.tag.uppercase()
        paused -> "PAUSED"
        else -> tag.orEmpty().uppercase()
    }
    val clockLabel = if (s.clock.isRunning) "Pause the clock" else "Start the clock"
    val longPress = if (waiting != null || round != null) null else onClock
    Box(
        Modifier.widthIn(min = 72.dp, max = 132.dp)
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .combinedClickable(
                source, indication = null, enabled = onOpen != null || longPress != null, role = Role.Button,
                onClickLabel = "Open the event",
                onLongClickLabel = if (longPress != null) clockLabel else null,
                onLongClick = longPress,
                hapticFeedbackEnabled = false,
                onClick = onOpen ?: {},
            )
            .semantics {
                contentDescription = when {
                    waiting != null -> "$label, vs ${waiting.opponent.orEmpty()}"
                    round != null -> "$label, " + if (over) "round over by $text" else "$text left in the round"
                    else -> "$label, match clock $text" + if (paused) ", paused" else ""
                }
            },
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            BasicText(label, style = if (paused) caps.copy(color = RiftColors.Gold) else caps, maxLines = 1)
            BasicText(
                if (waiting != null) "vs ${waiting.opponent ?: "?"}" else text,
                style = RiftType.Body.copy(
                    fontWeight = FontWeight.SemiBold, fontSize = if (waiting != null) 14.sp else 16.sp, lineHeight = 18.sp, fontFeatureSettings = "tnum",
                    color = if (over) RiftColors.Gold else Color.White,
                ),
                maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
        }
    }
}
