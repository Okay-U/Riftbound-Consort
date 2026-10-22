package pitopia.riftcount.decks

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import pitopia.riftcount.cards.CARD_ASPECT
import pitopia.riftcount.cards.Card
import pitopia.riftcount.cards.CardFace
import pitopia.riftcount.cards.rememberCardArt
import pitopia.riftcount.data.DecklistEntry
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.RoundIcon
import pitopia.riftcount.ui.common.ScoreIcons
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftType

private const val COLUMNS = 3
private val TypeOrder = listOf("unit", "spell", "gear")

/**
 * Main or side as the Cards tab shows cards, in groups: Units · Spells · Gear, or one group per energy
 * (Okay, 2026-10-22). Within a group by energy, then name.
 */
fun galleryGroups(cards: List<Pair<Card, Int>>, byEnergy: Boolean): List<Pair<String, List<Pair<Card, Int>>>> {
    val sorted = cards.sortedWith(compareBy({ it.first.attributes?.energy ?: Int.MAX_VALUE }, { it.first.name.lowercase() }))
    return if (byEnergy) {
        sorted.groupBy { it.first.attributes?.energy }.toSortedMap(nullsLast<Int>()).map { (e, list) -> (e?.let { "$it energy" } ?: "No energy") to list }
    } else {
        sorted.groupBy { it.first.type.lowercase() }.entries
            .sortedWith(compareBy({ TypeOrder.indexOf(it.key).let { i -> if (i < 0) TypeOrder.size else i } }, { it.key }))
            .map { (type, list) -> typeLabel(type) to list }
    }
}

private fun typeLabel(type: String) = when (type) {
    "unit" -> "Units"
    "spell" -> "Spells"
    "gear" -> "Gear"
    "" -> "Other"
    else -> type.replaceFirstChar { it.titlecase() }
}

/** The deck detail's piles: group headers with their counts, then three cards to a row (or [list] rows), the copies on each. */
@Composable
fun PileGallery(entries: List<DecklistEntry>, index: Map<String, Card>, byEnergy: Boolean, championId: String?, list: Boolean, modifier: Modifier = Modifier) {
    // A card the list no longer knows still shows, as its name on a blank face.
    val cards = entries.map { (index[it.cardId] ?: Card(id = it.cardId, name = it.cardName)) to it.count }
    val tilePx = LocalWindowInfo.current.containerSize.width / COLUMNS
    Column(modifier.fillMaxWidth()) {
        galleryGroups(cards, byEnergy).forEach { (label, group) ->
            Row(Modifier.fillMaxWidth().padding(top = 16.dp, bottom = 8.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                GroupLabel(label)
                GroupLabel("${group.sumOf { it.second }}")
            }
            if (list) {
                group.forEach { (card, count) -> CardRow(DecklistEntry(card.id, card.name, count), index[card.id], card.id == championId) }
            } else group.chunked(COLUMNS).forEach { row ->
                Row(Modifier.fillMaxWidth().padding(bottom = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    row.forEach { (card, count) ->
                        CardTile(card, tilePx, Modifier.weight(1f)) {
                            CountBadge(count, filled = false)
                            if (card.id == championId) ChampTag()
                        }
                    }
                    repeat(COLUMNS - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
    }
}

/**
 * The builder's pool card: a tap adds a copy (or says why not), the minus takes one back. A card that
 * cannot go in any more dims.
 */
@Composable
fun PickTile(card: Card, count: Int, blocked: Boolean, tilePx: Int, onAdd: () -> Unit, onRemove: () -> Unit, modifier: Modifier = Modifier) {
    val dim by animateFloatAsState(if (blocked && count == 0) 0.45f else 1f, tween(300), label = "dim")
    Box(
        modifier.semantics {
            contentDescription = "${card.name}, $count in the deck"
            if (count > 0) customActions = listOf(CustomAccessibilityAction("Take one out") { onRemove(); true })
        },
    ) {
        Pressable(onAdd, Modifier.fillMaxWidth().graphicsLayer { alpha = dim }, label = "Add one", pressedScale = 0.95f) {
            CardTile(card, tilePx, Modifier.fillMaxWidth()) { if (count > 0) CountBadge(count, filled = true) }
        }
        if (count > 0) {
            RoundIcon(onRemove, "Take one out", Modifier.align(Alignment.TopStart).padding(5.dp), size = 30.dp, fill = Color.Black.copy(alpha = 0.72f)) {
                BasicText("−", style = RiftType.Body.copy(fontSize = 17.sp, fontWeight = FontWeight.Bold, color = Color.White))
            }
        }
    }
}

/** A battlefield in the builder: its art, ringed and ticked once it is one of the three. */
@Composable
fun FieldPick(card: Card, on: Boolean, tilePx: Int, onToggle: () -> Unit, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(10.dp)
    Pressable(
        onToggle,
        modifier.let { if (on) it.dropShadow(shape, Shadow(radius = 18.dp, color = RiftColors.You.copy(alpha = 0.5f))) else it }
            .semantics { contentDescription = card.name + if (on) ", chosen" else "" },
        label = if (on) "Remove the battlefield" else "Pick the battlefield",
        pressedScale = 0.95f,
    ) {
        CardTile(card, tilePx, Modifier.fillMaxWidth()) {
            if (on) {
                Box(Modifier.matchParentSize().border(2.dp, RiftColors.You, shape))
                Box(
                    Modifier.align(Alignment.TopEnd).padding(6.dp).size(26.dp).background(RiftColors.You, CircleShape),
                    contentAlignment = Alignment.Center,
                ) { Image(ScoreIcons.Check, null, Modifier.size(15.dp), colorFilter = ColorFilter.tint(Color.Black)) }
            }
        }
    }
}

/** One card in the Cards tab's frame, with whatever the caller lays over it. */
@Composable
private fun CardTile(card: Card, tilePx: Int, modifier: Modifier, over: @Composable BoxScope.() -> Unit) {
    val art by rememberCardArt(card, tilePx)
    Box(modifier.aspectRatio(CARD_ASPECT)) {
        CardFace(card, errata = false, art = art, modifier = Modifier.fillMaxSize())
        over()
    }
}

@Composable
private fun BoxScope.CountBadge(count: Int, filled: Boolean) {
    Box(
        Modifier.align(Alignment.TopEnd).padding(6.dp).size(26.dp)
            .background(if (filled) RiftColors.You else Color.Black.copy(alpha = 0.72f), CircleShape)
            .border(1.dp, if (filled) RiftColors.You else Color.White.copy(alpha = 0.3f), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        BasicText(
            "$count",
            style = RiftType.Body.copy(fontSize = 13.sp, fontWeight = FontWeight.Bold, fontFeatureSettings = "tnum", color = if (filled) Color.Black else Color.White),
        )
    }
}

@Composable
private fun BoxScope.ChampTag() {
    BasicText(
        "CHAMP",
        Modifier.align(Alignment.TopStart).padding(6.dp).background(RiftColors.You, RoundedCornerShape(5.dp)).padding(horizontal = 6.dp, vertical = 2.dp),
        style = RiftType.Caption.copy(fontSize = 9.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.1.em, color = Color.Black),
    )
}

@Composable
private fun GroupLabel(text: String) =
    BasicText(text.uppercase(), style = RiftType.Caption.copy(letterSpacing = 0.14.em, color = Color.White.copy(alpha = 0.62f)))
