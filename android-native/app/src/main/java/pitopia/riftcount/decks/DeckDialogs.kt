package pitopia.riftcount.decks

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalClipboard
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import pitopia.riftcount.cards.Card
import pitopia.riftcount.cards.SearchField
import pitopia.riftcount.data.DeckText
import pitopia.riftcount.data.Decklist
import pitopia.riftcount.data.GameRecord
import pitopia.riftcount.ui.common.DialogFrame
import pitopia.riftcount.ui.common.LinkButton
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftType

private val FieldLabel = RiftType.Caption.copy(fontSize = 10.5.sp, letterSpacing = 0.14.em, color = Color.White.copy(alpha = 0.6f))

/** Result, turn order, deck and opponent of a logged game; deleting asks twice (iOS: swipe actions). */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun EditGameDialog(game: GameRecord, decks: List<Decklist>, legends: List<String>, onSave: (GameRecord) -> Unit, onDelete: () -> Unit, onDismiss: () -> Unit) {
    var won by remember { mutableStateOf(game.won) }
    var first by remember { mutableStateOf(game.startedFirst) }
    var deckId by remember { mutableStateOf(game.deckId) }
    var opponent by remember { mutableStateOf(game.opponent) }
    var query by remember { mutableStateOf("") }
    var confirm by remember { mutableStateOf(false) }
    val shortCount = remember(legends) { legends.groupingBy(::opponentShort).eachCount() }
    fun label(name: String) = opponentShort(name).let { if ((shortCount[it] ?: 0) > 1) name else it }
    DialogFrame(onDismiss, fullScreen = false) {
        Column(Modifier.heightIn(max = 470.dp).verticalScroll(rememberScrollState())) {
            BasicText("Edit game", style = RiftType.Body.copy(fontSize = 17.sp, fontWeight = FontWeight.Bold, color = Color.White))
            BasicText("RESULT", Modifier.padding(top = 16.dp, bottom = 8.dp), style = FieldLabel)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                OnOffChip("Won", won, RiftColors.You, 34.dp) { won = true }
                OnOffChip("Lost", !won, Violet, 34.dp) { won = false }
            }
            BasicText("TURN ORDER", Modifier.padding(top = 16.dp, bottom = 8.dp), style = FieldLabel)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                OnOffChip("Went first", first == true, Color.White, 34.dp) { first = true }
                OnOffChip("Went second", first == false, Color.White, 34.dp) { first = false }
                OnOffChip("Unknown", first == null, Color.White, 34.dp) { first = null }
            }
            BasicText("DECK", Modifier.padding(top = 16.dp, bottom = 8.dp), style = FieldLabel)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                OnOffChip("None", deckId == null, RiftColors.You, 34.dp) { deckId = null }
                decks.forEach { d -> OnOffChip(d.name, deckId.equals(d.id, true), RiftColors.You, 34.dp) { deckId = d.id } }
                // A deck deleted since the game: its name stays on the game unless another deck is picked.
                game.deckName?.takeIf { game.deckId != null && decks.none { d -> d.id.equals(game.deckId, true) } }?.let { name ->
                    OnOffChip("$name (deleted)", deckId == game.deckId, RiftColors.You, 34.dp) { deckId = game.deckId }
                }
            }
            BasicText("OPPONENT LEGEND", Modifier.padding(top = 16.dp), style = FieldLabel)
            SearchField(query, placeholder = "Search legends", inset = 0.dp) { query = it }
            FlowRow(Modifier.padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                val matches = legends.filter { query.isBlank() || it.contains(query.trim(), true) }
                val shown = (listOf(opponent).filter { it.isNotBlank() } + matches.filterNot { it == opponent }).take(24)
                OnOffChip("Unknown", opponent.isBlank(), Violet, 34.dp) { opponent = "" }
                shown.forEach { name -> OnOffChip(label(name), name == opponent, Violet, 34.dp) { opponent = name } }
            }
        }
        Column {
            Row(Modifier.fillMaxWidth().padding(top = 18.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                WideButton("Cancel", Modifier.weight(1f), onClick = onDismiss)
                WideButton("Save", Modifier.weight(1f), fill = RiftColors.You, ink = Color.Black) {
                    val deck = decks.firstOrNull { it.id.equals(deckId, true) }
                    val (id, name) = if (deckId == game.deckId && deck == null) game.deckId to game.deckName else deck?.id to deck?.name
                    onSave(game.copy(result = if (won) "won" else "lost", startedFirst = first, deckId = id, deckName = name, opponent = opponent))
                }
            }
            LinkButton(if (confirm) "Tap again to delete this game" else "Delete game", {
                if (confirm) onDelete() else confirm = true
            }, Modifier.padding(top = 8.dp), color = RiftColors.Danger)
        }
    }
}

/**
 * Paste a list in the deckbuilder text format (iOS imports the clipboard; the mock lets you see it first).
 * Lines no card matches are listed after the import.
 */
@Composable
fun ImportDialog(pool: List<Card>, onImport: (DeckText.Parsed) -> Unit, onDismiss: () -> Unit) {
    var text by remember { mutableStateOf("") }
    var result by remember { mutableStateOf<DeckText.Parsed?>(null) }
    var empty by remember { mutableStateOf(false) }
    val clipboard = LocalClipboard.current
    LaunchedEffect(Unit) {
        // Only an explicit Import reads the clipboard, and only text that looks like a deck list is taken over.
        val clip = clipboard.getClipEntry()?.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.text?.toString().orEmpty()
        if (text.isEmpty() && Regex("(?m)^\\s*\\d+x?\\s+\\S").containsMatchIn(clip)) text = clip
    }
    DialogFrame(onDismiss, fullScreen = false) {
        val done = result
        if (done != null) {
            BasicText("Deck imported", style = RiftType.Body.copy(fontSize = 17.sp, fontWeight = FontWeight.Bold, color = Color.White))
            BasicText(
                "${done.unresolved.size} ${if (done.unresolved.size == 1) "line matched" else "lines matched"} no card. Open the pile to finish the deck.",
                Modifier.padding(top = 6.dp, bottom = 10.dp), style = SheetText,
            )
            BasicText(
                done.unresolved.take(12).joinToString("\n"),
                Modifier.fillMaxWidth().background(Color(0xFF0A0A0A), RoundedCornerShape(16.dp)).padding(12.dp),
                style = RiftType.Body.copy(fontFamily = FontFamily.Monospace, fontSize = 12.sp, lineHeight = 18.sp, fontWeight = FontWeight.Normal, color = Color.White.copy(alpha = 0.8f)),
            )
            WideButton("Done", Modifier.padding(top = 12.dp).fillMaxWidth(), fill = RiftColors.You, ink = Color.Black, onClick = onDismiss)
            return@DialogFrame
        }
        BasicText("Import a deck", style = RiftType.Body.copy(fontSize = 17.sp, fontWeight = FontWeight.Bold, color = Color.White))
        BasicText("Paste a deck list. One card per line with its count.", Modifier.padding(top = 6.dp, bottom = 12.dp), style = SheetText)
        val shape = RoundedCornerShape(16.dp)
        BasicTextField(
            text, { text = it; empty = false },
            Modifier.fillMaxWidth().height(150.dp).background(Color(0xFF0A0A0A), shape).border(1.dp, Color.White.copy(alpha = 0.16f), shape).padding(12.dp)
                .semantics { contentDescription = "Deck list" },
            textStyle = RiftType.Body.copy(fontFamily = FontFamily.Monospace, fontSize = 12.5.sp, lineHeight = 18.75.sp, fontWeight = FontWeight.Normal, color = Color.White),
            cursorBrush = SolidColor(RiftColors.You),
            decorationBox = { field ->
                Box {
                    if (text.isEmpty()) BasicText("Legend:\n1 Jinx, Loose Cannon\n\nMainDeck:\n3 Get Excited!", style = RiftType.Body.copy(fontFamily = FontFamily.Monospace, fontSize = 12.5.sp, lineHeight = 18.75.sp, color = Color.White.copy(alpha = 0.35f)))
                    field()
                }
            },
        )
        if (empty) BasicText("No cards found in this text.", Modifier.padding(top = 8.dp), style = SheetText.copy(color = RiftColors.Gold))
        Row(Modifier.fillMaxWidth().padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            WideButton("Cancel", Modifier.weight(1f), onClick = onDismiss)
            WideButton(if (pool.isEmpty()) "Loading cards…" else "Import", Modifier.weight(1f), fill = RiftColors.You, ink = Color.Black, enabled = text.isNotBlank() && pool.isNotEmpty()) {
                val parsed = DeckText.parse(text, pool)
                when {
                    parsed.isEmpty -> empty = true
                    else -> {
                        onImport(parsed)
                        if (parsed.unresolved.isEmpty()) onDismiss() else result = parsed
                    }
                }
            }
        }
    }
}
