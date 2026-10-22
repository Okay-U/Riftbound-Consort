package pitopia.riftcount.decks

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import pitopia.riftcount.cards.Card
import pitopia.riftcount.data.DeckRules

/** What the Decks tab keeps while another tab is open: a half-built deck must survive a look at the cards. */
class DecksUi {
    var draft by mutableStateOf<Draft?>(null)
        private set
    var step by mutableStateOf(BuildStep.Legend)

    /** A card from the Cards tab that joins the deck once a legend it fits is picked. */
    var pending by mutableStateOf<Card?>(null)
        private set

    /** New deck; a legend starts it, any other card waits for a legend it fits. */
    fun startBuilder(card: Card? = null) {
        pending = null
        when {
            card == null -> { draft = Draft(); step = BuildStep.Legend }
            card.isLegend -> { draft = Builder.pickLegend(Draft(), card); step = BuildStep.Champion }
            else -> { draft = Draft(); step = BuildStep.Legend; pending = card }
        }
    }

    fun edit(d: Draft) {
        pending = null
        draft = d
        step = BuildStep.Main
    }

    fun update(d: Draft) {
        draft = d
    }

    /** The legend pick, with the waiting card added when it fits; returns a note for the toast. */
    fun pickLegend(legend: Card): String? {
        var d = Builder.pickLegend(draft ?: Draft(), legend)
        val card = pending ?: run { draft = d; return null }
        val champion = card.isChampion && DeckRules.matchesLegend(card, legend)
        val fits = champion || DeckRules.eligible(card, d.domains.map { it.lowercase() }.toSet())
        if (champion) d = Builder.pickChampion(d, card) else if (fits) d = Builder.add(d, Pile.Main, card)
        draft = d
        if (fits) pending = null
        return if (fits) "${card.title} is in the deck" else "${card.title} does not fit ${legend.title}'s domains"
    }

    fun close() {
        draft = null
        pending = null
        step = BuildStep.Legend
    }
}
