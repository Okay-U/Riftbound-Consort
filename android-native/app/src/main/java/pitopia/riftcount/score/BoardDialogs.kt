package pitopia.riftcount.score

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import pitopia.riftcount.ui.common.DialogFrame
import pitopia.riftcount.ui.common.Pill
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftType

@Composable
private fun DialogText(title: String, text: String) {
    BasicText(title, style = RiftType.Body.copy(fontWeight = FontWeight.Bold, fontSize = 16.sp, color = Color.White))
    Spacer(Modifier.height(6.dp))
    BasicText(text, style = RiftType.Body.copy(fontSize = 13.sp, lineHeight = 19.sp, color = Color.White.copy(alpha = 0.8f)))
    Spacer(Modifier.height(14.dp))
}

/** Before the scoreboard gives way to the Events tab: the event line is easy to hit by mistake. */
@Composable
fun OpenEventDialog(event: String, onStay: () -> Unit, onOpen: () -> Unit) {
    DialogFrame(onStay) {
        DialogText("Open the event?", "$event opens in Events. Your scoreboard stays as it is.")
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Pill("Stay here", onStay, Modifier.weight(1f).height(46.dp))
            Pill("Open event", onOpen, Modifier.weight(1f).height(46.dp), fill = RiftColors.You, ink = Color.Black)
        }
    }
}

/**
 * The seam's Reset Score (Okay, 2026-10-26): Reset sets the game to 0 and Undo brings it back; I won / I lost end
 * the game as it stands, for a concession or points the board missed. Four players only reset.
 */
@Composable
fun GameDialog(duel: Boolean, swatches: List<Swatch>, onKeep: () -> Unit, onEnd: (Int) -> Unit, onRestart: () -> Unit) {
    DialogFrame(onKeep) {
        if (duel) {
            DialogText(
                "Reset the score or end the game?",
                "Reset sets both scores and XP back to 0, and Undo brings them back. Won or lost ends the game as it stands, for a concession or points the board missed.",
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Pill("I won", { onEnd(YOU) }, Modifier.weight(1f).height(46.dp), fill = swatches[YOU].color, ink = swatches[YOU].ink)
                Pill("I lost", { onEnd(OPPONENT) }, Modifier.weight(1f).height(46.dp), fill = swatches[OPPONENT].color, ink = swatches[OPPONENT].ink)
            }
            Spacer(Modifier.height(8.dp))
        } else {
            DialogText("Reset the score?", "All scores and XP go back to 0, and Undo brings them back.")
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Pill("Keep playing", onKeep, Modifier.weight(1f).height(46.dp))
            Pill("Reset", onRestart, Modifier.weight(1f).height(46.dp), fill = RiftColors.Danger, ink = Color.Black)
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
