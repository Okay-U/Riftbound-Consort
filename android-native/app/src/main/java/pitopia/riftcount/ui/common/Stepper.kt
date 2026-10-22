package pitopia.riftcount.ui.common

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.EnterExitState
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.animateDp
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.BlurredEdgeTreatment
import androidx.compose.ui.draw.blur
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

private val StepOut = CubicBezierEasing(0.4f, 0f, 0.2f, 1f)

/** − count + as in the mocks: round buttons, the count blurs up and out and the new one rises in. [what] names one item for TalkBack. */
@Composable
fun Stepper(
    count: Int,
    onMinus: () -> Unit,
    onPlus: () -> Unit,
    what: String,
    modifier: Modifier = Modifier,
    minus: Boolean = count > 0,
    plus: Boolean = true,
    button: Dp = 38.dp,
) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        StepButton("−", "Remove one $what", minus, button, onMinus)
        StepCount(count, button, Modifier.semantics { contentDescription = "$count × $what" })
        StepButton("+", "Add one $what", plus, button, onPlus)
    }
}

@Composable
private fun StepButton(text: String, label: String, enabled: Boolean, size: Dp, onClick: () -> Unit) {
    Pressable(
        onClick,
        Modifier.size(size).semantics { contentDescription = label }.graphicsLayer { alpha = if (enabled) 1f else 0.3f }
            .background(Color.White.copy(alpha = 0.06f), CircleShape).border(1.dp, Color.White.copy(alpha = 0.18f), CircleShape),
        enabled = enabled,
        pressedScale = 0.9f,
    ) {
        BasicText(text, style = RiftType.Body.copy(fontSize = (size.value * 0.47f).sp, fontWeight = FontWeight.SemiBold, color = Color.White))
    }
}

/** A number that changes like the scoreboard's: [height] sets the box, the type follows it. */
@Composable
fun StepCount(count: Int, height: Dp, modifier: Modifier = Modifier, color: Color = Color.White, width: Dp = 30.dp, fontSize: Float = height.value * 0.63f, suffix: String = "") {
    val style = TextStyle(fontFamily = RiftType.Display, fontWeight = FontWeight.Black, fontSize = fontSize.sp, lineHeight = fontSize.sp, color = color, textAlign = TextAlign.Center)
    AnimatedContent(
        targetState = count,
        modifier = modifier.size(width, height),
        transitionSpec = {
            (fadeIn(tween(620, easing = RiftEase)) + slideInVertically(tween(620, easing = RiftEase)) { (it * 0.4f).toInt() })
                .togetherWith(fadeOut(tween(420, easing = StepOut)) + slideOutVertically(tween(420, easing = StepOut)) { -(it * 0.4f).toInt() })
        },
        contentAlignment = Alignment.Center,
        label = "count",
    ) { n ->
        val blur by transition.animateDp(label = "blur") { if (it == EnterExitState.Visible) 0.dp else 8.dp }
        Box(Modifier.size(width, height), contentAlignment = Alignment.Center) {
            BasicText("$n$suffix", Modifier.blur(blur, BlurredEdgeTreatment.Unbounded), style = style, maxLines = 1, softWrap = false)
        }
    }
}
