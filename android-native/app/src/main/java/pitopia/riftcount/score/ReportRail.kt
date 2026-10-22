package pitopia.riftcount.score

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.systemGestureExclusion
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import pitopia.riftcount.platform.Haptic
import pitopia.riftcount.ui.common.ScoreIcons
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

/**
 * "Slide along the light" (Okay's pick): the series' games sit on the line dim; sliding the glowing knob along it
 * lights each game in its winner's colour, and letting go at the end reports the series to PlayRiftbound. The line
 * flashes when Riot has it. Short of the end the knob slides back. "Reported" belongs to the series on the board,
 * never to the pairing alone: a new match or a newer round never inherits it.
 */
@Composable
fun ReportRail(c: ScoreController, colors: List<Color>, accent: Color, railLeft: Dp, railWidth: Dp, centerY: Dp, link: TableLink?) {
    val scope = rememberCoroutineScope()
    val density = LocalDensity.current
    val widthPx = with(density) { railWidth.toPx() }
    val sent = c.reportedSeries()
    val progress = remember { Animatable(if (sent != null) 1f else 0f) }
    val flash = remember { Animatable(1f) }
    var sending by remember { mutableStateOf(false) }
    val canSend = sent == null && !sending && link?.reportable == true

    fun send() {
        val l = link ?: return
        if (!canSend) return
        sending = true
        val log = c.state.log
        scope.launch {
            progress.animateTo(1f, tween(260, easing = RiftEase))
            try {
                // Once it is on its way it finishes and says so, also when the summary closes meanwhile.
                withContext(NonCancellable) {
                    val score = l.report(log.map { it.winner })
                    c.reported(SentReport(l.tag, log, score))
                    c.haptic(Haptic.Success)
                    c.show("Reported to PlayRiftbound · $score")
                }
                sending = false
                repeat(2) {
                    flash.animateTo(0.25f, tween(160))
                    flash.animateTo(1f, tween(220))
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                sending = false
                c.haptic(Haptic.Warning)
                c.show(e.message ?: "Couldn't report. Try again.")
                progress.animateTo(0f, tween(420, easing = RiftEase))
            }
        }
    }

    // The base line and the light that follows the knob.
    val shape = RoundedCornerShape(2.dp)
    Box(Modifier.offset(x = railLeft, y = centerY - 2.dp).size(railWidth, 4.dp).background(Color.White.copy(alpha = 0.18f), shape))
    Box(
        Modifier.offset(x = railLeft, y = centerY - 2.dp).size(railWidth, 4.dp)
            .graphicsLayer { scaleX = progress.value; alpha = flash.value; transformOrigin = TransformOrigin(0f, 0.5f) }
            .dropShadow(shape, Shadow(16.dp, accent, spread = 2.dp)).background(accent, shape),
    )
    val n = c.state.log.size
    c.state.log.forEachIndexed { i, g ->
        val at = (i + 1f) / (n + 1f)
        val lit = progress.value >= at - 0.001f
        val color = if (g.winner < 0) Color.White else colors[g.winner]
        val chip by animateColorAsState(if (lit) color else Color.White.copy(alpha = 0.14f), tween(260), label = "chip")
        val ink by animateColorAsState(if (lit) Color.Black else Color.White.copy(alpha = 0.7f), tween(260), label = "chipInk")
        val x = railLeft + railWidth * at
        Box(Modifier.offset(x = x - 5.dp, y = centerY - 5.dp).size(10.dp).background(chip, CircleShape))
        val text = "G${i + 1} · " + (g.scores?.let { "${it.max()}–${it.min()}" } ?: if (g.winner < 0) "Draw" else c.shortName(g.winner))
        Box(Modifier.offset(x = x - 60.dp, y = centerY - 57.dp).width(120.dp), contentAlignment = Alignment.Center) {
            BasicText(
                text,
                Modifier.background(chip, RoundedCornerShape(17.dp)).padding(horizontal = 12.dp, vertical = 8.dp),
                style = RiftType.Body.copy(fontWeight = FontWeight.SemiBold, fontSize = 13.sp, fontFeatureSettings = "tnum", color = ink),
            )
        }
    }
    // The knob: drag it to the end of the line; TalkBack gets a plain "report" action.
    if (sent == null) {
        Box(
            Modifier.offset(x = railLeft - 17.dp, y = centerY - 17.dp)
                .graphicsLayer { translationX = progress.value * widthPx }
                .size(34.dp)
                .systemGestureExclusion()
                .dropShadow(CircleShape, Shadow(18.dp, RiftColors.You.copy(alpha = 0.8f)))
                .background(RiftColors.You, CircleShape)
                .semantics {
                    contentDescription = "Report ${link?.tag.orEmpty()} to PlayRiftbound"
                    onClick { send(); true }
                }
                .pointerInput(canSend) {
                    if (!canSend) return@pointerInput
                    detectHorizontalDragGestures(
                        onDragEnd = {
                            if (progress.value > 0.92f) send() else scope.launch { progress.animateTo(0f, tween(420, easing = RiftEase)) }
                        },
                    ) { change, dx ->
                        if (sending) return@detectHorizontalDragGestures
                        change.consume()
                        scope.launch { progress.snapTo((progress.value + dx / widthPx).coerceIn(0f, 1f)) }
                    }
                },
            contentAlignment = Alignment.Center,
        ) { Image(ScoreIcons.Arrow, null, Modifier.size(18.dp), colorFilter = ColorFilter.tint(Color.Black)) }
    }
    BasicText(
        when {
            sent != null -> "REPORTED · ${sent.score}"
            sending -> "SENDING TO PLAYRIFTBOUND"
            else -> "SLIDE TO REPORT · ${link?.tag.orEmpty()}"
        },
        Modifier.fillMaxWidth().offset(y = centerY + 12.dp),
        style = RiftType.Body.copy(
            fontSize = 10.5.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.16.em, textAlign = TextAlign.Center,
            color = if (sent != null) RiftColors.You else Color.White.copy(alpha = 0.72f),
        ),
    )
}
