package pitopia.riftcount.ui.common

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.paneTitle
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.window.DialogWindowProvider
import kotlinx.coroutines.launch
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase

private val SheetShape = RoundedCornerShape(28.dp)
private val Sink = CubicBezierEasing(0.4f, 0f, 1f, 1f)

/**
 * The mocks' bottom sheet: its own window so it covers the tab bar, rises 40dp in (600ms), sinks out (260ms).
 * [content] gets `close`, which plays the exit before [onDismiss]; [overlay] draws above the scrim (toasts).
 */
@Composable
fun Sheet(
    label: String,
    onDismiss: () -> Unit,
    overlay: @Composable BoxScope.() -> Unit = {},
    content: @Composable ColumnScope.(close: () -> Unit) -> Unit,
) {
    val t = remember { Animatable(0f) }
    var closing by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val close: () -> Unit = {
        if (!closing) {
            closing = true
            scope.launch {
                t.animateTo(0f, tween(260, easing = Sink))
                onDismiss()
            }
        }
    }
    Dialog(
        onDismissRequest = close,
        properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false, dismissOnClickOutside = false),
    ) {
        val window = (LocalView.current.parent as? DialogWindowProvider)?.window
        SideEffect { window?.setDimAmount(0f) }
        LaunchedEffect(Unit) { t.animateTo(1f, tween(600, easing = RiftEase)) }
        Box(Modifier.fillMaxSize()) {
            Box(
                Modifier.fillMaxSize().graphicsLayer { alpha = t.value }.background(Color.Black.copy(alpha = 0.62f))
                    .clickable(remember { MutableInteractionSource() }, indication = null, onClick = close),
            )
            Column(
                Modifier.align(Alignment.BottomCenter).statusBarsPadding().navigationBarsPadding().imePadding()
                    .padding(10.dp).fillMaxWidth()
                    .graphicsLayer { alpha = t.value; translationY = 40.dp.toPx() * (1f - t.value) }
                    .background(RiftColors.Sheet, SheetShape).border(1.dp, Color.White.copy(alpha = 0.12f), SheetShape)
                    .clickable(remember { MutableInteractionSource() }, indication = null) {}
                    .semantics { paneTitle = label }
                    .verticalScroll(rememberScrollState())
                    .padding(start = 20.dp, end = 20.dp, top = 10.dp, bottom = 20.dp),
            ) {
                Box(
                    Modifier.align(Alignment.CenterHorizontally).padding(bottom = 12.dp).size(40.dp, 4.dp)
                        .background(Color.White.copy(alpha = 0.24f), RoundedCornerShape(2.dp)),
                )
                content(close)
            }
            overlay()
        }
    }
}
