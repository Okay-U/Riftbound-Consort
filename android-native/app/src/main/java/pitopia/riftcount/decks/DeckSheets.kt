package pitopia.riftcount.decks

import android.content.ClipData
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.platform.ClipEntry
import androidx.compose.ui.platform.LocalClipboard
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import pitopia.riftcount.cards.Card
import pitopia.riftcount.cards.CardStyle
import pitopia.riftcount.cards.SearchField
import pitopia.riftcount.data.DeckRules
import pitopia.riftcount.data.DeckText
import pitopia.riftcount.data.Decklist
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.Sheet
import pitopia.riftcount.ui.common.StepCount
import pitopia.riftcount.ui.common.Stepper
import pitopia.riftcount.ui.common.ToastHost
import pitopia.riftcount.ui.common.Toaster
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

private val Label = RiftType.Caption.copy(fontSize = 10.5.sp, letterSpacing = 0.14.em, color = Color.White.copy(alpha = 0.6f))

/** Draw odds over the 39-card main deck; several cards can be picked, the chance counts any of them. */
@Composable
fun OddsSheet(deck: Decklist, index: Map<String, Card>, onDismiss: () -> Unit) {
    val entries = deck.mainDeck
    var picked by remember { mutableStateOf(setOfNotNull(entries.maxByOrNull { it.count }?.cardId)) }
    val n = entries.sumOf { it.count }.coerceAtLeast(1)
    var draws by remember { mutableIntStateOf(minOf(6, n)) }
    var k by remember { mutableIntStateOf(1) }
    val copies = entries.filter { it.cardId in picked }.sumOf { it.count }
    val atLeast = k.coerceIn(1, copies.coerceAtLeast(1))
    val p = Odds.atLeast(n, copies, minOf(draws, n), atLeast)
    val pct = Math.round(p * 100).toInt()
    Sheet("Draw odds", onDismiss) {
        BasicText("Draw odds", style = SheetTitle)
        BasicText("Pick cards. The chance counts the main deck.", Modifier.padding(top = 4.dp, bottom = 12.dp), style = SheetText)
        Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            entries.sortedByDescending { it.count }.forEach { e ->
                val on = e.cardId in picked
                OnOffChip("${(index[e.cardId]?.title ?: e.cardName)} ×${e.count}", on) {
                    picked = if (on) picked - e.cardId else picked + e.cardId
                }
            }
        }
        Box(Modifier.fillMaxWidth().padding(top = 6.dp).height(118.dp), contentAlignment = Alignment.Center) {
            StepCount(
                pct, 118.dp, color = when {
                    pct >= 75 -> RiftColors.You
                    pct >= 40 -> Color.White
                    else -> RiftColors.Gold
                },
                width = 260.dp, fontSize = 108f, suffix = "%",
            )
        }
        val fill by animateFloatAsState(p.toFloat(), tween(700, easing = RiftEase), label = "odds")
        Box(Modifier.fillMaxWidth().height(6.dp).background(Color.White.copy(alpha = 0.12f), RoundedCornerShape(3.dp))) {
            Box(
                Modifier.fillMaxHeight().fillMaxWidth().graphicsLayer { scaleX = fill; transformOrigin = TransformOrigin(0f, 0.5f) }
                    .dropShadow(RoundedCornerShape(3.dp), Shadow(radius = 12.dp, color = RiftColors.You.copy(alpha = 0.8f)))
                    .background(RiftColors.You, RoundedCornerShape(3.dp)),
            )
        }
        val what = when (picked.size) {
            0 -> null
            1 -> index[picked.first()]?.title ?: entries.first { it.cardId in picked }.cardName
            else -> "any of ${picked.size} picked cards"
        }
        BasicText(
            if (what == null) "Pick a card above." else
                "Chance to see at least $atLeast ${if (atLeast == 1) "copy" else "copies"} of $what ($copies in deck) in the first ${minOf(draws, n)} cards.",
            Modifier.fillMaxWidth().padding(top = 12.dp, bottom = 4.dp),
            style = RiftType.Body.copy(fontSize = 13.5.sp, lineHeight = 19.5.sp, color = Color.White.copy(alpha = 0.78f), textAlign = TextAlign.Center),
        )
        Row(Modifier.fillMaxWidth().padding(top = 14.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            StepBox("Cards seen", Modifier.weight(1f)) { Stepper(draws, { draws-- }, { draws++ }, "card seen", minus = draws > 1, plus = draws < n, button = 32.dp) }
            StepBox("At least", Modifier.weight(1f)) { Stepper(atLeast, { k = atLeast - 1 }, { k = atLeast + 1 }, "copy", minus = atLeast > 1, plus = atLeast < copies, button = 32.dp) }
        }
    }
}

@Composable
private fun StepBox(label: String, modifier: Modifier, content: @Composable () -> Unit) {
    val shape = RoundedCornerShape(20.dp)
    Column(
        modifier.background(Color.White.copy(alpha = 0.05f), shape).border(1.dp, Color.White.copy(alpha = 0.08f), shape).padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        BasicText(label.uppercase(), Modifier.padding(bottom = 8.dp), style = Label)
        content()
    }
}

/** The mocks' on/off chip: green when on. */
@Composable
fun OnOffChip(label: String, on: Boolean, color: Color = RiftColors.You, height: Dp = 36.dp, onClick: () -> Unit) {
    val shape = RoundedCornerShape(height / 2)
    Pressable(
        onClick,
        Modifier.height(height).background(if (on) color else Color.White.copy(alpha = 0.04f), shape)
            .border(1.dp, if (on) color else Color.White.copy(alpha = 0.16f), shape).padding(horizontal = 12.dp)
            .semantics { selected = on },
        pressedScale = 0.95f,
        role = Role.Checkbox,
    ) {
        BasicText(label, style = RiftType.Body.copy(fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold, color = if (on) Color.Black else Color.White), maxLines = 1)
    }
}

/** Energy curve, power by domain, card types, average energy. */
@Composable
fun StatsSheet(deck: Decklist, index: Map<String, Card>, onDismiss: () -> Unit) {
    val s = remember(deck) { DeckStats.of(deck, index) }
    Sheet("Deck stats", onDismiss) {
        BasicText("Deck stats", style = SheetTitle)
        BasicText("ENERGY CURVE · MAIN DECK", Modifier.padding(top = 16.dp, bottom = 8.dp), style = Label)
        val max = (s.curve.maxOrNull() ?: 0).coerceAtLeast(1)
        Row(Modifier.fillMaxWidth().height(150.dp).padding(top = 22.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.Bottom) {
            s.curve.forEachIndexed { i, n ->
                val grow = remember { Animatable(0f) }
                LaunchedEffect(Unit) {
                    delay(i * 60L)
                    grow.animateTo(1f, tween(900, easing = RiftEase))
                }
                Column(Modifier.weight(1f).fillMaxHeight(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Bottom) {
                    BasicText("$n", style = RiftType.Title.copy(fontSize = 16.sp, lineHeight = 16.sp, color = Color.White))
                    Box(
                        Modifier.padding(vertical = 6.dp).fillMaxWidth().height(72.dp * (n.toFloat() / max)).graphicsLayer { scaleY = grow.value; transformOrigin = TransformOrigin(0.5f, 1f) }
                            .dropShadow(RoundedCornerShape(8.dp, 8.dp, 3.dp, 3.dp), Shadow(radius = 14.dp, color = RiftColors.You.copy(alpha = 0.45f * (if (n > 0) 1f else 0f))))
                            .background(RiftColors.You, RoundedCornerShape(8.dp, 8.dp, 3.dp, 3.dp)),
                    )
                    BasicText(if (i == 7) "7+" else "$i", style = RiftType.Body.copy(fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.6f)))
                }
            }
        }
        BasicText("POWER BY DOMAIN", Modifier.padding(top = 16.dp, bottom = 8.dp), style = Label)
        if (s.power.isEmpty()) {
            BasicText("No cards with power yet.", style = SheetText)
        } else {
            Row(Modifier.fillMaxWidth().height(14.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                s.power.forEach { (d, n) -> Box(Modifier.weight(n.toFloat()).fillMaxHeight().background(CardStyle.domainColor(d), RoundedCornerShape(7.dp))) }
            }
            Row(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                s.power.forEach { (d, n) ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(8.dp).background(CardStyle.domainColor(d), CircleShape))
                        BasicText("$d · $n", Modifier.padding(start = 6.dp), style = RiftType.Body.copy(fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.75f)))
                    }
                }
            }
        }
        BasicText("CARD TYPES", Modifier.padding(top = 16.dp, bottom = 2.dp), style = Label)
        val tmax = (s.types.maxOfOrNull { it.second } ?: 0).coerceAtLeast(1)
        s.types.forEach { (t, n) ->
            Row(Modifier.fillMaxWidth().padding(top = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                BasicText(if (t == "Gear") "Gear" else "${t}s", Modifier.width(58.dp), style = RiftType.Body.copy(fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color.White))
                Box(Modifier.weight(1f).height(8.dp).background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(4.dp))) {
                    Box(Modifier.fillMaxHeight().fillMaxWidth(n.toFloat() / tmax).background(Color.White, RoundedCornerShape(4.dp)))
                }
                BasicText("$n", Modifier.width(24.dp).padding(start = 4.dp), style = RiftType.Title.copy(fontSize = 16.sp, lineHeight = 16.sp, color = Color.White, textAlign = TextAlign.End))
            }
        }
        Row(
            Modifier.fillMaxWidth().padding(top = 16.dp)
                .drawBehind { drawRect(Color.White.copy(alpha = 0.08f), size = Size(size.width, 1.dp.toPx())) }.padding(top = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically,
        ) {
            BasicText("AVERAGE ENERGY", style = RiftType.Caption.copy(fontSize = 12.sp, letterSpacing = 0.12.em, color = Color.White.copy(alpha = 0.62f)))
            BasicText(s.averageEnergy?.let { "%.1f".format(it) } ?: "–", style = RiftType.Title.copy(fontSize = 30.sp, lineHeight = 30.sp, color = Color.White))
        }
    }
}

/** The mock's pick row: art or text, a check on the right when chosen. */
@Composable
fun PickRow(title: String, sub: String?, on: Boolean, modifier: Modifier = Modifier, check: Boolean = true, leading: (@Composable () -> Unit)? = null, onClick: () -> Unit) {
    val shape = RoundedCornerShape(20.dp)
    Pressable(
        onClick,
        modifier.padding(bottom = 8.dp).fillMaxWidth().heightIn(min = 62.dp)
            .let { if (on) it.dropShadow(shape, Shadow(radius = 18.dp, color = RiftColors.You.copy(alpha = 0.25f))) else it }
            // Opaque: a CSS box-shadow stays outside the box, Compose's would shine through a see-through fill.
            .background(Color(0xFF171717), shape).border(1.dp, if (on) RiftColors.You else Color.White.copy(alpha = 0.12f), shape)
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .semantics { selected = on },
        pressedScale = 0.98f,
        contentAlignment = Alignment.CenterStart,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            leading?.let { it(); Spacer(Modifier.width(12.dp)) }
            Column(Modifier.weight(1f)) {
                BasicText(title, style = RiftType.Body.copy(fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Color.White))
                sub?.let { BasicText(it, Modifier.padding(top = 2.dp), style = RiftType.Body.copy(fontSize = 12.sp, lineHeight = 16.sp, color = Color.White.copy(alpha = 0.6f)), maxLines = 3) }
            }
            if (check) {
                Box(
                    Modifier.padding(start = 8.dp).size(26.dp).background(if (on) RiftColors.You else Color.Transparent, CircleShape)
                        .border(1.5.dp, if (on) RiftColors.You else Color.White.copy(alpha = 0.3f), CircleShape),
                    contentAlignment = Alignment.Center,
                ) { if (on) Image(DeckIcons.Check, null, colorFilter = ColorFilter.tint(Color.Black)) }
            }
        }
    }
}

/** Swap the chosen champion: every champion of the legend; one from the main deck trades places. */
@Composable
fun ChampionSheet(deck: Decklist, index: Map<String, Card>, pool: List<Card>, onPick: (Card) -> Unit, onDismiss: () -> Unit) {
    val legend = deck.legend?.let { index[it.cardId] }
    val options = remember(legend, pool) { Builder.champions(legend, pool) }
    Sheet("Chosen champion", onDismiss) { close ->
        BasicText("Chosen champion", style = SheetTitle)
        BasicText(
            "The champion starts in its own zone. Copies in the main deck count toward the limit of three.",
            Modifier.padding(top = 4.dp, bottom = 12.dp), style = SheetText,
        )
        if (options.isEmpty()) BasicText(if (legend == null) "Pick a legend first." else "No champion card matches ${legend.title}.", style = SheetText)
        options.forEach { c ->
            val on = c.id == deck.champion?.cardId
            PickRow(c.name, unitLine(c) + if (on) " · chosen" else "", on, check = false, leading = { Mini(c) }) {
                onPick(c)
                close()
            }
        }
    }
}

/** iOS `DeckLegality`: what the deck still needs to be tournament legal. */
@Composable
fun IssuesSheet(deck: Decklist, index: Map<String, Card>, onDismiss: () -> Unit) {
    val issues = remember(deck) { DeckRules.issues(deck, index) }
    Sheet("Deck check", onDismiss) {
        BasicText(if (issues.isEmpty()) "Tournament legal" else "Not legal yet", style = SheetTitle)
        BasicText(
            if (issues.isEmpty()) "Legend, champion, three battlefields, 39 cards, 12 runes: all there." else "Saved decks may be drafts; this is what a tournament checks.",
            Modifier.padding(top = 4.dp, bottom = 4.dp), style = SheetText,
        )
        issues.forEach { Notice(it, RiftColors.Gold, DeckIcons.Warn) }
        if (issues.isEmpty()) Notice("Tournament legal", RiftColors.You, DeckIcons.Check)
    }
}

/** Three battlefields, each player brings their own. */
@Composable
fun FieldsSheet(deck: Decklist, pool: List<Card>, onToggle: (Card) -> Boolean, onDismiss: () -> Unit) {
    val toaster = remember { Toaster() }
    var query by remember { mutableStateOf("") }
    val all = remember(pool) { Builder.battlefields(pool) }
    Sheet("Battlefields", onDismiss, overlay = { ToastHost(toaster) }) {
        BasicText("Battlefields · ${deck.battlefields.size} / ${DeckRules.BATTLEFIELDS}", style = SheetTitle)
        BasicText("Pick three. Each player brings their own.", Modifier.padding(top = 4.dp, bottom = 4.dp), style = SheetText)
        SearchField(query, placeholder = "Search battlefields", inset = 0.dp) { query = it }
        Spacer(Modifier.height(12.dp))
        all.filter { query.isBlank() || it.name.contains(query.trim(), true) }.forEach { c ->
            val on = deck.battlefields.any { it.cardId == c.id }
            PickRow(c.name, c.summary, on) {
                if (!onToggle(c)) toaster.show("Three battlefields, remove one first")
            }
        }
    }
}

/** The deck as text for other deck sites and the import. */
@Composable
fun ExportSheet(deck: Decklist, index: Map<String, Card>, onCopied: () -> Unit, onDismiss: () -> Unit) {
    val text = remember(deck) { DeckText.export(deck, index) }
    val clipboard = LocalClipboard.current
    val scope = rememberCoroutineScope()
    Sheet("Export deck", onDismiss) { close ->
        BasicText("Export ${deck.name}", style = SheetTitle)
        BasicText("Plain text that the Riftcount import and most deck sites read.", Modifier.padding(top = 4.dp, bottom = 12.dp), style = SheetText)
        val shape = RoundedCornerShape(16.dp)
        BasicText(
            text.ifEmpty { "This deck is empty." },
            Modifier.fillMaxWidth().heightIn(max = 300.dp).background(Color(0xFF0A0A0A), shape).border(1.dp, Color.White.copy(alpha = 0.1f), shape)
                .verticalScroll(rememberScrollState()).padding(12.dp),
            style = RiftType.Body.copy(fontFamily = FontFamily.Monospace, fontSize = 12.sp, lineHeight = 18.6.sp, fontWeight = FontWeight.Normal, color = Color.White.copy(alpha = 0.86f)),
        )
        WideButton("Copy text", Modifier.padding(top = 12.dp).fillMaxWidth(), fill = RiftColors.You, ink = Color.Black, enabled = text.isNotEmpty()) {
            scope.launch {
                clipboard.setClipEntry(ClipEntry(ClipData.newPlainText(deck.name, text)))
                onCopied()
                close()
            }
        }
    }
}

/** Rename, edit in the builder, delete (iOS has them in the toolbar and the list). */
@Composable
fun DeckMenuSheet(deck: Decklist, onRename: (String) -> Unit, onEdit: () -> Unit, onDelete: () -> Unit, onDismiss: () -> Unit) {
    var name by remember { mutableStateOf(deck.name) }
    var confirm by remember { mutableStateOf(false) }
    Sheet("Deck", onDismiss) { close ->
        BasicText(deck.name, style = SheetTitle)
        BasicText("NAME", Modifier.padding(top = 14.dp, bottom = 8.dp), style = Label)
        NameField(name, { name = it.take(40) })
        WideButton("Save name", Modifier.padding(top = 10.dp).fillMaxWidth(), fill = RiftColors.You, ink = Color.Black, enabled = name.isNotBlank() && name.trim() != deck.name) {
            onRename(name.trim())
            close()
        }
        WideButton("Edit in the builder", Modifier.padding(top = 10.dp).fillMaxWidth()) {
            close()
            onEdit()
        }
        WideButton(if (confirm) "Tap again to delete ${deck.name}" else "Delete deck", Modifier.padding(top = 10.dp).fillMaxWidth(), fill = RiftColors.Danger.copy(alpha = if (confirm) 1f else 0.16f), ink = if (confirm) Color.Black else RiftColors.Danger) {
            if (confirm) {
                close()
                onDelete()
            } else {
                confirm = true
            }
        }
    }
}

/** The builder's and the menu's name input (52dp, green ring while typing). */
@Composable
fun NameField(value: String, onChange: (String) -> Unit, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(18.dp)
    BasicTextField(
        value, onChange,
        modifier.fillMaxWidth().height(52.dp).background(Color(0xFF0B0B0B), shape).border(1.dp, Color.White.copy(alpha = 0.16f), shape)
            .semantics { contentDescription = "Deck name" },
        textStyle = RiftType.Body.copy(fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Color.White),
        singleLine = true,
        cursorBrush = SolidColor(RiftColors.You),
        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
        decorationBox = { field -> Box(Modifier.fillMaxSize().padding(horizontal = 16.dp), contentAlignment = Alignment.CenterStart) { field() } },
    )
}
