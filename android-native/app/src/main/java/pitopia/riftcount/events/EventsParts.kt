package pitopia.riftcount.events

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.layout.layout
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import java.text.DateFormat
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Currency
import java.util.Date
import java.util.Locale
import kotlin.math.abs
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.lineIcon
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftType

/** Colours and type of the EventsMix mock. */
object Ev {
    val Card = Color(0xFF0D0D0D)
    val Ring = Color.White.copy(alpha = 0.08f)
    val Green = RiftColors.You
    val Violet = RiftColors.Opponent
    val Gold = RiftColors.Gold
    val Red = RiftColors.Danger
    val Caption = RiftType.Caption.copy(color = Color.White.copy(alpha = 0.55f))
    val Label = RiftType.Caption.copy(letterSpacing = 0.14.em, color = Color.White.copy(alpha = 0.58f))
    val Muted = RiftType.Body.copy(fontSize = 12.5.sp, lineHeight = 17.sp, color = Color.White.copy(alpha = 0.6f))
    val Msg = RiftType.Body.copy(fontSize = 14.sp, lineHeight = 21.sp, color = Color.White.copy(alpha = 0.66f), textAlign = TextAlign.Center)
    val Display = RiftType.Title
}

/** A filled and outlined shape on a 24 viewport, white (tint it with a ColorFilter): the mock's filled hearts. */
private fun solidIcon(pathData: String, size: Dp) =
    ImageVector.Builder(defaultWidth = size, defaultHeight = size, viewportWidth = 24f, viewportHeight = 24f)
        .addPath(
            addPathNodes(pathData), fill = SolidColor(Color.White), stroke = SolidColor(Color.White), strokeLineWidth = 2f,
            strokeLineCap = StrokeCap.Round, strokeLineJoin = StrokeJoin.Round,
        )
        .build()

object EvIcons {
    private const val HEART = "M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z"
    val HeartFilled = solidIcon(HEART, 13.dp)
    val Search = lineIcon("M11 4a7 7 0 1 0 0 14a7 7 0 1 0 0-14zM20 20l-3.5-3.5", 18.dp, 2.2f)
    val Heart = lineIcon(HEART, 13.dp)
    val Pin = lineIcon("M12 21s7-6.2 7-11a7 7 0 0 0-14 0c0 4.8 7 11 7 11z", 13.dp)
    val Back = lineIcon("M19 12H5M11 18l-6-6 6-6", 20.dp, 2.2f)
    val ChevronLeft = lineIcon("M15 18l-6-6 6-6", 20.dp, 2.2f)
    val ChevronRight = lineIcon("M9 18l6-6-6-6", 20.dp, 2.2f)
    val Lock = lineIcon("M6 11h12v10H6zM8 11V8a4 4 0 0 1 8 0v3", 13.dp, 2.4f)
    val Reload = lineIcon("M21 12a9 9 0 1 1-3-6.7M21 4v5h-5", 18.dp, 2.2f)
    val Check = lineIcon("M5 12l5 5 9-10", 16.dp, 2.8f)
    val Crown = lineIcon("M3 18h18M4 18L3 8l5 4 4-7 4 7 5-4-1 10", 28.dp)
    val Medal = lineIcon("M12 15a6 6 0 1 0 0-12 6 6 0 0 0 0 12zM8.2 13.9L7 21l5-3 5 3-1.2-7.1", 28.dp)
}

/** The mock's `.sech`: spaced capitals with an aside on the right. */
@Composable
fun Caption(left: String, right: String? = null, top: Dp = 22.dp, aside: (@Composable () -> Unit)? = null) {
    Row(Modifier.fillMaxWidth().padding(start = 4.dp, end = 4.dp, top = top, bottom = 10.dp), verticalAlignment = Alignment.CenterVertically) {
        BasicText(left.uppercase(), Modifier.weight(1f), style = Ev.Caption)
        right?.let { BasicText(it.uppercase(), style = Ev.Caption) }
        aside?.invoke()
    }
}

/** Lets a scrolling row run under the page's side padding to the screen edges (the mock's negative margins). */
fun Modifier.bleed(by: Dp) = layout { measurable, constraints ->
    val extra = by.roundToPx()
    val wide = constraints.maxWidth + 2 * extra
    val placeable = measurable.measure(constraints.copy(minWidth = wide, maxWidth = wide))
    layout(constraints.maxWidth, placeable.height) { placeable.place(-extra, 0) }
}

private val CardShape = RoundedCornerShape(22.dp)

/** `.card`: a dark rounded panel with a hairline ring. */
@Composable
fun EvCard(modifier: Modifier = Modifier, glow: Boolean = false, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier.fillMaxWidth()
            .let { if (glow) it.dropShadow(CardShape, Shadow(30.dp, Ev.Green.copy(alpha = 0.12f))) else it }
            .background(Ev.Card, CardShape)
            .border(1.dp, if (glow) Ev.Green.copy(alpha = 0.5f) else Ev.Ring, CardShape)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        content = content,
    )
}

@Composable
fun CardLabel(text: String, color: Color = Color.White.copy(alpha = 0.58f)) = BasicText(text.uppercase(), style = Ev.Label.copy(color = color))

/** `.epill` and `.spill`: a small capsule. */
@Composable
fun EvPill(text: String, bg: Color = Color.White.copy(alpha = 0.08f), ink: Color = Color.White, height: Int = 22) {
    Box(Modifier.height(height.dp).background(bg, RoundedCornerShape(50)).padding(horizontal = 8.dp), contentAlignment = Alignment.Center) {
        BasicText(text, style = RiftType.Body.copy(fontSize = 10.5.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.04.em, color = ink), maxLines = 1)
    }
}

/** `.mini`: YOU / DROPPED / PLAYING tags inside rows. */
@Composable
fun MiniPill(text: String, bg: Color, ink: Color) {
    Box(Modifier.height(18.dp).background(bg, RoundedCornerShape(9.dp)).padding(horizontal = 6.dp), contentAlignment = Alignment.Center) {
        BasicText(text, style = RiftType.Body.copy(fontSize = 9.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.08.em, color = ink), maxLines = 1)
    }
}

enum class BtnKind { Green, Ghost, Danger, DangerSoft }

/** `.btn`: 50dp capsule; green glows. */
@Composable
fun EvButton(text: String, kind: BtnKind, modifier: Modifier = Modifier, enabled: Boolean = true, onClick: () -> Unit) {
    val shape = RoundedCornerShape(25.dp)
    val (bg, ink) = when (kind) {
        BtnKind.Green -> Ev.Green to Color.Black
        BtnKind.Ghost -> Color.White.copy(alpha = 0.1f) to Color.White
        BtnKind.Danger -> Ev.Red to Color.Black
        BtnKind.DangerSoft -> Ev.Red.copy(alpha = 0.14f) to Ev.Red
    }
    Pressable(
        onClick,
        modifier.height(50.dp)
            .let { if (kind == BtnKind.Green && enabled) it.dropShadow(shape, Shadow(20.dp, Ev.Green.copy(alpha = 0.35f))) else it }
            .background(bg.copy(alpha = bg.alpha * if (enabled) 1f else 0.4f), shape),
        enabled = enabled,
        pressedScale = 0.96f,
    ) {
        BasicText(text, style = RiftType.Body.copy(fontSize = 14.sp, fontWeight = FontWeight.Bold, color = ink.copy(alpha = if (enabled) 1f else 0.5f)), maxLines = 1)
    }
}

/** `.chip` / `.rchip`: filter and round chips; on = green with a glow. */
@Composable
fun EvChip(text: String, on: Boolean, modifier: Modifier = Modifier, enabled: Boolean = true, display: Boolean = false, onClick: () -> Unit) {
    val shape = RoundedCornerShape(17.dp)
    val bg by animateColorAsState(if (on) Ev.Green else Color.White.copy(alpha = 0.04f), tween(260), label = "chipBg")
    val ink by animateColorAsState(if (on) Color.Black else Color.White, tween(260), label = "chipInk")
    val style = if (display) RiftType.Title.copy(fontSize = 13.sp, lineHeight = 13.sp, letterSpacing = 0.06.em, fontWeight = FontWeight.ExtraBold)
    else RiftType.Body.copy(fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold)
    Pressable(
        onClick,
        modifier.height(34.dp)
            .let { if (on) it.dropShadow(shape, Shadow(14.dp, Ev.Green.copy(alpha = 0.4f))) else it }
            .background(bg, shape).border(1.dp, if (on) Ev.Green else Color.White.copy(alpha = 0.16f), shape)
            .padding(horizontal = 12.dp),
        enabled = enabled,
    ) {
        BasicText(text, style = style.copy(color = ink.copy(alpha = if (enabled) 1f else 0.3f)), maxLines = 1)
    }
}

/** `.dbadge`: day, month and time of an event. */
@Composable
fun DateBadge(startsAt: Long?) {
    Column(
        Modifier.width(60.dp).background(Color.White.copy(alpha = 0.06f), RoundedCornerShape(16.dp)).padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (startsAt == null) {
            BasicText("TBD", style = RiftType.Body.copy(fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.6f)))
        } else {
            BasicText(Fmt.day(startsAt), style = Ev.Display.copy(fontSize = 30.sp, lineHeight = 30.sp, color = Color.White))
            BasicText(Fmt.month(startsAt), style = RiftType.Body.copy(fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.14.em, color = Color.White))
            BasicText(Fmt.time(startsAt), Modifier.padding(top = 3.dp), style = RiftType.Body.copy(fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.6f)))
        }
    }
}

private val TileShape = RoundedCornerShape(22.dp)

/** `.ecard`: a pressable list card with a left badge. */
@Composable
fun EvRowCard(onClick: () -> Unit, modifier: Modifier = Modifier, label: String? = null, content: @Composable RowScope.() -> Unit) {
    Pressable(onClick, modifier.fillMaxWidth(), pressedScale = 0.98f, label = label, contentAlignment = Alignment.TopStart) {
        Row(
            Modifier.fillMaxWidth().background(Ev.Card, TileShape).border(1.dp, Ev.Ring, TileShape).padding(12.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            content = content,
        )
    }
}

/** Name, format line, pills and store line of an event card. */
@Composable
fun RowScope.EventInfo(name: String, fmt: String?, storeLine: String?, favoriteStore: Boolean, pills: @Composable RowScope.() -> Unit = {}) {
    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        BasicText(name, style = RiftType.Body.copy(fontSize = 15.5.sp, lineHeight = 18.6.sp, fontWeight = FontWeight.Bold, color = Color.White), maxLines = 2, overflow = TextOverflow.Ellipsis)
        fmt?.let { BasicText(it, style = Ev.Muted, maxLines = 1, overflow = TextOverflow.Ellipsis) }
        Row(Modifier.padding(top = 2.dp), horizontalArrangement = Arrangement.spacedBy(6.dp), content = pills)
        storeLine?.let {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Image(if (favoriteStore) EvIcons.HeartFilled else EvIcons.Pin, null, colorFilter = ColorFilter.tint(if (favoriteStore) Ev.Green else Color.White.copy(alpha = 0.7f)))
                BasicText(it, style = RiftType.Body.copy(fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.7f)), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

/** The status pill of an event for the signed-in player. */
@Composable
fun StatusPill(state: PlayerState, live: Boolean) {
    when (state) {
        PlayerState.Registered, PlayerState.Active -> EvPill(if (live) "Playing" else "Registered", Ev.Green.copy(alpha = 0.16f), Ev.Green)
        PlayerState.Waitlisted -> EvPill("Waitlisted", Ev.Gold.copy(alpha = 0.16f), Ev.Gold)
        PlayerState.Dropped -> EvPill("Dropped", Color.White.copy(alpha = 0.1f), Color.White.copy(alpha = 0.7f))
        PlayerState.Eliminated -> EvPill("Eliminated", Color.White.copy(alpha = 0.1f), Color.White.copy(alpha = 0.7f))
        PlayerState.None -> Unit
    }
}

/** `.empty`: a message with an action, for signed-out, failed and empty lists. */
@Composable
fun EmptyState(title: String, text: String, button: String?, onClick: () -> Unit = {}) {
    Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 40.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        BasicText(title, style = Ev.Display.copy(fontSize = 26.sp, lineHeight = 28.sp, color = Color.White, textAlign = TextAlign.Center))
        BasicText(text, Modifier.padding(top = 8.dp, bottom = 18.dp), style = Ev.Msg)
        button?.let { EvButton(it, BtnKind.Green, Modifier.fillMaxWidth(), onClick = onClick) }
    }
}

/** `.spin`: the mock's ring spinner (the one animation allowed to loop while something loads). */
@Composable
fun Spinner(modifier: Modifier = Modifier, size: Int = 36) {
    val turn by rememberInfiniteTransition(label = "spin").animateFloat(0f, 360f, infiniteRepeatable(tween(900, easing = LinearEasing), RepeatMode.Restart), label = "turn")
    Canvas(modifier.size(size.dp)) {
        val w = 3.dp.toPx()
        drawCircle(Color.White.copy(alpha = 0.12f), radius = this.size.minDimension / 2 - w / 2, style = Stroke(w))
        drawArc(Ev.Green, turn, 90f, false, topLeft = Offset(w / 2, w / 2), size = Size(this.size.width - w, this.size.height - w), style = Stroke(w, cap = StrokeCap.Round))
    }
}

/** Display strings, iOS `PlayRiftboundFormat` and the cards' formatters. */
object Fmt {
    private fun f(pattern: String) = SimpleDateFormat(pattern, Locale.getDefault())

    fun day(ms: Long) = f("d").format(Date(ms))
    fun month(ms: Long) = f("MMM").format(Date(ms)).uppercase().trimEnd('.')
    fun time(ms: Long): String = DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(ms))
    fun weekday(ms: Long) = f("EEE").format(Date(ms)).trimEnd('.')
    /** "Tue 21 Oct 2026 · 18:30". */
    fun whenLine(ms: Long) = "${weekday(ms)} ${f("d MMM yyyy").format(Date(ms))} · ${time(ms)}"
    /** "21 Oct". */
    fun shortDate(ms: Long) = f("d MMM").format(Date(ms))
    /** "October 2026". */
    fun monthYear(ms: Long) = f("LLLL yyyy").format(Date(ms)).replaceFirstChar { it.titlecase() }

    /** `ONE_V_ONE` → "1v1", `BEST_OF_THREE` → "Best Of Three" (iOS). */
    fun humanize(raw: String): String = when (raw.uppercase()) {
        "ONE_V_ONE", "1V1" -> "1v1"
        "TWO_V_TWO", "2V2" -> "2v2"
        // The site's own labels (its event finder).
        "LIMITED_SEALED" -> "Sealed"
        "LIMITED_DRAFT" -> "Draft"
        else -> raw.replace('_', ' ').lowercase().split(' ').joinToString(" ") { w -> w.replaceFirstChar { it.titlecase(Locale.getDefault()) } }
    }

    fun price(fee: EntryFee?, pricing: String?): String {
        val minor = fee?.minorUnits ?: 0
        if (fee != null && minor > 0) {
            val nf = NumberFormat.getCurrencyInstance()
            runCatching { nf.currency = Currency.getInstance(fee.currency) }
            nf.minimumFractionDigits = if (minor % 100 == 0) 0 else 2
            return nf.format(minor / 100.0)
        }
        return pricing?.let(::humanize) ?: "Free"
    }

    fun players(count: Int, cap: Int?) = if (cap != null && cap > 0) "$count/$cap" else "$count"

    fun formatLine(vararg parts: String?): String? = parts.filterNotNull().map(::humanize).takeIf { it.isNotEmpty() }?.joinToString(" • ")

    fun storeLine(o: Organizer?, distanceMeters: Double? = null): String? {
        o ?: return null
        return listOfNotNull(o.name, o.physicalAddress?.city, distanceMeters?.let { "%.0f km".format(it / 1000) }).joinToString(" • ")
    }

    fun ordinal(n: Int): String {
        val suffix = when {
            n % 100 in 11..13 -> "th"
            n % 10 == 1 -> "st"
            n % 10 == 2 -> "nd"
            n % 10 == 3 -> "rd"
            else -> "th"
        }
        return "$n$suffix"
    }

    fun clock(seconds: Int): String {
        val a = abs(seconds)
        return "%02d:%02d".format(a / 60, a % 60)
    }

    fun pct(v: Double?): String = v?.let { "%.1f%%".format(if (it <= 1) it * 100 else it) } ?: "–"
}
