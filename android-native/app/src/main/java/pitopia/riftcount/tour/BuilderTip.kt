package pitopia.riftcount.tour

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import pitopia.riftcount.ui.common.GlowButton
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

private val Steps = listOf(
    "Pick a Legend",
    "Pick its Champion",
    "Choose Battlefields",
    "Fill Main + Side decks (3-of cap)",
    "Adjust Runes (12 total, ±)",
    "Save your deck",
)

/** iOS `BuilderTipOverlay`: the builder's steps once, the first time it opens (`didSeeBuilderTip`). */
@Composable
fun BuilderTip(onDone: () -> Unit) {
    val t = remember { Animatable(0f) }
    LaunchedEffect(Unit) { t.animateTo(1f, tween(420, easing = RiftEase)) }
    BackHandler(onBack = onDone)
    val shape = RoundedCornerShape(28.dp)
    Box(
        Modifier.fillMaxSize().graphicsLayer { alpha = t.value }.background(Color.Black.copy(alpha = 0.62f))
            .clickable(remember { MutableInteractionSource() }, null) {},
        contentAlignment = Alignment.Center,
    ) {
        Column(
            Modifier.padding(24.dp).widthIn(max = 420.dp).fillMaxWidth()
                .graphicsLayer { val s = 0.96f + 0.04f * t.value; scaleX = s; scaleY = s }
                .background(RiftColors.Sheet, shape).border(1.dp, Color.White.copy(alpha = 0.1f), shape)
                .padding(22.dp),
        ) {
            BasicText("Build a deck", style = RiftType.Title.copy(fontSize = 34.sp, lineHeight = 34.sp, color = Color.White))
            BasicText(
                "Walk through these steps in order:",
                Modifier.padding(top = 8.dp, bottom = 16.dp),
                style = RiftType.Body.copy(fontSize = 14.sp, color = Color.White.copy(alpha = 0.7f)),
            )
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Steps.forEachIndexed { i, step ->
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Box(Modifier.size(26.dp).background(RiftColors.You.copy(alpha = 0.16f), CircleShape), contentAlignment = Alignment.Center) {
                            BasicText("${i + 1}", style = RiftType.Body.copy(fontSize = 12.sp, fontWeight = FontWeight.Bold, color = RiftColors.You))
                        }
                        BasicText(step, style = RiftType.Body.copy(fontSize = 15.sp, color = Color.White))
                    }
                }
            }
            Box(Modifier.padding(top = 22.dp)) { GlowButton("Got it", enabled = true, onClick = onDone) }
        }
    }
}
