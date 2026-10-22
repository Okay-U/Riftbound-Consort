package pitopia.riftcount.score

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import pitopia.riftcount.ui.common.DialogFrame
import pitopia.riftcount.ui.common.Pill
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

/**
 * After the last game (or "End"): who won the series, one chip per game on the light rail. In match mode the
 * rail reports the series to PlayRiftbound ([ReportRail]).
 */
@Composable
fun MatchSummary(c: ScoreController, colors: List<Color>, centerY: Dp, link: TableLink?) {
    val s = c.state
    val wins = s.seriesWins()
    val lead = when { wins[YOU] > wins[OPPONENT] -> YOU; wins[OPPONENT] > wins[YOU] -> OPPONENT; else -> -1 }
    val series = "${maxOf(wins[0], wins[1])}–${minOf(wins[0], wins[1])}"
    val accent = if (lead < 0) Color.White else colors[lead]
    val headline = if (lead < 0) "Match drawn $series" else "${c.shortName(lead)} ${if (lead == YOU && c.shortName(YOU) == "You") "win" else "wins"} $series"
    // The pairing as Riot has it now: reported meanwhile, or a newer round.
    LaunchedEffect(Unit) { link?.refresh() }
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val railLeft = 28.dp
        val railWidth = maxWidth - 56.dp
        SoftIn(Modifier.fillMaxWidth().offset(y = centerY - 139.dp), delayMs = 700, durationMs = 1200) {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                BasicText("BEST OF ${s.bestOf}", style = TextStyle(fontFamily = RiftType.Text, fontWeight = FontWeight.SemiBold, fontSize = 10.sp, letterSpacing = 0.18.em, color = Color.White.copy(alpha = 0.72f)))
                Spacer(Modifier.height(2.dp))
                BasicText(headline, style = TextStyle(fontFamily = RiftType.Display, fontWeight = FontWeight.Black, fontSize = 36.sp, lineHeight = 36.sp, letterSpacing = 0.06.em, color = accent))
            }
        }
        // Only the series started for the pairing goes to Riot, never a best of three played for practice.
        val live = link?.takeIf { it.tag == s.liveTag }
        val reporting = c.reportedSeries() != null || live?.reportable == true
        if (reporting) SoftIn(Modifier.fillMaxSize(), delayMs = 900, durationMs = 700) {
            Box(Modifier.fillMaxSize()) { ReportRail(c, colors, accent, railLeft, railWidth, centerY, live) }
        } else {
            RailIn(Modifier.offset(x = railLeft, y = centerY - 2.dp).size(railWidth, 4.dp), Color.White.copy(alpha = 0.18f), null)
            RailIn(Modifier.offset(x = railLeft, y = centerY - 2.dp).size(railWidth, 4.dp), accent, accent, delayMs = 1300)
        }
        val n = s.log.size
        if (!reporting) s.log.forEachIndexed { i, g ->
            val x = railLeft + railWidth * ((i + 1f) / (n + 1f))
            val color = if (g.winner < 0) Color.White else colors[g.winner]
            val text = "G${i + 1} · " + (g.scores?.let { "${it.max()}–${it.min()}" } ?: if (g.winner < 0) "Draw" else c.shortName(g.winner))
            Box(Modifier.offset(x = x - 5.dp, y = centerY - 5.dp).size(10.dp).dropShadow(CircleShape, Shadow(12.dp, color)).background(color, CircleShape))
            SoftIn(Modifier.offset(x = x - 60.dp, y = centerY - 57.dp).width(120.dp), delayMs = 1300 + i * 220, durationMs = 600) {
                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    BasicText(
                        text,
                        Modifier.background(color, RoundedCornerShape(17.dp)).padding(horizontal = 12.dp, vertical = 8.dp),
                        style = RiftType.Body.copy(fontWeight = FontWeight.SemiBold, fontSize = 13.sp, fontFeatureSettings = "tnum", color = Color.Black),
                    )
                }
            }
        }
        Column(Modifier.fillMaxWidth().offset(y = centerY + if (reporting) 52.dp else 37.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            SoftIn(delayMs = 1700, durationMs = 600) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Pill("Start a new match", { link?.refresh(); c.newMatch() }, Modifier.height(46.dp), fill = accent, ink = inkOn(accent))
                    Spacer(Modifier.height(4.dp))
                    LinkText("Wrong results? Set them yourself") { c.openPicker(ending = false) }
                    // The event says one game, the table plays three: game 1 then no longer ends the match.
                    if (s.bestOf == 1 && !s.ended && c.reportedSeries() == null) LinkText("We play best of 3") { c.toggleFormat() }
                }
            }
        }
    }
}

@Composable
private fun RailIn(modifier: Modifier, color: Color, glow: Color?, delayMs: Int = 900) {
    val t = remember { Animatable(0f) }
    LaunchedEffect(Unit) { t.animateTo(1f, tween(900, delayMs, RiftEase)) }
    Box(
        modifier
            .graphicsLayer { scaleX = t.value; transformOrigin = TransformOrigin(0f, 0.5f) }
            .let { if (glow != null) it.dropShadow(RoundedCornerShape(2.dp), Shadow(16.dp, glow, spread = 2.dp)) else it }
            .background(color, RoundedCornerShape(2.dp)),
    )
}

@Composable
fun LinkText(text: String, onClick: () -> Unit) {
    Pressable(onClick, Modifier.padding(6.dp)) {
        BasicText(text, style = RiftType.Body.copy(fontWeight = FontWeight.SemiBold, fontSize = 13.sp, color = Color.White.copy(alpha = 0.82f), textDecoration = TextDecoration.Underline))
    }
}

@Composable
private fun DialogText(title: String, text: String) {
    BasicText(title, style = RiftType.Body.copy(fontWeight = FontWeight.Bold, fontSize = 16.sp, color = Color.White))
    Spacer(Modifier.height(6.dp))
    BasicText(text, style = RiftType.Body.copy(fontSize = 13.sp, lineHeight = 19.sp, color = Color.White.copy(alpha = 0.8f)))
    Spacer(Modifier.height(14.dp))
}

@Composable
fun RestartDialog(gameNo: Int, series: Boolean, onKeep: () -> Unit, onRestart: () -> Unit) {
    DialogFrame(onKeep) {
        DialogText(
            "Restart game $gameNo?",
            if (series) "Both scores and XP go back to 0. The series and the match clock stay as they are, and Undo brings the game back."
            else "Both scores and XP go back to 0, and Undo brings the game back.",
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Pill("Keep playing", onKeep, Modifier.weight(1f).height(46.dp))
            Pill("Restart", onRestart, Modifier.weight(1f).height(46.dp), fill = RiftColors.Danger, ink = Color.Black)
        }
    }
}

/** "End the match": what happened in each game, also games nobody kept score of. Draws are allowed. */
@Composable
fun ResultPickerDialog(c: ScoreController, picker: ResultPicker, colors: List<Color>) {
    val me = picker.picks.count { it == YOU }
    val them = picker.picks.count { it == OPPONENT }
    val accent = if (me == them) Color.White else if (me > them) colors[YOU] else colors[OPPONENT]
    DialogFrame(c::closePicker) {
        DialogText(
            if (picker.ending) "End the match" else "Set the game results",
            if (picker.ending) "Pick what happened in each game, also games nobody kept score of or an intentional draw. Empty games are left out."
            else "Pick the result of each game.",
        )
        picker.picks.forEachIndexed { i, v ->
            val locked = picker.locked(i)
            Column(Modifier.graphicsLayer { alpha = if (locked) 0.35f else 1f }.padding(bottom = 12.dp)) {
                BasicText("GAME ${i + 1}", style = TextStyle(fontFamily = RiftType.Text, fontWeight = FontWeight.SemiBold, fontSize = 12.sp, letterSpacing = 0.06.em, color = Color.White.copy(alpha = 0.72f)))
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    listOf(YOU to c.shortName(YOU), -1 to "Draw", OPPONENT to c.shortName(OPPONENT)).forEach { (who, label) ->
                        val on = v == who
                        val fill = if (!on) Color.White.copy(alpha = 0.06f) else if (who < 0) Color.White else colors[who]
                        Pill(
                            label, { c.choose(i, who) }, Modifier.weight(1f).height(44.dp), fill = fill,
                            ink = if (on) Color.Black else Color.White, enabled = !locked,
                            border = androidx.compose.foundation.BorderStroke(1.dp, Color.White.copy(alpha = 0.18f)),
                        )
                    }
                }
            }
        }
        Row(
            Modifier.fillMaxWidth().background(Color.White.copy(alpha = 0.05f), RoundedCornerShape(16.dp)).padding(horizontal = 14.dp, vertical = 10.dp),
            horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically,
        ) {
            BasicText(c.shortName(YOU), style = RiftType.Body.copy(fontWeight = FontWeight.SemiBold, fontSize = 14.sp, color = Color.White))
            BasicText("$me – $them", style = TextStyle(fontFamily = RiftType.Display, fontWeight = FontWeight.Black, fontSize = 22.sp, color = accent, textAlign = TextAlign.Center))
            BasicText(c.shortName(OPPONENT), style = RiftType.Body.copy(fontWeight = FontWeight.SemiBold, fontSize = 14.sp, color = Color.White))
        }
        Spacer(Modifier.height(14.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Pill("Cancel", { c.closePicker() }, Modifier.weight(1f).height(46.dp))
            Pill(
                if (picker.ending) "End match" else "Done", { c.pickDone() }, Modifier.weight(1f).height(46.dp),
                fill = accent, ink = Color.Black, enabled = picker.picks.any { it != null },
            )
        }
    }
}

/** Toast in the middle of the board for 2.2s. */
@Composable
fun BoardToast(toast: Toast?, onDone: (Long) -> Unit, modifier: Modifier = Modifier) {
    if (toast == null) return
    LaunchedEffect(toast.id) { delay(2200); onDone(toast.id) }
    HalfToast(toast.text, modifier)
}
