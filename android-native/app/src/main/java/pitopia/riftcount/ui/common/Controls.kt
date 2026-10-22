package pitopia.riftcount.ui.common

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.BlurEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

/** Tap target that shrinks a little while pressed (the mocks' `:active { scale(.94) }`), no ripple. */
@Composable
fun Pressable(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    pressedScale: Float = 0.94f,
    role: Role = Role.Button,
    label: String? = null,
    contentAlignment: Alignment = Alignment.Center,
    content: @Composable BoxScope.() -> Unit,
) {
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) pressedScale else 1f, tween(250, easing = RiftEase), label = "press")
    Box(
        modifier
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .clickable(source, indication = null, enabled = enabled, onClickLabel = label, role = role, onClick = onClick),
        contentAlignment = contentAlignment,
        content = content,
    )
}

/** Rounded pill button: filled ([fill]) or ghost (translucent white). */
@Composable
fun Pill(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    fill: Color = Color.White.copy(alpha = 0.10f),
    ink: Color = Color.White,
    border: BorderStroke? = null,
    shape: Shape = RoundedCornerShape(50),
    enabled: Boolean = true,
    style: TextStyle = RiftType.Body.copy(fontWeight = FontWeight.SemiBold, fontSize = 14.sp),
) {
    Pressable(
        onClick,
        modifier
            .graphicsLayer { alpha = if (enabled) 1f else 0.4f }
            .background(fill, shape)
            .let { if (border != null) it.border(border, shape) else it }
            .padding(horizontal = 14.dp),
        enabled = enabled,
    ) {
        BasicText(text, style = style.copy(color = ink), maxLines = 1, softWrap = false)
    }
}

/** Round icon button of the seam (42dp, white 10%). */
@Composable
fun RoundIcon(
    onClick: () -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    size: Dp = 42.dp,
    fill: Color = Color.White.copy(alpha = 0.10f),
    content: @Composable BoxScope.() -> Unit,
) {
    Pressable(
        onClick,
        modifier
            .size(size)
            .semantics { contentDescription = label }
            .graphicsLayer { alpha = if (enabled) 1f else 0.35f }
            .background(fill, CircleShape),
        enabled = enabled,
        label = label,
        content = content,
    )
}

/** The mocks' green underlined text button. */
@Composable
fun LinkButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, color: Color = RiftColors.You) {
    Pressable(onClick, modifier.padding(6.dp)) {
        BasicText(
            text,
            style = RiftType.Body.copy(
                fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = color,
                textDecoration = TextDecoration.Underline,
            ),
        )
    }
}

/** The mock's `.fade` with its delay: up 14dp out of an 8dp blur; all leave in 200ms. */
@Composable
fun Rise(shown: Boolean, delayMs: Int, modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    val t = remember { Animatable(0f) }
    LaunchedEffect(shown) { t.animateTo(if (shown) 1f else 0f, if (shown) tween(700, delayMs, RiftEase) else tween(200)) }
    Box(
        modifier.graphicsLayer {
            val v = t.value
            alpha = v
            translationY = 14.dp.toPx() * (1f - v)
            val b = 8.dp.toPx() * (1f - v)
            renderEffect = if (b > 0.5f) BlurEffect(b, b) else null
        },
    ) { content() }
}

/** The mock's `.send`: a wide green pill with a glow, grey while it cannot be used. */
@Composable
fun GlowButton(text: String, enabled: Boolean, icon: ImageVector? = null, onClick: () -> Unit) {
    val shape = RoundedCornerShape(28.dp)
    val bg by animateColorAsState(if (enabled) RiftColors.You else Color.White.copy(alpha = 0.12f), tween(300), label = "glowBg")
    val ink by animateColorAsState(if (enabled) Color.Black else Color.White.copy(alpha = 0.55f), tween(300), label = "glowInk")
    val glow by animateFloatAsState(if (enabled) 0.35f else 0f, tween(300), label = "glow")
    Pressable(
        onClick,
        Modifier.fillMaxWidth().height(56.dp).dropShadow(shape, Shadow(22.dp, RiftColors.You.copy(alpha = glow))).background(bg, shape),
        enabled = enabled,
        pressedScale = 0.97f,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            icon?.let { Image(it, null, colorFilter = ColorFilter.tint(ink)) }
            BasicText(text, style = RiftType.Body.copy(fontSize = 15.sp, fontWeight = FontWeight.Bold, color = ink))
        }
    }
}
