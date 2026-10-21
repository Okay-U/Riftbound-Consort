package pitopia.riftcount.ui.common

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
