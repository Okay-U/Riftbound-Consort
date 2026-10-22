package pitopia.riftcount.cards

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.EnterExitState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.animateDp
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.BlurredEdgeTreatment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import pitopia.riftcount.data.DeckRules
import pitopia.riftcount.data.DeckRules.Slot
import pitopia.riftcount.data.Decklist
import pitopia.riftcount.data.DecklistStore
import pitopia.riftcount.platform.Haptic
import pitopia.riftcount.platform.haptic
import pitopia.riftcount.ui.common.Pill
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.Sheet
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

private class SheetToast(val id: Int, val text: String)

/** Copies of [card] per deck with a stepper; decks it cannot join are greyed out with the reason. */
@Composable
fun AddToDeckSheet(card: Card, decks: DecklistStore, index: Map<String, Card>, onDismiss: () -> Unit) {
    var toast by remember { mutableStateOf<SheetToast?>(null) }
    var naming by remember { mutableStateOf(false) }
    val view = LocalView.current
    fun say(text: String) {
        toast = SheetToast((toast?.id ?: 0) + 1, text)
    }
    fun plus(deck: Decklist) {
        val next = DeckRules.add(card, deck, index, System.currentTimeMillis())
        decks.replace(next)
        view.haptic(Haptic.Tick)
        say("Added to ${deck.name} · ${DeckRules.count(card, next)} of ${maxCopies(card)}")
    }
    Sheet(
        "Add to deck", onDismiss,
        overlay = { toast?.let { t -> DeckToast(t) { if (toast?.id == t.id) toast = null } } },
    ) {
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
        decks.lists.forEach { deck ->
            DeckRow(card, deck, index, onPlus = { plus(deck) }, onMinus = {
                decks.replace(DeckRules.remove(card, deck, System.currentTimeMillis()))
                view.haptic(Haptic.Undo)
            })
        }
        if (naming) {
            NewDeckField { name ->
                plus(decks.create(name))
                naming = false
            }
        } else {
            NewDeckButton { naming = true }
        }
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
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                StepButton("−", "Remove one copy from ${deck.name}", count > 0, onMinus)
                StepCount(count, maxCopies(card))
                StepButton("+", "Add one copy to ${deck.name}", canAdd, onPlus)
            }
        }
    }
}

@Composable
private fun StepButton(text: String, label: String, enabled: Boolean, onClick: () -> Unit) {
    Pressable(
        onClick,
        Modifier.size(38.dp).semantics { contentDescription = label }.graphicsLayer { alpha = if (enabled) 1f else 0.3f }
            .background(Color.White.copy(alpha = 0.06f), CircleShape).border(1.dp, Color.White.copy(alpha = 0.18f), CircleShape),
        enabled = enabled,
        pressedScale = 0.9f,
    ) {
        BasicText(text, style = RiftType.Body.copy(fontSize = 18.sp, fontWeight = FontWeight.SemiBold, color = Color.White))
    }
}

private val StepOut = CubicBezierEasing(0.4f, 0f, 0.2f, 1f)

/** The count morphs like the scoreboard's numbers: old one blurs up and out, new one rises in. */
@Composable
private fun StepCount(count: Int, max: Int) {
    val style = TextStyle(fontFamily = RiftType.Display, fontWeight = FontWeight.Black, fontSize = 24.sp, lineHeight = 24.sp, color = Color.White, textAlign = TextAlign.Center)
    AnimatedContent(
        targetState = count,
        modifier = Modifier.size(30.dp, 38.dp).semantics { contentDescription = "$count of $max copies" },
        transitionSpec = {
            (fadeIn(tween(620, easing = RiftEase)) + slideInVertically(tween(620, easing = RiftEase)) { (it * 0.4f).toInt() })
                .togetherWith(fadeOut(tween(420, easing = StepOut)) + slideOutVertically(tween(420, easing = StepOut)) { -(it * 0.4f).toInt() })
        },
        contentAlignment = Alignment.Center,
        label = "copies",
    ) { n ->
        val blur by transition.animateDp(label = "blur") { if (it == EnterExitState.Visible) 0.dp else 8.dp }
        Box(Modifier.size(30.dp, 38.dp), contentAlignment = Alignment.Center) {
            BasicText("$n", Modifier.blur(blur, BlurredEdgeTreatment.Unbounded), style = style)
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

/** iOS asks for the new deck's name in the sheet; the card goes in as its first card. */
@Composable
private fun NewDeckField(onCreate: (String) -> Unit) {
    var name by remember { mutableStateOf("") }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { focus.requestFocus() }
    val ok = name.isNotBlank()
    val shape = RoundedCornerShape(25.dp)
    Row(Modifier.padding(top = 10.dp).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        BasicTextField(
            value = name,
            onValueChange = { name = it.take(40) },
            modifier = Modifier.weight(1f).height(50.dp).focusRequester(focus)
                .background(Color.White.copy(alpha = 0.07f), shape).border(1.dp, RiftColors.You.copy(alpha = 0.6f), shape)
                .semantics { contentDescription = "Deck name" },
            textStyle = RiftType.Body.copy(fontSize = 16.sp, color = Color.White),
            singleLine = true,
            cursorBrush = SolidColor(RiftColors.You),
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { if (ok) onCreate(name.trim()) }),
            decorationBox = { field ->
                Box(Modifier.padding(horizontal = 18.dp), contentAlignment = Alignment.CenterStart) {
                    if (name.isEmpty()) BasicText("Deck name", style = RiftType.Body.copy(fontSize = 16.sp, color = Color.White.copy(alpha = 0.5f)))
                    field()
                }
            },
        )
        Spacer(Modifier.width(8.dp))
        Pill(
            "Create", { onCreate(name.trim()) }, Modifier.height(50.dp), enabled = ok, fill = RiftColors.You, ink = Color.Black,
            style = RiftType.Body.copy(fontSize = 15.sp, fontWeight = FontWeight.Bold),
        )
    }
}

/** "Added to Void Tempo · 2 of 3" at the top, over the scrim. */
@Composable
private fun BoxScope.DeckToast(toast: SheetToast, onDone: () -> Unit) {
    val t = remember(toast.id) { Animatable(0f) }
    LaunchedEffect(toast.id) {
        t.animateTo(1f, tween(520, easing = RiftEase))
        delay(1700)
        t.animateTo(0f, tween(260))
        onDone()
    }
    val shape = RoundedCornerShape(50)
    BasicText(
        toast.text,
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
