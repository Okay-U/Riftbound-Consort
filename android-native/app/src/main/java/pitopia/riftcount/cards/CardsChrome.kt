package pitopia.riftcount.cards

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import kotlin.math.roundToInt
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.RoundIcon
import pitopia.riftcount.ui.common.lineIcon
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

/** Line icons of the Cards mock. */
object CardIcons {
    val Search = lineIcon("M4 11a7 7 0 1 0 14 0a7 7 0 1 0 -14 0M20 20l-3.5-3.5", 18.dp, 2.2f)
    val Filter = lineIcon("M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12M14 6a2 2 0 1 0 4 0a2 2 0 1 0 -4 0M8 12a2 2 0 1 0 4 0a2 2 0 1 0 -4 0M16 18a2 2 0 1 0 4 0a2 2 0 1 0 -4 0", 18.dp)
    val Back = lineIcon("M19 12H5M11 18l-6-6 6-6", 20.dp, 2.2f)
    val Plus = lineIcon("M12 5v14M5 12h14", 18.dp, 2.6f)
}

@Composable
fun CardsHeader(count: Int?) {
    Row(
        Modifier.fillMaxWidth().statusBarsPadding().padding(start = 20.dp, end = 20.dp, top = 6.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Bottom,
    ) {
        BasicText("Cards", style = RiftType.Title.copy(color = Color.White))
        if (count != null) BasicText(
            (if (count == 1) "1 card" else "$count cards").uppercase(),
            Modifier.padding(bottom = 6.dp),
            style = RiftType.Caption.copy(fontSize = 12.sp, letterSpacing = 0.14.em, color = Color.White.copy(alpha = 0.7f), fontFeatureSettings = "tnum"),
        )
    }
}

@Composable
fun SearchField(value: String, onChange: (String) -> Unit) {
    val focus = LocalFocusManager.current
    val source = remember { MutableInteractionSource() }
    val focused by source.collectIsFocusedAsState()
    val ring by animateFloatAsState(if (focused) 1f else 0f, tween(300), label = "focus")
    val shape = RoundedCornerShape(25.dp)
    BasicTextField(
        value = value,
        onValueChange = onChange,
        modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 16.dp).fillMaxWidth().height(50.dp)
            .drawBehind {
                val grow = 4.dp.toPx()
                drawRoundRect(
                    RiftColors.You.copy(alpha = 0.12f * ring), Offset(-grow, -grow), Size(size.width + grow * 2, size.height + grow * 2),
                    CornerRadius(size.height / 2 + grow),
                )
            }
            .background(Color.White.copy(alpha = 0.07f), shape)
            .border(1.dp, lerp(Color.White.copy(alpha = 0.12f), RiftColors.You.copy(alpha = 0.6f), ring), shape)
            .semantics { contentDescription = "Search cards by name" },
        textStyle = RiftType.Body.copy(fontSize = 16.sp, color = Color.White),
        singleLine = true,
        cursorBrush = SolidColor(RiftColors.You),
        keyboardOptions = KeyboardOptions(autoCorrectEnabled = false, imeAction = ImeAction.Search),
        keyboardActions = KeyboardActions(onSearch = { focus.clearFocus() }),
        interactionSource = source,
        decorationBox = { field ->
            Row(Modifier.fillMaxSize().padding(start = 18.dp, end = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Image(CardIcons.Search, null, colorFilter = ColorFilter.tint(Color.White.copy(alpha = 0.7f)))
                Spacer(Modifier.width(10.dp))
                Box(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
                    if (value.isEmpty()) BasicText("Search cards", style = RiftType.Body.copy(fontSize = 16.sp, color = Color.White.copy(alpha = 0.5f)))
                    field()
                }
                if (value.isNotEmpty()) {
                    RoundIcon({ onChange("") }, "Clear search", size = 34.dp) {
                        BasicText("×", style = RiftType.Body.copy(fontSize = 18.sp, color = Color.White))
                    }
                }
            }
        },
    )
}

/** "All" plus the six domains as glowing discs; several domains can be on at once. */
@Composable
fun RuneRow(selected: Set<String>, onAll: () -> Unit, onToggle: (String) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(start = 12.dp, end = 12.dp, top = 16.dp), horizontalArrangement = Arrangement.SpaceBetween) {
        RuneButton("All", selected.isEmpty(), Color.White, null, onAll)
        CardFilters.domainsInOrder.forEach { d -> RuneButton(d, d in selected, CardStyle.domainColor(d), CardStyle.glyph(d)) { onToggle(d) } }
    }
}

@Composable
private fun RowScope.RuneButton(label: String, on: Boolean, color: Color, glyph: Int?, onClick: () -> Unit) {
    val t by animateFloatAsState(if (on) 1f else 0f, tween(350), label = "rune")
    Pressable(
        onClick,
        Modifier.weight(1f).semantics {
            selected = on
            contentDescription = if (glyph == null) "All domains" else "Domain $label"
        },
        pressedScale = 0.9f,
        role = Role.Checkbox,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Box(
                Modifier.size(44.dp)
                    .dropShadow(CircleShape, Shadow(radius = 22.dp, color = color.copy(alpha = 0.6f * t)))
                    .background(lerp(Color.White.copy(alpha = 0.04f), color, t), CircleShape)
                    .border(1.dp, lerp(Color.White.copy(alpha = 0.18f), color, t), CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                val ink = lerp(color, Color.Black, t)
                if (glyph == null) {
                    BasicText("All", style = RiftType.Title.copy(fontSize = 13.sp, lineHeight = 13.sp, fontWeight = FontWeight.ExtraBold, letterSpacing = 0.08.em, color = ink))
                } else {
                    Image(painterResource(glyph), null, Modifier.size(22.dp), colorFilter = ColorFilter.tint(ink))
                }
            }
            Spacer(Modifier.height(6.dp))
            BasicText(
                label.uppercase(),
                style = RiftType.Caption.copy(fontSize = 10.sp, letterSpacing = 0.12.em, color = lerp(Color.White.copy(alpha = 0.62f), Color.White, t)),
                maxLines = 1, softWrap = false,
            )
        }
    }
}

/** Sort switch (Set · Energy · Type) and the Filter button with its count of active filters. */
@Composable
fun CardControls(sort: CardSort, onSort: (CardSort) -> Unit, active: Int, onFilter: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.weight(1f).padding(end = 10.dp)) { SortSwitch(sort, onSort) }
        val shape = RoundedCornerShape(20.dp)
        Pressable(
            onFilter,
            Modifier.height(40.dp).background(Color.White.copy(alpha = 0.06f), shape).border(1.dp, Color.White.copy(alpha = 0.14f), shape)
                .padding(start = 12.dp, end = 14.dp)
                .semantics { contentDescription = if (active > 0) "Filter, $active active" else "Filter" },
            pressedScale = 0.95f,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Image(CardIcons.Filter, null, colorFilter = ColorFilter.tint(Color.White))
                Spacer(Modifier.width(8.dp))
                BasicText("Filter", style = RiftType.Body.copy(fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color.White))
                AnimatedVisibility(active > 0, enter = scaleIn(tween(420, easing = RiftEase), initialScale = 0.6f) + fadeIn(tween(420)), exit = fadeOut(tween(150))) {
                    BasicText(
                        "$active",
                        Modifier.padding(start = 8.dp).defaultMinSize(20.dp, 20.dp).background(RiftColors.You, RoundedCornerShape(10.dp)).padding(horizontal = 6.dp, vertical = 2.dp),
                        style = RiftType.Body.copy(fontSize = 11.sp, lineHeight = 16.sp, fontWeight = FontWeight.Bold, color = Color.Black, textAlign = TextAlign.Center),
                    )
                }
            }
        }
    }
}

/** 230dp like the mock, narrower when a small phone has less room. */
@Composable
private fun SortSwitch(sort: CardSort, onSort: (CardSort) -> Unit) {
    val x by animateFloatAsState(sort.ordinal.toFloat(), tween(520, easing = RiftEase), label = "sort")
    val shape = RoundedCornerShape(20.dp)
    BoxWithConstraints(
        Modifier.widthIn(max = 230.dp).fillMaxWidth().height(40.dp)
            .background(Color.White.copy(alpha = 0.07f), shape).border(1.dp, Color.White.copy(alpha = 0.1f), shape).padding(3.dp),
    ) {
        val thumb = maxWidth / CardSort.entries.size
        Box(
            Modifier.offset { IntOffset((x * thumb.toPx()).roundToInt(), 0) }.size(thumb, 32.dp)
                .background(Color.White, RoundedCornerShape(16.dp)),
        )
        Row(Modifier.fillMaxSize()) {
            CardSort.entries.forEach { s ->
                val on = s == sort
                val ink by animateColorAsState(if (on) Color.Black else Color.White.copy(alpha = 0.78f), tween(300), label = "ink")
                Box(
                    Modifier.weight(1f).fillMaxHeight().selectable(on, remember { MutableInteractionSource() }, null, role = Role.Tab) { onSort(s) },
                    contentAlignment = Alignment.Center,
                ) {
                    BasicText(s.label, style = RiftType.Body.copy(fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = ink))
                }
            }
        }
    }
}
