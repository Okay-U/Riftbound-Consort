package pitopia.riftcount.decks

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.unit.dp
import pitopia.riftcount.cards.Card
import pitopia.riftcount.cards.CardIcons
import pitopia.riftcount.cards.Shortlist
import pitopia.riftcount.platform.Haptic
import pitopia.riftcount.platform.haptic
import pitopia.riftcount.ui.common.RoundIcon
import pitopia.riftcount.ui.common.Sheet
import pitopia.riftcount.ui.theme.RiftColors

/**
 * The cards kept in mind, opened from the Decks table (Okay, 2026-10-22), grouped like a deck's gallery. The star
 * takes a card off; it stays until the sheet closes, dimmed, so a second tap puts it back.
 */
@Composable
fun ShortlistSheet(index: Map<String, Card>, onDismiss: () -> Unit) {
    val shown = remember { Shortlist.ids.mapNotNull { index[it] } }
    val tilePx = LocalWindowInfo.current.containerSize.width / 3
    Sheet("Shortlist", onDismiss) {
        BasicText("Shortlist", style = SheetTitle)
        BasicText(
            if (shown.isEmpty()) "Save a card on its Add to deck sheet in Cards. It waits here and in the builder."
            else "${Shortlist.ids.size} kept in mind · the star takes a card off",
            Modifier.padding(top = 4.dp, bottom = 4.dp),
            style = SheetText,
        )
        galleryGroups(shown.map { it to 1 }, byEnergy = false).forEach { (label, group) ->
            Row(Modifier.fillMaxWidth().padding(top = 12.dp, bottom = 8.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                GroupLabel(label)
                GroupLabel("${group.size}")
            }
            group.chunked(3).forEach { row ->
                Row(Modifier.fillMaxWidth().padding(bottom = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    row.forEach { (card, _) -> KeptTile(card, tilePx, Modifier.weight(1f)) }
                    repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
    }
}

@Composable
private fun KeptTile(card: Card, tilePx: Int, modifier: Modifier) {
    val view = LocalView.current
    val on = Shortlist.has(card.id)
    val dim by animateFloatAsState(if (on) 1f else 0.4f, tween(300), label = "kept")
    Box(modifier) {
        CardTile(card, tilePx, Modifier.fillMaxWidth().graphicsLayer { alpha = dim }) {}
        RoundIcon(
            {
                Shortlist.toggle(card.id)
                view.haptic(Haptic.Tick)
            },
            if (on) "Take ${card.name} off the shortlist" else "Put ${card.name} back on the shortlist",
            Modifier.align(Alignment.TopEnd).padding(5.dp),
            size = 30.dp,
            fill = if (on) RiftColors.You else Color.Black.copy(alpha = 0.72f),
        ) {
            Image(if (on) CardIcons.StarFilled else CardIcons.Star, null, Modifier.size(16.dp), colorFilter = ColorFilter.tint(if (on) Color.Black else Color.White))
        }
    }
}
