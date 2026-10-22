package pitopia.riftcount.ui.shell

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

/** [key] is the `currentTab` value the Skip app stored; its old "dice" tab maps to Score. */
enum class Tab(val label: String, val icon: ImageVector, val key: String) {
    Score("Score", NavIcons.Score, "score"),
    Events("Events", NavIcons.Events, "events"),
    Cards("Cards", NavIcons.Cards, "cards"),
    Decks("Decks", NavIcons.Decks, "decks"),
    Settings("Settings", NavIcons.Settings, "settings"),
    ;

    companion object {
        fun fromKey(key: String): Tab = entries.firstOrNull { it.key == key } ?: Score
    }
}

private val BarShape = RoundedCornerShape(33.dp)
private val KnobShape = RoundedCornerShape(25.dp)
private val BarInset = 6.dp

/** Floating pill bar from the mocks; the green knob glides to the selected tab. [hidden] fades it under an overlay. */
@Composable
fun BottomNav(selected: Tab, onSelect: (Tab) -> Unit, modifier: Modifier = Modifier, hidden: Boolean = false) {
    val shown by animateFloatAsState(if (hidden) 0f else 1f, tween(420, easing = RiftEase), label = "nav")
    // Faded out it would still catch taps meant for the overlay underneath.
    if (shown == 0f) return
    BoxWithConstraints(
        modifier
            .graphicsLayer { alpha = shown }
            .navigationBarsPadding()
            .padding(start = 14.dp, end = 14.dp, bottom = 14.dp)
            .fillMaxWidth()
            .height(66.dp)
            .background(RiftColors.NavBar, BarShape)
            .border(1.dp, RiftColors.Hairline, BarShape),
    ) {
        val itemWidth = (maxWidth - BarInset * 2) / Tab.entries.size
        val knobX by animateDpAsState(
            targetValue = BarInset + itemWidth * selected.ordinal + 2.dp,
            animationSpec = tween(durationMillis = 520, easing = RiftEase),
            label = "knob",
        )
        Box(
            Modifier
                .offset { IntOffset(knobX.roundToPx(), 7.dp.roundToPx()) }
                .width(itemWidth - 4.dp)
                .height(50.dp)
                .dropShadow(KnobShape, Shadow(radius = 18.dp, color = RiftColors.You.copy(alpha = 0.18f)))
                .background(RiftColors.You.copy(alpha = 0.14f), KnobShape)
                .border(1.dp, RiftColors.You.copy(alpha = 0.4f), KnobShape),
        )
        Row(Modifier.padding(horizontal = BarInset).fillMaxHeight(), verticalAlignment = Alignment.CenterVertically) {
            Tab.entries.forEach { tab ->
                NavItem(tab, tab == selected, Modifier.width(itemWidth)) { if (!hidden) onSelect(tab) }
            }
        }
    }
}

@Composable
private fun NavItem(tab: Tab, active: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val tint by animateColorAsState(
        targetValue = if (active) RiftColors.You else RiftColors.InkMuted,
        animationSpec = tween(durationMillis = 300),
        label = "tint",
    )
    Column(
        modifier
            .fillMaxHeight()
            .selectable(
                selected = active,
                onClick = onClick,
                role = Role.Tab,
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
            ),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Image(tab.icon, contentDescription = null, colorFilter = ColorFilter.tint(tint))
        Spacer(Modifier.height(3.dp))
        BasicText(tab.label, style = RiftType.NavLabel.copy(color = tint))
    }
}
