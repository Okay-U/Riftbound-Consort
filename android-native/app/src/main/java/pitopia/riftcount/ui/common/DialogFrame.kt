package pitopia.riftcount.ui.common

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.window.DialogWindowProvider
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import pitopia.riftcount.ui.theme.RiftEase

/**
 * Shared dialog: its own window above the tab bar (back closes it via [onDismiss]), our dim scrim instead
 * of the platform's, and a centred card that pops in. Taps on the scrim do nothing, like the mock.
 */
@Composable
fun DialogFrame(onDismiss: () -> Unit, fullScreen: Boolean = true, content: @Composable () -> Unit) = Dialog(
    onDismissRequest = onDismiss,
    properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false),
) {
    val view = LocalView.current
    val window = (view.parent as? DialogWindowProvider)?.window
    SideEffect {
        window?.setDimAmount(0f)
        // A dialog is its own window: keep the status bar hidden like the screen below it.
        if (fullScreen && window != null) WindowCompat.getInsetsController(window, view).hide(WindowInsetsCompat.Type.statusBars())
    }
    val t = remember { Animatable(0f) }
    LaunchedEffect(Unit) { t.animateTo(1f, tween(460, easing = RiftEase)) }
    Box(
        Modifier.fillMaxSize().graphicsLayer { alpha = t.value }.background(Color.Black.copy(alpha = 0.66f))
            .clickable(remember { MutableInteractionSource() }, indication = null) {},
        contentAlignment = Alignment.Center,
    ) {
        val shape = RoundedCornerShape(26.dp)
        Column(
            Modifier.padding(horizontal = 24.dp).widthIn(max = 352.dp)
                .graphicsLayer { translationY = 10.dp.toPx() * (1f - t.value); scaleX = 0.95f + 0.05f * t.value; scaleY = 0.95f + 0.05f * t.value }
                .background(Color(0xFF121212), shape).border(1.dp, Color.White.copy(alpha = 0.14f), shape).padding(20.dp),
        ) { content() }
    }
}
