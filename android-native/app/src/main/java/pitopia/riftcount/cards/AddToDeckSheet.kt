package pitopia.riftcount.cards

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import pitopia.riftcount.data.DeckRules
import pitopia.riftcount.data.DeckRules.Slot
import pitopia.riftcount.data.Decklist
import pitopia.riftcount.data.DecklistStore
import pitopia.riftcount.platform.Haptic
import pitopia.riftcount.platform.haptic
import pitopia.riftcount.ui.common.Pill
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.Sheet
import pitopia.riftcount.ui.common.Stepper
import pitopia.riftcount.ui.common.ToastHost
import pitopia.riftcount.ui.common.Toaster
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftType

/** Copies of [card] per deck with a stepper; decks it cannot join are greyed out with the reason. */
@Composable
fun AddToDeckSheet(card: Card, decks: DecklistStore, index: Map<String, Card>, onNewDeck: () -> Unit, onDismiss: () -> Unit) {
    val toaster = remember { Toaster() }
    val view = LocalView.current
    fun plus(deck: Decklist) {
        val next = DeckRules.add(card, deck, index, System.currentTimeMillis())
        decks.replace(next)
        view.haptic(Haptic.Tick)
        toaster.show("Added to ${deck.name} · ${DeckRules.count(card, next)} of ${maxCopies(card)}")
    }
    Sheet("Add to deck", onDismiss, overlay = { ToastHost(toaster) }) { close ->
        BasicText("Add ${card.title}", style = RiftType.Body.copy(fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color.White))
        BasicText(
            when {
                decks.lists.isEmpty() -> "No decks yet. Start one with this card."
                card.isLegend -> "A deck has one legend. Its domains decide which cards fit."
                else -> maxCopies(card).let { "Up to $it ${if (it == 1) "copy" else "copies"} per deck. Decks outside the card’s domains are greyed out." }
            },
            Modifier.padding(top = 4.dp, bottom = 14.dp),
            style = RiftType.Body.copy(fontSize = 13.sp, lineHeight = 19.sp, fontWeight = FontWeight.Normal, color = Color.White.copy(alpha = 0.72f)),
        )
        ShortlistRow(card) { on ->
            view.haptic(Haptic.Tick)
            toaster.show(if (on) "On your shortlist · find it in the builder" else "Off your shortlist")
        }
        decks.lists.forEach { deck ->
            DeckRow(card, deck, index, onPlus = { plus(deck) }, onMinus = {
                decks.replace(DeckRules.remove(card, deck, System.currentTimeMillis()))
                view.haptic(Haptic.Undo)
            })
        }
        // The mock's flow: the builder opens with this card (a legend starts it, any other card joins the main deck).
        // Battlefields and runes are picked on their own builder steps.
        if (card.isLegend || card.isChampion || DeckRules.eligible(card, emptySet())) {
            NewDeckButton {
                close()
                onNewDeck()
            }
        }
    }
}

/** Keeps the card in mind for a deck to come (the builder's Shortlist chip, the Cards filter). */
@Composable
private fun ShortlistRow(card: Card, onToggled: (Boolean) -> Unit) {
    val on = Shortlist.has(card.id)
    Row(
        Modifier.fillMaxWidth().padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier.size(44.dp).background(if (on) RiftColors.You else Color.White.copy(alpha = 0.08f), RoundedCornerShape(14.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Image(if (on) CardIcons.StarFilled else CardIcons.Star, null, colorFilter = ColorFilter.tint(if (on) Color.Black else Color.White))
        }
        Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
            BasicText("Shortlist", style = RiftType.Body.copy(fontSize = 15.sp, fontWeight = FontWeight.Bold, color = Color.White), maxLines = 1)
            BasicText(
                "Keep it in mind for a deck · ${Shortlist.ids.size} on it",
                style = RiftType.Body.copy(fontSize = 12.5.sp, lineHeight = 16.sp, color = Color.White.copy(alpha = 0.66f)),
            )
        }
        Pill(
            if (on) "Saved" else "Save", { onToggled(Shortlist.toggle(card.id)) }, Modifier.height(36.dp),
            fill = if (on) RiftColors.You else Color.White.copy(alpha = 0.12f), ink = if (on) Color.Black else Color.White,
        )
    }
}

/** Per-deck limit of this card: one legend or battlefield, twelve runes, three copies of anything else. */
private fun maxCopies(card: Card) = when {
    card.isLegend || card.isBattlefield -> 1
    card.isRune -> DeckRules.RUNES
    else -> DeckRules.COPY_LIMIT
}

@Composable
private fun DeckRow(card: Card, deck: Decklist, index: Map<String, Card>, onPlus: () -> Unit, onMinus: () -> Unit) {
    val count = DeckRules.count(card, deck)
    val legend = deck.legend?.let { index[it.cardId] }
    val domains = legend?.domains.orEmpty()
    val slot = DeckRules.slotFor(card, deck, index)
    val fits = slot != Slot.Main || DeckRules.eligible(card, DeckRules.legendDomains(deck, index))
    val blocker = DeckRules.blocker(card, deck, index)
    val sub = when {
        !fits -> listOf("Not in ${legend?.title ?: "the legend"}'s domains") + domains
        slot == Slot.Legend -> listOf(
            when {
                count > 0 -> "Legend of this deck"
                legend != null -> "Replaces ${legend.title} as legend"
                else -> "Becomes the legend"
            },
        )
        blocker != null -> listOf(blocker)
        slot == Slot.Champion -> listOf("Becomes the chosen champion")
        slot == Slot.Battlefield -> listOf("Adds to Battlefields", "${deck.battlefields.size} / ${DeckRules.BATTLEFIELDS}")
        slot == Slot.Rune -> listOf("Adds to Runes", "${deck.runes.sumOf { it.count }} / ${DeckRules.RUNES}")
        else -> listOf("Adds to Main deck", "${deck.mainDeck.sumOf { it.count }} / ${DeckRules.MAIN}")
    }.joinToString(" · ")
    val canAdd = fits && blocker == null && !(slot == Slot.Legend && count > 0)
    val off = !fits && count == 0
    Row(
        Modifier.fillMaxWidth().graphicsLayer { alpha = if (off) 0.42f else 1f }
            .drawBehind { drawRect(Color.White.copy(alpha = 0.08f), size = Size(size.width, 1.dp.toPx())) }
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val colors = domains.map(CardStyle::domainColor).ifEmpty { listOf(Color.White.copy(alpha = 0.5f), Color.White.copy(alpha = 0.25f)) }
        Box(
            Modifier.size(44.dp).background(Brush.linearGradient(if (colors.size == 1) colors + colors else colors), RoundedCornerShape(14.dp)),
            contentAlignment = Alignment.Center,
        ) {
            BasicText(
                (legend?.title ?: deck.name).take(1).uppercase(),
                style = RiftType.Title.copy(fontSize = 20.sp, lineHeight = 20.sp, color = Color.Black),
            )
        }
        Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
            BasicText(deck.name, style = RiftType.Body.copy(fontSize = 15.sp, fontWeight = FontWeight.Bold, color = Color.White), maxLines = 1)
            BasicText(sub, style = RiftType.Body.copy(fontSize = 12.5.sp, lineHeight = 16.sp, color = Color.White.copy(alpha = 0.66f)))
        }
        if (!off) {
            Stepper(count, onMinus, onPlus, "copy", plus = canAdd)
        }
    }
}

@Composable
private fun NewDeckButton(onClick: () -> Unit) {
    Pressable(
        onClick,
        Modifier.padding(top = 10.dp).fillMaxWidth().height(50.dp).drawBehind {
            val w = 1.dp.toPx()
            drawRoundRect(
                Color.White.copy(alpha = 0.3f), cornerRadius = CornerRadius(size.height / 2),
                style = Stroke(w, pathEffect = PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 4.dp.toPx()))),
            )
        },
        pressedScale = 0.97f,
    ) {
        BasicText("+ New deck with this card", style = RiftType.Body.copy(fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Color.White))
    }
}
