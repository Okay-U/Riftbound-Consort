package pitopia.riftcount.decks

import pitopia.riftcount.cards.Card
import pitopia.riftcount.data.DeckRules
import pitopia.riftcount.data.Decklist
import pitopia.riftcount.data.DecklistEntry

/** Changes made right in the deck detail (iOS `DeckDetailView`), each returning the new deck. */
object DeckEdits {
    fun entries(deck: Decklist, pile: Pile) = if (pile == Pile.Main) deck.mainDeck else deck.sideDeck

    /** iOS `canIncrement`: pile size, three copies of a card across main, side and champion, three signatures. */
    fun canAdd(deck: Decklist, pile: Pile, card: Card, cards: Map<String, Card>): Boolean = when {
        pile == Pile.Main && deck.mainDeck.sumOf { it.count } >= DeckRules.MAIN -> false
        pile == Pile.Side && deck.sideDeck.sumOf { it.count } >= Builder.SIDE -> false
        DeckRules.copies(deck, card, cards) >= DeckRules.COPY_LIMIT -> false
        card.isSignature && DeckRules.signatures(deck, cards) >= DeckRules.SIGNATURE_LIMIT -> false
        else -> true
    }

    fun step(deck: Decklist, pile: Pile, entry: DecklistEntry, delta: Int, nowMs: Long): Decklist {
        val list = entries(deck, pile).mapNotNull {
            if (it.cardId == entry.cardId) it.copy(count = it.count + delta).takeIf { e -> e.count > 0 } else it
        }
        val next = if (pile == Pile.Main) deck.copy(mainDeck = list) else deck.copy(sideDeck = list)
        return next.copy(updatedAt = nowMs)
    }

    /** Runes of a legend domain: the printing already in the deck changes, a new one is the domain's rune card. */
    fun rune(deck: Decklist, domain: String, delta: Int, pool: List<Card>, cards: Map<String, Card>, nowMs: Long): Decklist {
        val total = deck.runes.sumOf { it.count }
        if (delta > 0 && total >= DeckRules.RUNES) return deck
        val mine = deck.runes.filter { e -> cards[e.cardId]?.domains?.any { it.equals(domain, true) } == true }
        val runes = when {
            delta > 0 && mine.isNotEmpty() -> deck.runes.map { if (it.cardId == mine.first().cardId) it.copy(count = it.count + 1) else it }
            delta > 0 -> DeckRules.runeCard(domain, pool)?.let { deck.runes + DecklistEntry(it.id, it.name, 1) } ?: return deck
            mine.isEmpty() -> return deck
            else -> deck.runes.mapNotNull { if (it.cardId == mine.last().cardId) it.copy(count = it.count - 1).takeIf { e -> e.count > 0 } else it }
        }
        return deck.copy(runes = runes, updatedAt = nowMs)
    }

    fun runeCount(deck: Decklist, domain: String, cards: Map<String, Card>) =
        deck.runes.filter { e -> cards[e.cardId]?.domains?.any { it.equals(domain, true) } == true }.sumOf { it.count }

    /**
     * A new chosen champion. One already in the main or side deck swaps places with the old one (iOS
     * `swapChampion`, the card count stays); any other replaces it.
     */
    fun champion(deck: Decklist, card: Card, nowMs: Long): Decklist {
        val old = deck.champion
        if (old?.cardId == card.id) return deck
        val entry = DecklistEntry(card.id, card.name, 1)
        val inMain = deck.mainDeck.any { it.cardId == card.id }
        val inSide = deck.sideDeck.any { it.cardId == card.id }
        if (!inMain && !inSide) return deck.copy(champion = entry, updatedAt = nowMs)
        val pile = if (inMain) Pile.Main else Pile.Side
        var next = step(deck, pile, entry, -1, nowMs)
        // The old champion takes the freed place in the same pile, so main and side keep their size.
        if (old != null) {
            val list = entries(next, pile)
            val back = if (list.any { it.cardId == old.cardId }) {
                list.map { if (it.cardId == old.cardId) it.copy(count = it.count + 1) else it }
            } else {
                list + old.copy(count = 1)
            }
            next = if (pile == Pile.Main) next.copy(mainDeck = back) else next.copy(sideDeck = back)
        }
        return next.copy(champion = entry, updatedAt = nowMs)
    }

    /** null when three are chosen already and [card] is not one of them. */
    fun toggleBattlefield(deck: Decklist, card: Card, nowMs: Long): Decklist? = when {
        deck.battlefields.any { it.cardId == card.id } -> deck.copy(battlefields = deck.battlefields.filterNot { it.cardId == card.id }, updatedAt = nowMs)
        deck.battlefields.sumOf { it.count } >= DeckRules.BATTLEFIELDS -> null
        else -> deck.copy(battlefields = deck.battlefields + DecklistEntry(card.id, card.name, 1), updatedAt = nowMs)
    }
}
