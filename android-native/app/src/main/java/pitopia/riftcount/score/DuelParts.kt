package pitopia.riftcount.score

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.EnterExitState
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateDp
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.wrapContentSize
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import kotlin.math.PI
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.sin
import pitopia.riftcount.ui.common.Pill
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

private fun polygon(n: Int, r: Float, cx: Float, cy: Float): List<Offset> =
    List(n) { i -> val a = ((-90 + i * 360.0 / n) * PI / 180).toFloat(); Offset(cx + r * cos(a), cy + r * sin(a)) }

private fun List<Offset>.closedPath() = Path().apply { moveTo(first().x, first().y); drop(1).forEach { lineTo(it.x, it.y) }; close() }

/** Die outlines of the mock on a 200 viewport: D20 hexagon with its facets, D6 rounded square. */
private class DieShapes(type: DieType) {
    val body: Path
    val facets: Path

    init {
        if (type == DieType.D20) {
            val hex = polygon(6, 92f, 100f, 100f)
            val tri = polygon(3, 56f, 100f, 106f)
            body = hex.closedPath()
            facets = tri.closedPath().apply { tri.forEachIndexed { i, p -> moveTo(p.x, p.y); lineTo(hex[i * 2].x, hex[i * 2].y) } }
        } else {
            body = PathParser().parsePathString("M58 22 H142 Q178 22 178 58 V142 Q178 178 142 178 H58 Q22 178 22 142 V58 Q22 22 58 22 Z").toPath()
            facets = PathParser().parsePathString("M46 46 L154 46 L154 154 L46 154 Z").toPath()
        }
    }
}

@Composable
fun DieGraphic(type: DieType, die: Die, accent: Color, highlight: Boolean, sizeDp: Float = 190f) {
    val shapes = remember(type) { DieShapes(type) }
    val rolled = die.value != null
    val spinTarget = if (die.rolling || !rolled) die.rolls * 48f else ceil(die.rolls * 48f / 360f) * 360f + 360f
    val spin by animateFloatAsState(spinTarget, tween(if (die.rolling) 160 else 900, easing = if (die.rolling) LinearEasing else RiftEase), label = "spin")
    val ring = remember { Animatable(1f) }
    LaunchedEffect(rolled && !die.rolling) { if (rolled && !die.rolling) { ring.snapTo(0f); ring.animateTo(1f, tween(1100, easing = RiftEase)) } }
    val numberSize = (sizeDp * 0.43f).sp
    Box(Modifier.size(sizeDp.dp), contentAlignment = Alignment.Center) {
        Box(
            Modifier.size((sizeDp * 0.9f).dp)
                .graphicsLayer { val p = ring.value; scaleX = 0.4f + 1.8f * p; scaleY = 0.4f + 1.8f * p; alpha = 0.5f * (1f - p) }
                .border(2.dp, accent, CircleShape),
        )
        Canvas(Modifier.fillMaxSize().graphicsLayer { rotationZ = spin }) {
            scale(size.width / 200f, pivot = Offset.Zero) {
                drawPath(shapes.body, if (rolled) accent.copy(alpha = 0.12f) else Color.White.copy(alpha = 0.03f))
                drawPath(shapes.body, accent, style = Stroke(width = 3f, join = StrokeJoin.Round))
                drawPath(shapes.facets, accent.copy(alpha = 0.35f), style = Stroke(width = 1.5f, join = StrokeJoin.Round))
            }
        }
        val fast = die.rolling && die.rolls < 9
        AnimatedContent(
            targetState = die.value,
            transitionSpec = {
                val inMs = if (fast) 160 else 640
                val outMs = if (fast) 130 else 380
                (fadeIn(tween(inMs, easing = RiftEase)) + slideInVertically(tween(inMs, easing = RiftEase)) { (it * 0.14f).toInt() })
                    .togetherWith(fadeOut(tween(outMs)) + slideOutVertically(tween(outMs)) { -(it * 0.14f).toInt() })
                    // Not clipped to the number's box: the blur and the slide reach past it.
                    .using(SizeTransform(clip = false))
            },
            contentAlignment = Alignment.Center,
            label = "die",
        ) { v ->
            val blur by transition.animateDp(label = "dieBlur") { if (it == EnterExitState.Visible) 0.dp else 10.dp }
            BasicText(
                v?.toString() ?: "?",
                // The blur only draws inside its own layer: room around the digits, or it ends in a box.
                Modifier.wrapContentSize(unbounded = true).blur(blur, BlurredEdgeTreatment.Unbounded).padding(24.dp),
                style = TextStyle(
                    fontFamily = RiftType.Display, fontWeight = FontWeight.Black, fontSize = numberSize, lineHeight = numberSize,
                    fontFeatureSettings = "tnum", color = if (v == null) Color.White.copy(alpha = 0.35f) else if (highlight) accent else Color.White,
                ),
            )
        }
    }
}

/** One player's side during "who goes first": tap the half to roll. */
@Composable
fun DuelHalf(
    name: String,
    type: DieType,
    die: Die,
    accent: Color,
    ink: Color,
    hint: String?,
    head: String?,
    headInk: Color,
    choosing: Boolean,
    highlight: Boolean,
    onRoll: () -> Unit,
    onFirst: () -> Unit,
    onSecond: () -> Unit,
    modifier: Modifier = Modifier,
    dieSize: Float = 190f,
) {
    Pressable(onRoll, modifier.fillMaxSize(), pressedScale = 0.98f, label = "$name, tap to roll") {
        // On a short half (a 360 × 800 phone) the die gives way, so the first / second pills keep their height:
        // 150dp is the name, the verdict, the pills and the gaps between them.
        BoxWithConstraints {
            val fitted = minOf(dieSize, maxHeight.value - 150f).coerceAtLeast(96f)
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                BasicText(name.uppercase(), style = TextStyle(fontFamily = RiftType.Text, fontWeight = FontWeight.SemiBold, fontSize = 11.sp, letterSpacing = 0.16.em, color = Color.White.copy(alpha = 0.78f)))
                Spacer(Modifier.height(14.dp))
                DieGraphic(type, die, accent, highlight, fitted)
                if (hint != null) {
                    Spacer(Modifier.height(16.dp))
                    BasicText(hint, style = RiftType.Body.copy(fontWeight = FontWeight.SemiBold, fontSize = 14.sp, color = Color.White.copy(alpha = 0.72f)))
                }
                if (head != null) {
                    Spacer(Modifier.height(12.dp))
                    SoftIn(durationMs = 900) {
                        BasicText(head, style = TextStyle(fontFamily = RiftType.Display, fontWeight = FontWeight.Black, fontSize = 32.sp, lineHeight = 32.sp, letterSpacing = 0.06.em, color = headInk))
                    }
                }
                if (choosing) {
                    Spacer(Modifier.height(14.dp))
                    SoftIn(Modifier.fillMaxWidth(), delayMs = 200) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Pill("I go first", onFirst, Modifier.weight(1f).height(54.dp), fill = accent, ink = ink, style = RiftType.Body.copy(fontWeight = FontWeight.Bold, fontSize = 15.sp))
                            Pill(
                                "I go second", onSecond, Modifier.weight(1f).height(54.dp), fill = Color.Black.copy(alpha = 0.4f),
                                border = androidx.compose.foundation.BorderStroke(1.dp, Color.White.copy(alpha = 0.2f)),
                                style = RiftType.Body.copy(fontWeight = FontWeight.Bold, fontSize = 15.sp),
                            )
                        }
                    }
                }
            }
        }
    }
}

/** "Darius starts": the duel's verdict across the seam, with Roll again / Start the game. */
@Composable
fun DuelBanner(title: String, text: String, accent: Color, ink: Color, onAgain: () -> Unit, onStart: () -> Unit, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(26.dp)
    val t = remember { Animatable(0f) }
    LaunchedEffect(Unit) { t.animateTo(1f, tween(520, easing = RiftEase)) }
    Column(
        modifier
            .graphicsLayer { alpha = t.value; scaleX = 0.95f + 0.05f * t.value; scaleY = 0.95f + 0.05f * t.value }
            .background(Color(0xF80C0C0C), shape).border(1.dp, Color.White.copy(alpha = 0.16f), shape).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        BasicText(title, style = TextStyle(fontFamily = RiftType.Display, fontWeight = FontWeight.Black, fontSize = 28.sp, lineHeight = 28.sp, letterSpacing = 0.04.em, color = accent))
        BasicText(text, style = RiftType.Body.copy(fontSize = 13.sp, lineHeight = 19.sp, color = Color.White.copy(alpha = 0.72f)))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Pill("Roll again", onAgain, Modifier.weight(1f).height(46.dp))
            Pill("Start the game", onStart, Modifier.weight(1f).height(46.dp), fill = accent, ink = ink)
        }
    }
}

@Composable
fun DieTypeSwitch(type: DieType, enabled: Boolean, onPick: (DieType) -> Unit) {
    val x by animateFloatAsState(if (type == DieType.D20) 0f else 49f, tween(500, easing = RiftEase), label = "dieSwitch")
    Box(Modifier.size(104.dp, 42.dp).background(Color.White.copy(alpha = 0.07f), RoundedCornerShape(21.dp)).padding(3.dp)) {
        Box(Modifier.size(49.dp, 36.dp).graphicsLayer { translationX = x.dp.toPx() }.background(Color.White, RoundedCornerShape(18.dp)))
        Row(Modifier.fillMaxSize()) {
            DieType.entries.forEach { t ->
                Pressable({ onPick(t) }, Modifier.weight(1f).fillMaxSize(), enabled = enabled, label = t.label) {
                    BasicText(
                        t.label,
                        style = TextStyle(fontFamily = RiftType.Display, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp, letterSpacing = 0.06.em, color = if (t == type) Color.Black else Color.White.copy(alpha = 0.8f)),
                    )
                }
            }
        }
    }
}
