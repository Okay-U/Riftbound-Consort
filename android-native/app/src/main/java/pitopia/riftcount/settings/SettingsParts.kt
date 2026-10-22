package pitopia.riftcount.settings

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import kotlin.math.abs
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.lineIcon
import pitopia.riftcount.ui.common.softBlur
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

/** Line icons of the SettingsHybrid mock (24 viewport, 2 stroke). */
object SettingsIcons {
    val Haptics = lineIcon("M5 8v8M19 8v8M9 5h6a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1z", 20.dp)
    val Sounds = lineIcon("M4 10v4h4l5 4V6l-5 4zM16 9a4 4 0 0 1 0 6M18.5 6.5a8 8 0 0 1 0 11", 20.dp)
    val Awake = lineIcon(
        "M12 3v2M12 19v2M5 12H3M21 12h-2M6.3 6.3L4.9 4.9M19.1 19.1l-1.4-1.4M6.3 17.7l-1.4 1.4M19.1 4.9l-1.4 1.4" +
            "M12 8a4 4 0 1 0 0 8a4 4 0 1 0 0-8z",
        20.dp,
    )
    val Shake = lineIcon("M7 3h10a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zM2 8l1 4-1 4M22 8l-1 4 1 4", 20.dp)
    val Black = lineIcon("M12 3a9 9 0 1 0 9 9 7 7 0 0 1-9-9z", 20.dp)
    val Colors = lineIcon(
        "M12 3a9 9 0 0 0 0 18c1.1 0 2-.9 2-2 0-.5-.2-1-.5-1.3-.3-.4-.5-.8-.5-1.2 0-1.1.9-2 2-2h2.4a4.6 4.6 0 0 0 4.6-4.6" +
            "C22 6.4 17.5 3 12 3zM7 12h.01M9 8h.01M14 7h.01M17 10h.01",
        20.dp,
    )
    val Match = lineIcon("M8 21h8M12 17v4M7 4h10v4a5 5 0 0 1-10 0zM17 5h3v2a3 3 0 0 1-3 3M7 5H4v2a3 3 0 0 0 3 3", 20.dp)
    val Tour = lineIcon("M12 3l2.2 5.5L20 9l-4.5 3.8L17 19l-5-3.3L7 19l1.5-6.2L4 9l5.8-.5z", 20.dp)
    val Trophy = lineIcon("M8 21h8M12 17v4M7 4h10v4a5 5 0 0 1-10 0z", 20.dp)
    val Book = lineIcon("M4 5a2 2 0 0 1 2-2h13v16H6a2 2 0 0 0-2 2zM4 21V5M8 7h7", 20.dp)
    val Heart = lineIcon("M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z", 20.dp)
    val Log = lineIcon("M5 4h14v16H5zM8 8h8M8 12h8M8 16h5", 20.dp)
    val Bug = lineIcon("M8 9h8v6a4 4 0 0 1-8 0zM12 9v10M9 5l1.5 2M15 5l-1.5 2M4 12h4M16 12h4M5 17l3-1M19 17l-3-1", 20.dp)
    val Wish = lineIcon("M9 18h6M10 21h4M12 3a6 6 0 0 0-3.5 10.9V16h7v-2.1A6 6 0 0 0 12 3z", 20.dp)
    val Share = lineIcon("M12 3v12M7 8l5-5 5 5M5 14v5h14v-5", 20.dp)
    val Star = lineIcon("M12 3l2.6 5.6 6.1.7-4.5 4.2 1.2 6L12 16.6 6.6 19.5l1.2-6L3.3 9.3l6.1-.7z", 20.dp)
    val Coffee = lineIcon("M4 9h13v5a5 5 0 0 1-5 5H9a5 5 0 0 1-5-5zM17 10h2a2 2 0 0 1 0 4h-2M8 3v3M12 3v3", 20.dp)
    val Shield = lineIcon("M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z", 20.dp)
    val Chevron = lineIcon("M9 18l6-6-6-6", 16.dp, 2.4f)
    val External = lineIcon("M7 17L17 7M8 7h9v9", 16.dp, 2.4f)
    val Back = lineIcon("M19 12H5M11 18l-6-6 6-6", 20.dp, 2.2f)
    val Check = lineIcon("M5 12l5 5 9-10", 18.dp, 3.2f)
    val Send = lineIcon("M22 2l-7 20-4-9-9-4zM22 2L11 13", 18.dp, 2.4f)
}

private val CaptionInk = Color.White.copy(alpha = 0.58f)
val RowTitle = RiftType.Body.copy(fontSize = 15.5.sp, lineHeight = 19.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
val RowSub = RiftType.Body.copy(fontSize = 12.5.sp, lineHeight = 17.5.sp, color = Color.White.copy(alpha = 0.6f))
val FootText = RiftType.Body.copy(fontSize = 12.5.sp, lineHeight = 18.75.sp, color = Color.White.copy(alpha = 0.55f))

/** "MOST USED", a section caption, with an optional aside on the right. */
@Composable
fun SectionHead(title: String, aside: String? = null) {
    Row(Modifier.fillMaxWidth().padding(start = 6.dp, end = 6.dp, bottom = 8.dp), horizontalArrangement = Arrangement.SpaceBetween) {
        BasicText(title.uppercase(), style = RiftType.Caption.copy(color = CaptionInk))
        aside?.let { BasicText(it.uppercase(), style = RiftType.Caption.copy(color = CaptionInk)) }
    }
}

/** The mock's `.group`: rows on a faint rounded panel. */
@Composable
fun Group(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    val shape = RoundedCornerShape(24.dp)
    Column(
        modifier.fillMaxWidth().clip(shape).background(Color.White.copy(alpha = 0.045f)).border(1.dp, Color.White.copy(alpha = 0.08f), shape),
        content = content,
    )
}

/** A row that opens something: a sub page (chevron) or an outside app ([external], arrow). */
@Composable
fun LinkRow(
    label: String,
    icon: ImageVector?,
    sub: String? = null,
    divider: Boolean = true,
    external: Boolean = false,
    trailing: @Composable () -> Unit = { Chevron(external) },
    onClick: () -> Unit,
) {
    val source = remember { MutableInteractionSource() }
    RowShell(label, icon, sub, divider, false, source, Modifier.clickable(source, null, role = Role.Button, onClick = onClick), trailing)
}

@Composable
fun ToggleRow(label: String, icon: ImageVector, sub: String?, on: Boolean, divider: Boolean = true, onChange: (Boolean) -> Unit) {
    val source = remember { MutableInteractionSource() }
    RowShell(label, icon, sub, divider, on, source, Modifier.toggleable(on, source, null, role = Role.Switch, onValueChange = onChange)) {
        Toggle(on)
    }
}

/** [modifier] carries the row's click or toggle; [source] its presses. */
@Composable
private fun RowShell(
    label: String,
    icon: ImageVector?,
    sub: String?,
    divider: Boolean,
    iconOn: Boolean,
    source: MutableInteractionSource,
    modifier: Modifier = Modifier,
    trailing: @Composable () -> Unit,
) {
    val pressed by source.collectIsPressedAsState()
    val press by animateFloatAsState(if (pressed) 0.04f else 0f, tween(200), label = "press")
    Row(
        Modifier.fillMaxWidth().heightIn(min = 64.dp)
            .drawBehind {
                if (press > 0f) drawRect(Color.White.copy(alpha = press))
                if (divider) drawRect(Color.White.copy(alpha = 0.06f), size = Size(size.width, 1.dp.toPx()))
            }
            .then(modifier)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        if (icon != null) RowIcon(icon, iconOn)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            BasicText(label, style = RowTitle)
            sub?.let { BasicText(it, style = RowSub) }
        }
        trailing()
    }
}

@Composable
private fun RowIcon(icon: ImageVector, on: Boolean) {
    val bg by animateColorAsState(if (on) RiftColors.You.copy(alpha = 0.16f) else Color.White.copy(alpha = 0.07f), tween(400), label = "iconBg")
    val ink by animateColorAsState(if (on) RiftColors.You else Color.White, tween(400), label = "iconInk")
    Box(Modifier.size(36.dp).background(bg, RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
        Image(icon, null, Modifier.size(19.dp), colorFilter = ColorFilter.tint(ink))
    }
}

@Composable
fun Chevron(external: Boolean = false) {
    Image(if (external) SettingsIcons.External else SettingsIcons.Chevron, null, colorFilter = ColorFilter.tint(Color.White.copy(alpha = 0.45f)))
}

/** The mock's `.tg` switch: green track with a glow and a black knob when on. */
@Composable
fun Toggle(on: Boolean) {
    val x = animateDpAsState(if (on) 22.dp else 0.dp, tween(520, easing = RiftEase), label = "knob")
    val track by animateColorAsState(if (on) RiftColors.You else Color.White.copy(alpha = 0.14f), tween(360), label = "track")
    val knob by animateColorAsState(if (on) Color.Black else Color.White, tween(300), label = "knobInk")
    val glow by animateFloatAsState(if (on) 0.45f else 0f, tween(500), label = "glow")
    val shape = RoundedCornerShape(16.dp)
    Box(Modifier.size(54.dp, 32.dp).dropShadow(shape, Shadow(16.dp, RiftColors.You.copy(alpha = glow))).background(track, shape)) {
        Box(Modifier.padding(3.dp).offset { IntOffset(x.value.roundToPx(), 0) }.size(26.dp).background(knob, CircleShape))
    }
}

private val TileShape = RoundedCornerShape(24.dp)
private val BackText = RiftType.Body.copy(fontSize = 12.5.sp, lineHeight = 1.4.em, color = Color.White.copy(alpha = 0.82f))

/**
 * A tile of "Most used" that turns over on its long axis to tell what it does. The front is [front];
 * the "i" stays on top of both faces like the mock. [darkInfo]: the "i" sits on a green face.
 */
@Composable
fun FlipTile(label: String, info: String, darkInfo: Boolean, modifier: Modifier = Modifier, front: @Composable BoxScope.() -> Unit) {
    var flipped by rememberSaveable(label) { mutableStateOf(false) }
    val rot by animateFloatAsState(if (flipped) 180f else 0f, tween(760, easing = RiftEase), label = "flip")
    val dark = darkInfo && !flipped
    val infoBg by animateColorAsState(if (dark) Color.Black.copy(alpha = 0.16f) else Color.White.copy(alpha = 0.12f), tween(300), label = "infoBg")
    val infoInk by animateColorAsState(if (dark) Color.Black else Color.White, tween(300), label = "infoInk")
    Box(modifier.height(88.dp)) {
        Box(Modifier.fillMaxSize().graphicsLayer { rotationX = rot; cameraDistance = 12.5f * density }) {
            if (rot < 90f) {
                front()
            } else {
                Box(
                    Modifier.fillMaxSize().graphicsLayer { rotationX = 180f }
                        .background(Color(0xFF161616), TileShape).border(1.dp, Color.White.copy(alpha = 0.14f), TileShape)
                        .clickable(remember { MutableInteractionSource() }, null, onClickLabel = "Back to $label") { flipped = false }
                        // The end keeps clear of the "i", which stays on this face too.
                        .padding(start = 14.dp, top = 12.dp, end = 34.dp),
                ) {
                    BasicText(info, style = BackText, autoSize = TextAutoSize.StepBased(10.sp, 12.5.sp, 0.25.sp))
                }
            }
        }
        // A 44dp touch area in the corner around the 26dp "i".
        Pressable(
            { flipped = !flipped },
            Modifier.align(Alignment.TopEnd).size(44.dp)
                .semantics { contentDescription = if (flipped) "Back to $label" else "What $label does" },
            pressedScale = 0.9f,
            contentAlignment = Alignment.TopEnd,
        ) {
            Box(Modifier.padding(top = 8.dp, end = 8.dp).size(26.dp).background(infoBg, CircleShape), contentAlignment = Alignment.Center) {
                BasicText("i", style = RiftType.Body.copy(fontSize = 13.sp, fontWeight = FontWeight.Bold, fontStyle = FontStyle.Italic, color = infoInk))
            }
        }
    }
}

/** Front of a switch tile: green and glowing when on, the state underneath the name. */
@Composable
fun BoxScope.SwitchFace(label: String, icon: ImageVector, on: Boolean, onToggle: () -> Unit) {
    val bg by animateColorAsState(if (on) RiftColors.You else Color.White.copy(alpha = 0.07f), tween(380), label = "tileBg")
    val ink by animateColorAsState(if (on) Color.Black else Color.White, tween(380), label = "tileInk")
    val glow by animateFloatAsState(if (on) 0.35f else 0f, tween(500), label = "tileGlow")
    val iconBg by animateColorAsState(if (on) Color.Black.copy(alpha = 0.14f) else Color.White.copy(alpha = 0.08f), tween(380), label = "tileIcon")
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    Row(
        Modifier.matchParentSize().dropShadow(TileShape, Shadow(24.dp, RiftColors.You.copy(alpha = glow)))
            .background(bg, TileShape)
            .background(if (pressed) Color.Black.copy(alpha = 0.08f) else Color.Transparent, TileShape)
            .toggleable(on, source, null, role = Role.Switch) { onToggle() }
            .padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.size(42.dp).background(iconBg, CircleShape), contentAlignment = Alignment.Center) {
            Image(icon, null, colorFilter = ColorFilter.tint(ink))
        }
        TileText(label, if (on) "On" else "Off", ink)
    }
}

/** Front of the Players tile: "2P" or "4P", the old number blurs away upwards as the new one rises. */
@Composable
fun BoxScope.PlayersFace(players: Int, onToggle: () -> Unit) {
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val state = if (players == 2) "Duel" else "Free-for-all"
    Row(
        Modifier.matchParentSize().background(Color.White.copy(alpha = 0.08f), TileShape)
            .background(if (pressed) Color.Black.copy(alpha = 0.08f) else Color.Transparent, TileShape)
            .clickable(source, null, role = Role.Button, onClickLabel = "Switch to ${if (players == 2) 4 else 2} players", onClick = onToggle)
            .semantics { stateDescription = "$players players, $state" }
            .padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        MorphNumber("${players}P", Modifier.size(52.dp, 42.dp).clearAndSetSemantics {})
        TileText("Players", state, Color.White)
    }
}

private val OutEase = CubicBezierEasing(0.4f, 0f, 0.2f, 1f)

@Composable
private fun MorphNumber(text: String, modifier: Modifier) {
    var shown by remember { mutableStateOf(text) }
    var old by remember { mutableStateOf<String?>(null) }
    val out = remember { Animatable(0f) }
    val into = remember { Animatable(1f) }
    LaunchedEffect(text) {
        if (text == shown) return@LaunchedEffect
        old = shown
        shown = text
        out.snapTo(0f)
        into.snapTo(0f)
        coroutineScope {
            launch { out.animateTo(1f, tween(420, easing = OutEase)) }
            launch { into.animateTo(1f, tween(620, easing = RiftEase)) }
        }
        old = null
    }
    val style = RiftType.Title.copy(fontSize = 32.sp, lineHeight = 32.sp, color = Color.White)
    Box(modifier, contentAlignment = Alignment.Center) {
        old?.let { BasicText(it, Modifier.blurShift { -out.value }, style = style) }
        BasicText(shown, Modifier.blurShift { 1f - into.value }, style = style)
    }
}

/** [off] 0 is in place, -1 / +1 gone: faded, blurred 8dp and 40% of its height up / down. */
private fun Modifier.blurShift(off: () -> Float) = graphicsLayer {
    val o = off()
    val a = abs(o)
    alpha = 1f - a
    translationY = size.height * 0.4f * o
    val b = 8.dp.toPx() * a
    renderEffect = softBlur(b)
}

@Composable
private fun TileText(label: String, state: String, ink: Color) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        BasicText(label, style = RiftType.Body.copy(fontSize = 14.5.sp, lineHeight = 16.7.sp, fontWeight = FontWeight.Bold, color = ink), maxLines = 2)
        BasicText(state, style = RiftType.Body.copy(fontSize = 12.sp, lineHeight = 14.sp, fontWeight = FontWeight.SemiBold, color = ink.copy(alpha = ink.alpha * 0.7f)))
    }
}
