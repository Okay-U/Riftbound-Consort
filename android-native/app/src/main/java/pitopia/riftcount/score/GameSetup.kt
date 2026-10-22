package pitopia.riftcount.score

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import pitopia.riftcount.cards.Card
import pitopia.riftcount.cards.SearchField
import pitopia.riftcount.data.Decklist
import pitopia.riftcount.decks.Mini
import pitopia.riftcount.decks.OnOffChip
import pitopia.riftcount.decks.PickRow
import pitopia.riftcount.decks.SheetText
import pitopia.riftcount.decks.SheetTitle
import pitopia.riftcount.ui.common.Sheet
import pitopia.riftcount.ui.theme.RiftType

private val Label = RiftType.Caption.copy(fontSize = 10.5.sp, letterSpacing = 0.14.em, color = Color.White.copy(alpha = 0.6f))

/** Your deck and the turn order (iOS `GameSetupSheet`): the deck names your half and goes into the match log. */
@Composable
fun DeckPickSheet(c: ScoreController, decks: List<Decklist>, index: Map<String, Card>, onDismiss: () -> Unit) {
    Sheet("Your deck", onDismiss) { close ->
        BasicText("Your deck", style = SheetTitle)
        BasicText("Its legend names your half; finished games go into its match log.", Modifier.padding(top = 4.dp, bottom = 12.dp), style = SheetText)
        PickRow("No deck", "Games count for all decks only", c.deckId.isEmpty()) {
            c.pickDeck("")
            close()
        }
        decks.forEach { d ->
            val legend = d.legend?.let { index[it.cardId] }
            PickRow(d.name, legend?.name ?: "No legend yet", c.deckId.equals(d.id, true), leading = { Mini(legend) }) {
                c.pickDeck(d.id)
                close()
            }
        }
        if (decks.isEmpty()) BasicText("No decks yet: build one on the Decks tab.", style = SheetText)
        BasicText("TURN ORDER", Modifier.padding(top = 10.dp, bottom = 8.dp), style = Label)
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            OnOffChip("Unknown", c.turnOrder.isEmpty(), Color.White, 34.dp) { c.pickTurnOrder("") }
            OnOffChip("Going first", c.turnOrder == "first", Color.White, 34.dp) { c.pickTurnOrder("first") }
            OnOffChip("Going second", c.turnOrder == "second", Color.White, 34.dp) { c.pickTurnOrder("second") }
        }
        Spacer(Modifier.height(4.dp))
    }
}

/** The opponent's legend, searchable; one row per legend (printings folded, like the iOS picker). */
@Composable
fun OpponentPickSheet(c: ScoreController, legends: List<String>, pool: List<Card>, onDismiss: () -> Unit) {
    var query by remember { mutableStateOf("") }
    val art = remember(pool) { pool.filter { it.isRareLegend }.associateBy { it.name } }
    Sheet("Opponent's legend", onDismiss) { close ->
        BasicText("Opponent's legend", style = SheetTitle)
        BasicText("Names their half and the game in the match log.", Modifier.padding(top = 4.dp), style = SheetText)
        SearchField(query, placeholder = "Search legends", inset = 0.dp) { query = it }
        Spacer(Modifier.height(12.dp))
        if (query.isBlank()) {
            PickRow("Unknown", null, c.opponent.isBlank()) {
                c.pickOpponent("")
                close()
            }
        }
        if (legends.isEmpty()) BasicText("Loading the card list…", style = SheetText)
        legends.filter { query.isBlank() || it.contains(query.trim(), true) }.forEach { name ->
            val card = art[name]
            PickRow(name, card?.domains?.joinToString(" · "), c.opponent == name, leading = { Mini(card) }) {
                c.pickOpponent(name)
                close()
            }
        }
    }
}
