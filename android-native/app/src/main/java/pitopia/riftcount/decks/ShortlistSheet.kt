package pitopia.riftcount.decks

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Animatable
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.toSize
import kotlinx.coroutines.launch
import pitopia.riftcount.cards.AddToDeckSheet
import pitopia.riftcount.cards.Card
import pitopia.riftcount.cards.CardDetail
import pitopia.riftcount.cards.CardIcons
import pitopia.riftcount.cards.CloseEase
import pitopia.riftcount.data.DeckRules
import pitopia.riftcount.cards.ErrataStore
import pitopia.riftcount.cards.Shortlist
import pitopia.riftcount.data.DecklistStore
import pitopia.riftcount.platform.Haptic
import pitopia.riftcount.platform.haptic
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.RoundIcon
import pitopia.riftcount.ui.common.Sheet
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase

/**
 * The cards kept in mind, opened from the Decks table (Okay, 2026-10-22), grouped like a deck's gallery. The star
 * takes a card off; it stays until the sheet closes, dimmed, so a second tap puts it back. A tap on a card opens
 * it as the Cards tab does, with Add to deck (Okay, 2026-10-26).
 */
@Composable
fun ShortlistSheet(index: Map<String, Card>, errata: ErrataStore, decks: DecklistStore, onNewDeck: (Card) -> Unit, onDismiss: () -> Unit) {
    val shown = remember { Shortlist.ids.mapNotNull { index[it] } }
    val tilePx = LocalWindowInfo.current.containerSize.width / 3
    val scope = rememberCoroutineScope()
    var open by remember { mutableStateOf<Pair<Card, Rect>?>(null) }
    var detailShown by remember { mutableStateOf(false) }
    var adding by remember { mutableStateOf(false) }
    val hero = remember { Animatable(0f) }

    fun openCard(card: Card, from: Rect) {
        if (open != null) return
        open = card to from
        detailShown = true
        scope.launch {
            hero.snapTo(0f)
            hero.animateTo(1f, tween(680, easing = RiftEase))
        }
    }

    fun closeCard() {
        if (!detailShown) return
        detailShown = false
        adding = false
        scope.launch {
            hero.animateTo(0f, tween(540, easing = CloseEase))
            open = null
        }
    }

    Sheet("Shortlist", onDismiss, overlay = {
        BackHandler(enabled = detailShown) { closeCard() }
        open?.let { (card, from) ->
            CardDetail(
                card = card, from = from, progress = { hero.value }, shown = detailShown, tilePx = tilePx,
                erratum = errata.forCard(card), inDecks = decks.lists.count { DeckRules.count(card, it) > 0 },
                onClose = ::closeCard, onAdd = { adding = true },
            )
        }
    }) {
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
                    row.forEach { (card, _) -> KeptTile(card, tilePx, open?.first?.id == card.id, Modifier.weight(1f), ::openCard) }
                    repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
    }
    val opened = open
    if (adding && opened != null && detailShown) {
        AddToDeckSheet(opened.first, decks, index, onNewDeck = { onNewDeck(opened.first) }) { adding = false }
    }
}

/** [hidden] while the tile has flown into the detail. */
@Composable
private fun KeptTile(card: Card, tilePx: Int, hidden: Boolean, modifier: Modifier, onOpen: (Card, Rect) -> Unit) {
    val view = LocalView.current
    val on = Shortlist.has(card.id)
    val dim by animateFloatAsState(if (on) 1f else 0.4f, tween(300), label = "kept")
    val coords = remember { arrayOfNulls<LayoutCoordinates>(1) }
    Box(modifier.graphicsLayer { alpha = if (hidden) 0f else 1f }) {
        Pressable(
            // The whole tile, also when the sheet's edge cuts it.
            { coords[0]?.takeIf { it.isAttached }?.let { onOpen(card, Rect(it.positionInRoot(), it.size.toSize())) } },
            Modifier.fillMaxWidth().onGloballyPositioned { coords[0] = it }.graphicsLayer { alpha = dim },
            pressedScale = 0.96f,
            label = "Open ${card.name}",
        ) {
            CardTile(card, tilePx, Modifier.fillMaxWidth()) {}
        }
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
