package pitopia.riftcount.decks

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridScope
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import pitopia.riftcount.cards.Card
import pitopia.riftcount.cards.SearchField
import pitopia.riftcount.cards.Shortlist
import pitopia.riftcount.data.DeckRules
import pitopia.riftcount.ui.common.LinkButton
import pitopia.riftcount.ui.common.softBlur
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

/**
 * The builder: seven stops on a light rail, a page per stop sliding sideways, Back and Next at the bottom.
 * [onToast] reports what a pick did; [onSave] gets the finished draft.
 */
@Composable
fun BuilderView(ui: DecksUi, shown: Boolean, pool: List<Card>, index: Map<String, Card>, onToast: (String) -> Unit, onSave: (Draft) -> Unit, onClose: () -> Unit) {
    val d = ui.draft ?: return
    val slide = remember { Animatable(1f) }
    LaunchedEffect(shown) { slide.animateTo(if (shown) 0f else 1f, tween(640, easing = RiftEase)) }
    val step = ui.step
    val champions = remember(d.legend, pool) { Builder.champions(d.legend, pool) }
    val issues = remember(d) { DeckRules.issues(Builder.toDeck(d, pool, 0), index) }
    val done = listOf(d.legend != null, d.champion != null, d.battlefields.size == DeckRules.BATTLEFIELDS, d.mainCount == DeckRules.MAIN, true, d.runeCount == DeckRules.RUNES, false)
    fun reachable(i: Int) = i <= step.ordinal || (0 until i).all { j -> done[j] || j >= 3 }
    Column(
        Modifier.fillMaxSize().graphicsLayer { translationY = size.height * slide.value }.background(RiftColors.Page)
            .clickable(remember { MutableInteractionSource() }, indication = null) {}.statusBarsPadding().navigationBarsPadding().imePadding(),
    ) {
        Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 18.dp), verticalAlignment = Alignment.CenterVertically) {
            PanelIcon(DeckIcons.Close, "Close the builder", onClose)
            BasicText(
                "${if (d.editing != null) "EDIT DECK" else "NEW DECK"} · STEP ${step.ordinal + 1} OF 7",
                Modifier.weight(1f).wrapContentWidth(Alignment.CenterHorizontally),
                style = RiftType.Caption.copy(fontSize = 11.5.sp, letterSpacing = 0.16.em, color = Color.White.copy(alpha = 0.66f)),
            )
            Spacer(Modifier.width(42.dp))
        }
        Rail(step, done, ::reachable) { ui.step = it }
        TitleLine(step.title, step)
        Box(Modifier.weight(1f).fillMaxWidth()) {
            AnimatedContent(
                targetState = step,
                transitionSpec = {
                    val dir = if (targetState.ordinal > initialState.ordinal) 1 else -1
                    (slideInHorizontally(tween(620, easing = RiftEase)) { it * dir } + fadeIn(tween(520)))
                        .togetherWith(slideOutHorizontally(tween(620, easing = RiftEase)) { -it * dir } + fadeOut(tween(520)))
                },
                label = "page",
            ) { s ->
                when (s) {
                    BuildStep.Legend -> LegendPage(d, pool) { legend -> ui.pickLegend(legend)?.let(onToast) }
                    BuildStep.Champion -> ChampionPage(d, champions) { ui.update(Builder.pickChampion(d, it)) }
                    BuildStep.Fields -> FieldsPage(d, pool, onToast) { ui.update(it) }
                    BuildStep.Main -> PoolPage(d, Pile.Main, pool, index, onToast) { ui.update(it) }
                    BuildStep.Side -> PoolPage(d, Pile.Side, pool, index, onToast) { ui.update(it) }
                    BuildStep.Runes -> RunesPage(d) { ui.update(it) }
                    BuildStep.Save -> SavePage(d, issues) { ui.update(d.copy(name = it.take(40))) }
                }
            }
        }
        Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = 22.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            WideButton("Back", Modifier.weight(1f), enabled = step.ordinal > 0) { ui.step = BuildStep.entries[step.ordinal - 1] }
            val noChampions = step == BuildStep.Champion && champions.isEmpty()
            val label = when {
                step == BuildStep.Save && d.editing != null -> "Save changes"
                step == BuildStep.Save -> if (issues.isEmpty()) "Save deck" else "Save as draft"
                step == BuildStep.Main && d.mainCount < DeckRules.MAIN -> "Continue · ${d.mainCount}/${DeckRules.MAIN}"
                noChampions -> "Skip"
                else -> "Next"
            }
            val enabled = when (step) {
                BuildStep.Legend -> d.legend != null
                BuildStep.Champion -> d.champion != null || noChampions
                BuildStep.Save -> d.name.isNotBlank()
                else -> true
            }
            WideButton(label, Modifier.weight(1f), fill = RiftColors.You, ink = Color.Black, enabled = enabled) {
                if (step == BuildStep.Save) onSave(d) else ui.step = BuildStep.entries[step.ordinal + 1]
            }
        }
    }
}

/** The light rail: a glowing fill up to the current stop; done stops green with a check, the current one white. */
@Composable
private fun Rail(step: BuildStep, done: List<Boolean>, reachable: (Int) -> Boolean, onGo: (BuildStep) -> Unit) {
    val fill by animateFloatAsState(step.ordinal / 6f, tween(700, easing = RiftEase), label = "rail")
    BoxWithConstraints(Modifier.fillMaxWidth().padding(top = 6.dp).height(74.dp)) {
        val left = 34.dp
        val span = maxWidth - left * 2
        Box(Modifier.offset(left, 24.dp).size(span, 3.dp).background(Color.White.copy(alpha = 0.12f), RoundedCornerShape(2.dp)))
        Box(
            Modifier.offset(left, 24.dp).size(span, 3.dp).graphicsLayer { scaleX = fill; transformOrigin = TransformOrigin(0f, 0.5f) }
                .dropShadow(RoundedCornerShape(2.dp), Shadow(radius = 12.dp, color = RiftColors.You.copy(alpha = 0.8f)))
                .background(RiftColors.You, RoundedCornerShape(2.dp)),
        )
        BuildStep.entries.forEachIndexed { i, s ->
            val cur = s == step
            val before = i < step.ordinal
            val x = left + span * (i / 6f)
            val bg by animateColorAsState(if (cur) Color.White else if (before) RiftColors.You else Color.White.copy(alpha = 0.14f), tween(400), label = "node")
            val scale by animateFloatAsState(if (cur) 1.12f else 1f, tween(400, easing = RiftEase), label = "nodeScale")
            Box(
                Modifier.offset { IntOffset((x - 13.dp).roundToPx(), 13.dp.roundToPx()) }.size(26.dp)
                    .graphicsLayer { scaleX = scale; scaleY = scale }
                    .let { m ->
                        when {
                            cur -> m.dropShadow(CircleShape, Shadow(radius = 18.dp, color = Color.White.copy(alpha = 0.4f))).dropShadow(CircleShape, Shadow(radius = 0.dp, spread = 5.dp, color = RiftColors.You.copy(alpha = 0.35f)))
                            before -> m.dropShadow(CircleShape, Shadow(radius = 12.dp, color = RiftColors.You.copy(alpha = 0.7f)))
                            else -> m
                        }
                    }
                    .background(bg, CircleShape)
                    .clickable(remember { MutableInteractionSource() }, indication = null, enabled = reachable(i), role = Role.Tab) { onGo(s) }
                    .semantics { contentDescription = "Step ${i + 1}, ${s.label}" },
                contentAlignment = Alignment.Center,
            ) { if (before && done[i]) Image(DeckIcons.Check, null, colorFilter = ColorFilter.tint(Color.Black)) }
            BasicText(
                s.label,
                Modifier.offset { IntOffset((x - 40.dp).roundToPx(), 46.dp.roundToPx()) }.width(80.dp).wrapContentWidth(Alignment.CenterHorizontally),
                style = RiftType.Body.copy(fontSize = 10.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.06.em, color = if (cur) Color.White else if (before) RiftColors.You.copy(alpha = 0.9f) else Color.White.copy(alpha = 0.4f)),
            )
        }
    }
}

@Composable
private fun TitleLine(title: String, key: BuildStep) {
    val t = remember(key) { Animatable(0f) }
    LaunchedEffect(key) { t.animateTo(1f, tween(600, easing = RiftEase)) }
    BasicText(
        title,
        Modifier.padding(horizontal = 20.dp).height(44.dp).graphicsLayer {
            alpha = t.value
            translationY = 10.dp.toPx() * (1f - t.value)
            val b = 8.dp.toPx() * (1f - t.value)
            renderEffect = softBlur(b)
        },
        style = RiftType.Title.copy(fontSize = 32.sp, lineHeight = 32.sp, color = Color.White),
    )
}

@Composable
private fun LegendPage(d: Draft, pool: List<Card>, onPick: (Card) -> Unit) {
    var query by remember { mutableStateOf("") }
    val all = remember(pool) { Builder.legends(pool) }
    val shown = all.filter { query.isBlank() || it.name.contains(query.trim(), true) }
    val density = LocalDensity.current
    LazyVerticalGrid(
        GridCells.Fixed(2), Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 24.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        item(span = { GridItemSpan(2) }) { Box(Modifier.padding(bottom = 4.dp)) { SearchField(query, placeholder = "Search legends", inset = 0.dp) { query = it } } }
        if (shown.isEmpty()) item(span = { GridItemSpan(2) }) { BasicText(if (all.isEmpty()) "Loading the card list…" else "No legend matches.", style = SheetText) }
        items(shown, key = { it.id }) { l ->
            val on = d.legend?.id == l.id
            val shape = RoundedCornerShape(22.dp)
            Box(
                Modifier.height(118.dp).let { if (on) it.dropShadow(shape, Shadow(radius = 24.dp, color = Color.White.copy(alpha = 0.35f))) else it }
                    .clip(shape).clickable(remember { MutableInteractionSource() }, indication = null, role = Role.RadioButton) { onPick(l) }
                    .semantics { contentDescription = l.name },
            ) {
                ArtBox(l, with(density) { 200.dp.roundToPx() }, Modifier.fillMaxSize(), alignment = ArtTop, initialSize = 90.sp) {
                    Box(Modifier.fillMaxSize().bottomShade(0.25f))
                    Column(Modifier.align(Alignment.BottomStart).padding(12.dp)) {
                        BasicText(l.title, style = RiftType.Title.copy(fontSize = 22.sp, lineHeight = 22.sp, letterSpacing = 0.02.em, color = Color.White), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        // "Scorn of the Moon · Overnumbered": two printings of one legend look alike otherwise.
                        listOfNotNull(l.subtitle, l.printing).joinToString(" · ").ifEmpty { null }?.let {
                            BasicText(it, style = RiftType.Body.copy(fontSize = 11.5.sp, lineHeight = 13.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.85f)), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        }
                        BasicText(
                            l.domains.joinToString(" · ").uppercase(), Modifier.padding(top = 4.dp),
                            style = RiftType.Caption.copy(fontSize = 10.sp, letterSpacing = 0.12.em, color = Color.White.copy(alpha = 0.8f)),
                        )
                    }
                }
                Box(Modifier.fillMaxSize().border(if (on) 2.dp else 1.dp, if (on) Color.White else Color.White.copy(alpha = 0.1f), shape))
            }
        }
    }
}

@Composable
private fun ChampionPage(d: Draft, champions: List<Card>, onPick: (Card) -> Unit) {
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 24.dp)) {
        if (champions.isEmpty()) item { BasicText(if (d.legend == null) "Pick a legend first." else "No champion card matches ${d.legend.title}. Skip this step.", style = SheetText) }
        items(champions, key = { it.id }) { c ->
            PickRow(c.name, unitLine(c), d.champion?.id == c.id, leading = { Mini(c) }) { onPick(c) }
        }
    }
}

/** The battlefields as the Cards tab shows them, three to a row (Okay: building without art is hard). */
@Composable
private fun FieldsPage(d: Draft, pool: List<Card>, onToast: (String) -> Unit, onChange: (Draft) -> Unit) {
    var query by remember { mutableStateOf("") }
    val all = remember(pool) { Builder.battlefields(pool) }
    val tilePx = LocalWindowInfo.current.containerSize.width / 3
    PoolGrid {
        header { CountHead(d.battlefields.size, DeckRules.BATTLEFIELDS, if (d.keepBattlefields) "Kept as they are" else "Pick three") }
        if (d.keepBattlefields) {
            header { BasicText("This deck's battlefields are not all in today's card list, so they stay as they are.", Modifier.padding(bottom = 10.dp), style = SheetText) }
        } else {
            header { Box(Modifier.padding(bottom = 6.dp)) { SearchField(query, placeholder = "Search battlefields", inset = 0.dp) { query = it } } }
            items(all.filter { query.isBlank() || it.name.contains(query.trim(), true) }, key = { it.id }) { c ->
                val on = d.battlefields.any { it.id == c.id }
                FieldPick(c, on, tilePx, onToggle = {
                    if (!on && d.battlefields.size >= DeckRules.BATTLEFIELDS) onToast("Three battlefields, remove one first") else onChange(Builder.toggleBattlefield(d, c))
                })
            }
        }
    }
}

/** Three cards to a row, headers across the whole width. */
@Composable
private fun PoolGrid(content: LazyGridScope.() -> Unit) {
    LazyVerticalGrid(
        GridCells.Fixed(3), Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 2.dp, bottom = 24.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp),
        content = content,
    )
}

/** A grid item stacks what it holds on top of each other: a header lays its parts out in a column. */
private fun LazyGridScope.header(content: @Composable ColumnScope.() -> Unit) = item(span = { GridItemSpan(maxLineSpan) }) { Column { content() } }

@Composable
private fun CountHead(n: Int, of: Int, right: String, rightTag: Boolean = false) {
    Row(Modifier.fillMaxWidth().padding(top = 2.dp, bottom = 10.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
        BasicText(
            buildAnnotatedString {
                append("$n")
                pushStyle(SpanStyle(fontSize = 20.sp, color = Color.White.copy(alpha = 0.55f)))
                append(" / $of")
                pop()
            },
            style = RiftType.Title.copy(fontSize = 40.sp, lineHeight = 40.sp, fontFeatureSettings = "tnum", color = Color.White),
        )
        if (rightTag) {
            BasicText(
                right,
                Modifier.height(28.dp).border(1.dp, Color(0x80C08BFF), RoundedCornerShape(14.dp)).padding(horizontal = 12.dp, vertical = 6.dp),
                style = RiftType.Caption.copy(fontWeight = FontWeight.Bold, letterSpacing = 0.08.em, color = Color(0xFFC08BFF)),
            )
        } else {
            BasicText(right.uppercase(), style = RiftType.Caption.copy(fontSize = 11.5.sp, letterSpacing = 0.14.em, color = Color.White.copy(alpha = 0.62f)))
        }
    }
}

@Composable
private fun Progress(fraction: Float) {
    val f by animateFloatAsState(fraction, tween(500, easing = RiftEase), label = "progress")
    Box(Modifier.fillMaxWidth().padding(bottom = 10.dp).height(5.dp).background(Color.White.copy(alpha = 0.1f), RoundedCornerShape(3.dp))) {
        Box(
            Modifier.fillMaxSize().graphicsLayer { scaleX = f; transformOrigin = TransformOrigin(0f, 0.5f) }
                .dropShadow(RoundedCornerShape(3.dp), Shadow(radius = 10.dp, color = RiftColors.You.copy(alpha = 0.8f))).background(RiftColors.You, RoundedCornerShape(3.dp)),
        )
    }
}

/**
 * Main or side: the cards the legend allows as a gallery (iOS `CardPoolPickerView`, Okay asked for the art):
 * a tap adds a copy, the minus on a card takes one back; search and type chips on top.
 */
@Composable
private fun PoolPage(d: Draft, pile: Pile, pool: List<Card>, index: Map<String, Card>, onToast: (String) -> Unit, onChange: (Draft) -> Unit) {
    var query by remember { mutableStateOf("") }
    var types by remember { mutableStateOf(emptySet<String>()) }
    var shortlisted by remember { mutableStateOf(false) }
    val kept = Shortlist.ids
    // Only the kept cards this legend may play count, so the chip never promises cards it cannot show.
    val keptHere = remember(d.legend, pool, kept) { Builder.pool(d, pool).count { it.id in kept } }
    val cards = remember(d.legend, pool, query, types, shortlisted, kept) {
        Builder.pool(d, pool, query, types).let { all -> if (shortlisted) all.filter { it.id in kept } else all }
    }
    val main = pile == Pile.Main
    val tilePx = LocalWindowInfo.current.containerSize.width / 3
    PoolGrid {
        header {
            if (main) CountHead(d.mainCount, DeckRules.MAIN, "SIG ${Builder.signatures(d, index)} / ${DeckRules.SIGNATURE_LIMIT}", rightTag = true)
            else CountHead(d.sideCount, Builder.SIDE, "Optional · 0 or 10")
            Progress(if (main) d.mainCount / DeckRules.MAIN.toFloat() else d.sideCount / Builder.SIDE.toFloat())
            SearchField(query, inset = 0.dp) { query = it }
            Row(Modifier.padding(top = 10.dp, bottom = 6.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf("Unit", "Spell", "Gear").forEach { t -> OnOffChip(t, t in types, height = 34.dp) { types = if (t in types) types - t else types + t } }
                // The cards kept in mind from the Cards tab, so they need no searching.
                if (keptHere > 0) OnOffChip("Shortlist $keptHere", shortlisted, height = 34.dp) { shortlisted = !shortlisted }
            }
            if (d.legend == null) BasicText("Pick a legend first: its domains decide the cards.", Modifier.padding(vertical = 12.dp), style = SheetText)
        }
        items(cards, key = { it.id }) { c ->
            val blocker = Builder.blocker(d, pile, c, index)
            PickTile(
                c, d.count(pile, c), blocker != null, tilePx,
                onAdd = { if (blocker != null) onToast(blocker) else onChange(Builder.add(d, pile, c)) },
                onRemove = { onChange(Builder.remove(d, pile, c)) },
            )
        }
    }
}

@Composable
private fun RunesPage(d: Draft, onChange: (Draft) -> Unit) {
    Column(Modifier.fillMaxSize().padding(horizontal = 16.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.weight(1f)) { CountHead(d.runeCount, DeckRules.RUNES, "") }
            LinkButton("Split evenly", { onChange(d.copy(runes = Builder.evenSplit(d.domains))) })
        }
        if (d.keepRunes) BasicText("This deck's runes are not all in today's card list or the legend's domains, so they stay as they are.", Modifier.padding(bottom = 10.dp), style = SheetText)
        else RunePool(d.domains, { d.runes[it.lowercase()] ?: 0 }, d.runeCount) { domain, delta -> onChange(Builder.rune(d, domain, delta)) }
    }
}

@Composable
private fun SavePage(d: Draft, issues: List<String>, onName: (String) -> Unit) {
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 24.dp)) {
        item {
            BasicText("DECK NAME", style = RiftType.Caption.copy(fontSize = 10.5.sp, letterSpacing = 0.14.em, color = Color.White.copy(alpha = 0.6f)))
            NameField(d.name, onName, Modifier.padding(top = 8.dp, bottom = 12.dp))
        }
        val rows = listOf(
            "Legend" to (d.legend?.title ?: d.unknownLegend?.cardName ?: "—"),
            "Champion" to (d.champion?.name ?: d.unknownChampion?.cardName ?: "—"),
            "Battlefields" to "${d.battlefields.size} / ${DeckRules.BATTLEFIELDS}",
            "Main deck" to "${d.mainCount} / ${DeckRules.MAIN}",
            "Sideboard" to "${d.sideCount} / ${Builder.SIDE}",
            "Runes" to "${d.runeCount} / ${DeckRules.RUNES}",
        )
        items(rows) { (k, v) ->
            Row(
                Modifier.fillMaxWidth().height(44.dp)
                    .drawBehind { drawRect(Color.White.copy(alpha = 0.07f), Offset(0f, size.height - 1.dp.toPx()), Size(size.width, 1.dp.toPx())) },
                horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically,
            ) {
                BasicText(k, style = RiftType.Body.copy(fontSize = 14.sp, color = Color.White))
                BasicText(v, style = RiftType.Body.copy(fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Color.White), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        items(issues) { t -> Notice(t, RiftColors.Gold, DeckIcons.Warn) }
        if (issues.isEmpty()) item { Notice("Tournament legal", RiftColors.You, DeckIcons.Check) }
    }
}

/** A gold warning or the green all-clear line (builder save page, deck check). */
@Composable
fun Notice(text: String, color: Color, icon: ImageVector) {
    val shape = RoundedCornerShape(14.dp)
    Row(
        Modifier.padding(top = 8.dp).fillMaxWidth().background(color.copy(alpha = 0.08f), shape).border(1.dp, color.copy(alpha = 0.32f), shape).padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Image(icon, null, colorFilter = ColorFilter.tint(color))
        Spacer(Modifier.width(10.dp))
        BasicText(text, style = RiftType.Body.copy(fontSize = 13.5.sp, lineHeight = 19.sp, fontWeight = if (color == RiftColors.You) FontWeight.SemiBold else FontWeight.Medium, color = if (color == RiftColors.You) color else Color.White))
    }
}
