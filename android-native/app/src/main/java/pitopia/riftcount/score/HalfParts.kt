package pitopia.riftcount.score

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.EnterExitState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.animateDp
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.BlurredEdgeTreatment
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import pitopia.riftcount.ui.common.Pill
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

private val Standard = CubicBezierEasing(0.4f, 0f, 0.2f, 1f)
private val Caps = TextStyle(fontFamily = RiftType.Text, fontWeight = FontWeight.SemiBold, fontSize = 11.sp, letterSpacing = 0.14.em)

@Composable
fun TopLine(
    legend: String,
    accent: Color,
    ink: Color,
    starter: Boolean,
    xp: Int,
    onXp: (Int) -> Unit,
    gamesWon: Int,
    seriesPips: Boolean,
    shown: Boolean = true,
    onName: (() -> Unit)? = null,
) {
    // Fades out once the game is decided, like the mock's `.ended .topline`.
    val alpha by animateFloatAsState(if (shown) 1f else 0f, tween(500), label = "topline")
    Row(Modifier.fillMaxWidth().graphicsLayer { this.alpha = alpha }, horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
        Row(Modifier.weight(1f, fill = false), verticalAlignment = Alignment.CenterVertically) {
            val name = @Composable { BasicText(legend.uppercase(), style = Caps.copy(color = Color.White.copy(alpha = 0.78f)), maxLines = 1) }
            // The name opens the game setup (deck, opponent), like iOS's deck pill.
            if (onName != null) Pressable(onName, Modifier.padding(vertical = 6.dp), label = "Change $legend", pressedScale = 0.96f) { name() } else name()
            if (starter) {
                Spacer(Modifier.width(8.dp))
                BasicText(
                    "GOES FIRST",
                    Modifier.background(accent, RoundedCornerShape(10.dp)).padding(horizontal = 8.dp, vertical = 3.dp),
                    style = Caps.copy(fontWeight = FontWeight.Bold, fontSize = 9.5.sp, letterSpacing = 0.1.em, color = ink),
                )
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            BasicText("XP $xp", style = RiftType.Body.copy(fontWeight = FontWeight.SemiBold, fontSize = 12.sp, color = Color.White.copy(alpha = 0.84f)))
            Spacer(Modifier.width(5.dp))
            XpButton("−", "Spend one XP", shown) { onXp(-1) }
            Spacer(Modifier.width(5.dp))
            XpButton("+", "Gain one XP", shown) { onXp(1) }
            if (seriesPips) {
                Spacer(Modifier.width(12.dp))
                repeat(GAMES_TO_WIN) { i ->
                    if (i > 0) Spacer(Modifier.width(6.dp))
                    Box(Modifier.size(8.dp).background(if (i < gamesWon) accent else Color.White.copy(alpha = 0.2f), CircleShape))
                }
            }
        }
    }
}

@Composable
private fun XpButton(text: String, label: String, enabled: Boolean, onClick: () -> Unit) {
    Pressable(
        onClick,
        Modifier.size(30.dp).background(Color.Black.copy(alpha = 0.35f), CircleShape).border(1.dp, Color.White.copy(alpha = 0.24f), CircleShape),
        enabled = enabled,
        label = label,
    ) {
        BasicText(text, style = RiftType.Body.copy(fontWeight = FontWeight.SemiBold, fontSize = 15.sp, color = Color.White))
    }
}

/** The big number: the old value blurs up and away, the new one rises in, a drop of colour spreads. */
@Composable
fun ScoreNumber(value: Int, accent: Color, won: Boolean, label: String, modifier: Modifier = Modifier, showTarget: Boolean = true, sizeDp: Float = 188f) {
    val numberSize = with(LocalDensity.current) { sizeDp.dp.toSp() }
    val style = TextStyle(
        fontFamily = RiftType.Display, fontWeight = FontWeight.Black, fontSize = numberSize, lineHeight = numberSize,
        fontFeatureSettings = "tnum", color = Color.White, textAlign = TextAlign.Center,
    )
    val lift by animateFloatAsState(if (won) 1f else 0f, tween(1100, easing = RiftEase), label = "won")
    Box(
        modifier
            .size((sizeDp * 1.38f).dp, (sizeDp * 1.04f).dp)
            .graphicsLayer { translationY = 60.dp.toPx() * lift; scaleX = 1f - 0.32f * lift; scaleY = 1f - 0.32f * lift }
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Drop(value, accent, (sizeDp * 0.8f))
        AnimatedContent(
            targetState = value,
            transitionSpec = {
                (fadeIn(tween(950, easing = RiftEase)) + slideInVertically(tween(950, easing = RiftEase)) { (it * 0.24f).toInt() } +
                    scaleIn(tween(950, easing = RiftEase), initialScale = 1.05f))
                    .togetherWith(
                        fadeOut(tween(650, easing = Standard)) + slideOutVertically(tween(650, easing = Standard)) { -(it * 0.26f).toInt() } +
                            scaleOut(tween(650, easing = Standard), targetScale = 0.92f),
                    )
            },
            contentAlignment = Alignment.Center,
            label = "score",
        ) { v ->
            val blur by transition.animateDp(transitionSpec = { tween(if (targetState == EnterExitState.Visible) 950 else 650) }, label = "blur") {
                when (it) {
                    EnterExitState.PreEnter -> 16.dp
                    EnterExitState.Visible -> 0.dp
                    EnterExitState.PostExit -> 14.dp
                }
            }
            BasicText(v.toString(), Modifier.blur(blur, BlurredEdgeTreatment.Unbounded), style = style)
        }
        if (showTarget) {
            BasicText(
                "OF $TARGET",
                Modifier.align(Alignment.BottomCenter).offset(y = 10.dp),
                style = Caps.copy(fontWeight = FontWeight.Normal, fontSize = 12.sp, letterSpacing = 0.2.em, color = Color.White.copy(alpha = 0.7f)),
            )
        }
    }
}

@Composable
private fun Drop(value: Int, accent: Color, sizeDp: Float) {
    val t = remember { Animatable(1f) }
    val first = remember { booleanArrayOf(true) }
    LaunchedEffect(value) {
        if (first[0]) { first[0] = false; return@LaunchedEffect }
        t.snapTo(0f)
        t.animateTo(1f, tween(1200, easing = RiftEase))
    }
    Box(
        Modifier
            .size(sizeDp.dp)
            .graphicsLayer { val p = t.value; scaleX = 0.3f + 2.3f * p; scaleY = 0.3f + 2.3f * p; alpha = 0.4f * (1f - p) }
            .background(accent, CircleShape),
    )
}

@Composable
fun ActionRow(accent: Color, ink: Color, onConquer: () -> Unit, onHold: () -> Unit, onEffect: () -> Unit, onFix: () -> Unit, height: Float = 54f) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        ActionButton("Conquer", "+1", "Conquer, plus one point", Modifier.weight(1f), height, accent, ink, onConquer)
        ActionButton("Hold", "+1", "Hold, plus one point", Modifier.weight(1f), height, null, Color.White, onHold)
        ActionButton("Effect", "+1", "Card effect, plus one point", Modifier.weight(1f), height, null, Color.White, onEffect)
        ActionButton("Fix", "−1", "Correct, minus one point", Modifier.weight(1f), height, null, Color.White, onFix)
    }
}

/** Four players: the same four actions as a 2×2 grid, so the labels fit a quarter of the table. */
@Composable
fun ActionGrid(accent: Color, ink: Color, onConquer: () -> Unit, onHold: () -> Unit, onEffect: () -> Unit, onFix: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            ActionButton("Conquer", "+1", "Conquer, plus one point", Modifier.weight(1f), 40f, accent, ink, onConquer)
            ActionButton("Hold", "+1", "Hold, plus one point", Modifier.weight(1f), 40f, null, Color.White, onHold)
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            ActionButton("Effect", "+1", "Card effect, plus one point", Modifier.weight(1f), 40f, null, Color.White, onEffect)
            ActionButton("Fix", "−1", "Correct, minus one point", Modifier.weight(1f), 40f, null, Color.White, onFix)
        }
    }
}

@Composable
private fun ActionButton(title: String, delta: String, label: String, modifier: Modifier, height: Float, accent: Color?, ink: Color, onClick: () -> Unit) {
    val shape = RoundedCornerShape(50)
    val base = modifier.height(height.dp)
    val styled = if (accent != null) {
        base.dropShadow(shape, Shadow(radius = 26.dp, color = accent.copy(alpha = 0.45f))).background(accent, shape)
    } else {
        base.background(Color.Black.copy(alpha = 0.38f), shape).border(1.dp, Color.White.copy(alpha = 0.2f), shape)
    }
    Pressable(onClick, styled, label = label) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            BasicText(title, style = RiftType.Body.copy(fontWeight = FontWeight.SemiBold, fontSize = 13.sp, lineHeight = 15.sp, color = ink))
            BasicText(
                delta,
                style = RiftType.Body.copy(fontWeight = FontWeight.Medium, fontSize = 10.sp, lineHeight = 12.sp, color = ink.copy(alpha = if (accent != null) 0.62f else 0.66f)),
            )
        }
    }
}

/** "Game 2 · Series 1–0" over the winner's half, softly in after the line has swept. */
@Composable
fun ResultText(title: String, sub: String, accent: Color, modifier: Modifier = Modifier) {
    SoftIn(modifier, delayMs = 250, durationMs = 1300) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            BasicText(title, style = TextStyle(fontFamily = RiftType.Display, fontWeight = FontWeight.Black, fontSize = 52.sp, lineHeight = 52.sp, letterSpacing = 0.16.em, color = accent))
            Spacer(Modifier.height(6.dp))
            BasicText(sub, style = RiftType.Body.copy(fontSize = 13.sp, color = Color.White.copy(alpha = 0.82f)))
        }
    }
}

@Composable
fun FinalPointSheet(accent: Color, ink: Color, onYes: () -> Unit, onNo: () -> Unit, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(24.dp)
    Rise(modifier) {
        Column(Modifier.fillMaxWidth().background(Color(0xF50E0E0E), shape).border(1.dp, Color.White.copy(alpha = 0.14f), shape).padding(18.dp)) {
            BasicText("Final point by conquering", style = RiftType.Body.copy(fontWeight = FontWeight.Bold, fontSize = 16.sp, color = Color.White))
            Spacer(Modifier.height(6.dp))
            BasicText(
                "It only counts if you already scored every other battlefield this turn. Otherwise you draw a card instead.",
                style = RiftType.Body.copy(fontSize = 13.sp, lineHeight = 19.sp, color = Color.White.copy(alpha = 0.8f)),
            )
            Spacer(Modifier.height(14.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Pill("Yes, score it", onYes, Modifier.weight(1f).height(46.dp), fill = accent, ink = ink)
                Pill("No, draw a card", onNo, Modifier.weight(1f).height(46.dp))
            }
        }
    }
}

@Composable
fun HalfToast(text: String, modifier: Modifier = Modifier) {
    Rise(modifier) {
        BasicText(
            text,
            Modifier
                .background(Color(0xF50E0E0E), RoundedCornerShape(50))
                .border(BorderStroke(1.dp, Color.White.copy(alpha = 0.18f)), RoundedCornerShape(50))
                .padding(horizontal = 16.dp, vertical = 10.dp),
            style = RiftType.Body.copy(fontSize = 13.sp, color = Color.White),
        )
    }
}

/** The mocks' "soft" entrance: up from 18dp, from blur 10dp to sharp. */
@Composable
fun SoftIn(modifier: Modifier = Modifier, delayMs: Int = 0, durationMs: Int = 900, content: @Composable () -> Unit) {
    val t = remember { Animatable(0f) }
    LaunchedEffect(Unit) { t.animateTo(1f, tween(durationMs, delayMs, RiftEase)) }
    Box(modifier.graphicsLayer { alpha = t.value; translationY = 18.dp.toPx() * (1f - t.value) }.blur((10 * (1f - t.value)).dp, BlurredEdgeTreatment.Unbounded)) {
        content()
    }
}

/** Sheets and toasts rise 24dp into place. */
@Composable
fun Rise(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    val t = remember { Animatable(0f) }
    LaunchedEffect(Unit) { t.animateTo(1f, tween(650, easing = RiftEase)) }
    Box(modifier.graphicsLayer { alpha = t.value; translationY = 24.dp.toPx() * (1f - t.value) }) { content() }
}

@Composable
fun NextGameButton(text: String, accent: Color, ink: Color, onClick: () -> Unit) {
    SoftIn(Modifier.fillMaxWidth(), delayMs = 600, durationMs = 1000) {
        Pill(
            text, onClick, Modifier.fillMaxWidth().height(54.dp), fill = accent, ink = ink,
            style = RiftType.Body.copy(fontWeight = FontWeight.Bold, fontSize = 15.sp),
        )
    }
}
