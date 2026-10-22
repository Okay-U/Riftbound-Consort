package pitopia.riftcount.ui.common

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

/** One short confirmation at a time ("Added to Void Tempo · 2 of 3"); a new one replaces it. */
class Toaster {
    class Line(val id: Int, val text: String)

    var line by mutableStateOf<Line?>(null)
        private set

    fun show(text: String) {
        line = Line((line?.id ?: 0) + 1, text)
    }

    fun done(id: Int) {
        if (line?.id == id) line = null
    }
}

/** The mocks' toast: a dark pill with a green rim under the status bar, 2.2 s. */
@Composable
fun BoxScope.ToastHost(toaster: Toaster) {
    val line = toaster.line ?: return
    val t = remember(line.id) { Animatable(0f) }
    LaunchedEffect(line.id) {
        t.animateTo(1f, tween(520, easing = RiftEase))
        delay(1700)
        t.animateTo(0f, tween(260))
        toaster.done(line.id)
    }
    val shape = RoundedCornerShape(50)
    BasicText(
        line.text,
        Modifier.align(Alignment.TopCenter).statusBarsPadding().padding(top = 22.dp, start = 16.dp, end = 16.dp)
            .graphicsLayer {
                alpha = t.value
                translationY = -10.dp.toPx() * (1f - t.value)
                scaleX = 0.95f + 0.05f * t.value
                scaleY = scaleX
            }
            .dropShadow(shape, Shadow(radius = 22.dp, color = RiftColors.You.copy(alpha = 0.2f)))
            .background(Color(0xF7101010), shape).border(1.dp, RiftColors.You.copy(alpha = 0.45f), shape)
            .padding(horizontal = 18.dp, vertical = 11.dp),
        style = RiftType.Body.copy(fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color.White),
        maxLines = 1,
    )
}
