package pitopia.riftcount.decks

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutLinearInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.util.lerp
import kotlin.math.cos
import kotlin.math.sin
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import pitopia.riftcount.cards.Card
import pitopia.riftcount.cards.CardFace
import pitopia.riftcount.cards.rememberCardArt
import pitopia.riftcount.data.Decklist
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.Sheet
import pitopia.riftcount.ui.common.ToastHost
import pitopia.riftcount.ui.common.Toaster
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

/** Test hand: four cards fly off the pile into a fan; tap up to two for the mulligan, draw one at a time. */
@Composable
fun HandSheet(deck: Decklist, index: Map<String, Card>, onDismiss: () -> Unit) {
    val toaster = remember { Toaster() }
    val scope = rememberCoroutineScope()
    var hand by remember { mutableStateOf(Hand.deal(deck)) }
    // New hand: the cards fly back onto the pile first, then four new ones come off it.
    var collecting by remember { mutableStateOf(false) }
    Sheet("Draw a test hand", onDismiss, overlay = { ToastHost(toaster) }) {
        BasicText("Test hand · ${deck.name}", style = SheetTitle)
        Row(Modifier.fillMaxWidth().padding(top = 2.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            val style = RiftType.Body.copy(fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.62f))
            BasicText(
                when {
                    hand.cards.isEmpty() -> "The main deck is empty"
                    hand.mulliganUsed -> "Mulligan used · ${hand.cards.size} cards"
                    hand.marked.isNotEmpty() -> "${hand.marked.size} marked for mulligan"
                    else -> "Tap up to 2 cards to mulligan"
                },
                style = style,
            )
            BasicText("${hand.pile.size} left in deck", style = style)
        }
        Fan(hand, index, collecting) { id ->
            val (next, note) = hand.toggle(id)
            hand = next
            note?.let(toaster::show)
        }
        Row(Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            WideButton("New hand", Modifier.weight(1f), enabled = !collecting) {
                scope.launch {
                    collecting = true
                    delay(COLLECT_MS + hand.cards.size * COLLECT_STAGGER_MS)
                    hand = Hand.deal(deck, firstId = hand.nextId)
                    collecting = false
                }
            }
            WideButton("Draw 1", Modifier.weight(1f), enabled = hand.canDraw && !collecting) { hand = hand.draw() }
            WideButton(
                if (hand.marked.isNotEmpty()) "Mulligan ${hand.marked.size}" else "Mulligan", Modifier.weight(1f),
                fill = RiftColors.Gold, ink = Color.Black, enabled = hand.canMulligan && !collecting,
            ) { hand = hand.mulligan() }
        }
    }
}

private const val COLLECT_MS = 380L
private const val COLLECT_STAGGER_MS = 45L

/** The mock's fan: cards on an arc of 300dp radius, up to 40° wide; a marked card lifts and glows amber. */
@Composable
private fun Fan(hand: Hand, index: Map<String, Card>, collecting: Boolean, onTap: (Int) -> Unit) {
    val density = LocalDensity.current
    BoxWithConstraints(Modifier.fillMaxWidth().padding(top = 6.dp).height(300.dp)) {
        val w = maxWidth
        // The pile, top right, the cards come from.
        Box(
            Modifier.align(Alignment.TopEnd).padding(top = 6.dp, end = 6.dp).size(56.dp, 78.dp)
                .background(Brush.linearGradient(listOf(Color(0xFF262626), Color(0xFF0C0C0C))), RoundedCornerShape(9.dp))
                .border(1.dp, Color.White.copy(alpha = 0.18f), RoundedCornerShape(9.dp)),
            contentAlignment = Alignment.Center,
        ) { BasicText("${hand.pile.size}", style = RiftType.Title.copy(fontSize = 20.sp, lineHeight = 20.sp, color = Color.White.copy(alpha = 0.75f))) }
        val n = hand.cards.size
        val spread = minOf(40f, 11f * (n - 1))
        var freshIndex = 0
        hand.cards.forEachIndexed { i, c ->
            key(c.id) {
                val angle = if (n <= 1) 0f else -spread / 2 + i * spread / (n - 1)
                val a by animateFloatAsState(angle, tween(700, easing = RiftEase), label = "fan")
                val lift by animateFloatAsState(if (c.id in hand.marked) 1f else 0f, tween(300, easing = RiftEase), label = "lift")
                val order = freshIndex++
                val fly = remember { Animatable(0f) }
                LaunchedEffect(Unit) {
                    delay(order * 90L)
                    fly.animateTo(1f, tween(700, easing = RiftEase))
                }
                // Back onto the pile, the last card first.
                LaunchedEffect(collecting) {
                    if (!collecting) return@LaunchedEffect
                    delay((n - 1 - i) * COLLECT_STAGGER_MS)
                    fly.animateTo(0f, tween(COLLECT_MS.toInt(), easing = FastOutLinearInEasing))
                }
                val card = index[c.cardId]
                val art by if (card != null) rememberCardArt(card, with(density) { 112.dp.roundToPx() }) else remember { mutableStateOf(null) }
                val marked = c.id in hand.marked
                val shape = RoundedCornerShape(12.dp)
                Pressable(
                    { onTap(c.id) },
                    Modifier.align(Alignment.TopStart).size(112.dp, 157.dp)
                        .graphicsLayer {
                            val v = fly.value
                            val rad = Math.toRadians(a.toDouble())
                            val r = 300.dp.toPx()
                            val baseX = (w.toPx() - 112.dp.toPx()) / 2
                            val fanX = baseX + sin(rad).toFloat() * r
                            val fanY = 96.dp.toPx() + (1f - cos(rad).toFloat()) * r - 28.dp.toPx() * lift
                            val pileX = w.toPx() - 112.dp.toPx() + 20.dp.toPx()
                            translationX = lerp(pileX, fanX, v)
                            translationY = lerp(-100.dp.toPx() + 96.dp.toPx(), fanY, v)
                            rotationZ = lerp(14f, a, v)
                            scaleX = lerp(0.5f, 1f, v)
                            scaleY = scaleX
                            transformOrigin = TransformOrigin(0.5f, 1.2f)
                        }
                        .let { m -> if (marked) m.dropShadow(shape, Shadow(radius = 18.dp, color = RiftColors.Gold.copy(alpha = 0.5f))) else m }
                        .semantics { contentDescription = (card?.name ?: "Card") + if (marked) ", marked for mulligan" else "" },
                    pressedScale = 0.97f,
                ) {
                    if (card != null) CardFace(card, false, art, Modifier.fillMaxSize().clip(shape)) else Box(Modifier.fillMaxSize().background(Color(0xFF1A1A1A), shape))
                    if (marked) Box(Modifier.fillMaxSize().border(2.dp, RiftColors.Gold, shape))
                }
            }
        }
    }
}

val SheetTitle = RiftType.Body.copy(fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color.White)
val SheetText = RiftType.Body.copy(fontSize = 13.sp, lineHeight = 19.sp, fontWeight = FontWeight.Normal, color = Color.White.copy(alpha = 0.7f))

/** The mock's `.btn`: 50dp pill, ghost, green or amber. */
@Composable
fun WideButton(
    text: String,
    modifier: Modifier = Modifier,
    fill: Color = Color.White.copy(alpha = 0.1f),
    ink: Color = Color.White,
    enabled: Boolean = true,
    glow: Boolean = fill == RiftColors.You,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(25.dp)
    Pressable(
        onClick,
        modifier.height(50.dp).graphicsLayer { alpha = if (enabled) 1f else 0.35f }
            .let { if (glow) it.dropShadow(shape, Shadow(radius = 20.dp, color = RiftColors.You.copy(alpha = 0.35f))) else it }
            .background(fill, shape),
        enabled = enabled,
        pressedScale = 0.96f,
    ) {
        BasicText(text, style = RiftType.Body.copy(fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = ink), maxLines = 1)
    }
}
