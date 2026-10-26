package pitopia.riftcount.score

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlin.random.Random
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import pitopia.riftcount.data.DecklistStore
import pitopia.riftcount.data.GameRecord
import pitopia.riftcount.data.GameRecordStore
import pitopia.riftcount.data.Prefs
import pitopia.riftcount.data.SwiftJson
import pitopia.riftcount.platform.Haptic

data class Toast(val text: String, val id: Long = System.nanoTime())

class ScoreController(
    private val scope: CoroutineScope,
    private val games: GameRecordStore,
    private val decks: DecklistStore,
    private val now: () -> Long = System::currentTimeMillis,
    private val random: Random = Random.Default,
) {
    var state by mutableStateOf(restore())
        private set
    var duel by mutableStateOf<DuelState?>(null)
        private set
    var toast by mutableStateOf<Toast?>(null)
        private set
    var drew by mutableStateOf(-1)
        private set
    /** The seam's game menu: won, lost or restart. */
    var gameMenu by mutableStateOf(false)
        private set

    /** Set by the screen so actions can buzz through the current view. */
    var haptic: (Haptic) -> Unit = {}

    private val tumbles = mutableListOf<Job>()
    private var drewJob: Job? = null

    // --- names from the active deck and the opponent's legend ---------------------------------

    /** The game setup (iOS `GameSetupSheet`), kept in the Skip app's keys; state so the halves rename at once. */
    var deckId by mutableStateOf(Prefs.string("activeDeckId", ""))
        private set
    var opponent by mutableStateOf(Prefs.string("activeOpponent", ""))
        private set
    /** "first", "second" or "" (unknown); the dice duel sets it too. */
    var turnOrder by mutableStateOf(Prefs.string("activeStartedFirst", ""))
        private set

    /** The half whose setup sheet is open (tap its name), -1 when none. */
    var setupSlot by mutableIntStateOf(-1)
        private set

    fun openSetup(slot: Int) {
        if (state.isDuel) setupSlot = slot
    }

    fun closeSetup() {
        setupSlot = -1
    }

    fun pickDeck(id: String) {
        deckId = id
        Prefs.put("activeDeckId", id)
    }

    fun pickOpponent(name: String) {
        opponent = name
        Prefs.put("activeOpponent", name)
    }

    fun pickTurnOrder(value: String) {
        turnOrder = value
        Prefs.put("activeStartedFirst", value)
    }

    fun legend(slot: Int): String = when {
        !state.isDuel -> "Player ${slot + 1}"
        slot == YOU -> decks.find(deckId)?.legend?.cardName?.let(::displayName) ?: "You"
        else -> opponent.trim().takeIf { it.isNotEmpty() }?.let(::displayName) ?: "Opponent"
    }

    /** First name for sentences: "Darius starts", "You start". */
    fun shortName(slot: Int): String = legend(slot).substringBefore(" · ")

    // --- scoring ---------------------------------------------------------------------------------

    fun score(slot: Int, kind: PointKind) = apply(state.score(slot, kind, now()), Haptic.Tick)
    fun fix(slot: Int) = apply(state.fix(slot, now()), Haptic.Tick)
    fun xp(slot: Int, delta: Int) = apply(state.xp(slot, delta), Haptic.Tick)
    fun undo() = apply(state.undo(), Haptic.Undo)
    fun nextGame() = apply(state.nextGame(now()), Haptic.Tick)

    /** Whose half asks who starts, or -1 (the question goes stale after a while). */
    fun startChooser(): Int = state.startChooser(now())

    /** The last game's loser goes first or second. */
    fun pickStart(first: Boolean) {
        val chooser = state.chooser
        if (chooser < 0) return
        val starter = if (first) chooser else 1 - chooser
        pickTurnOrder(if (starter == YOU) "first" else "second")
        apply(state.withStarter(starter, now()), Haptic.Success)
        show(startsText(starter))
    }

    fun finalPoint(scoreIt: Boolean) {
        val slot = state.asking
        apply(state.confirmFinalPoint(scoreIt, now()), Haptic.Tick)
        if (!scoreIt && slot >= 0) {
            drew = slot
            drewJob?.cancel()
            drewJob = scope.launch { delay(2400); drew = -1 }
        }
    }

    fun openGameMenu() { if (!state.gameOver) gameMenu = true }
    fun closeGameMenu() { gameMenu = false }
    fun restart() { gameMenu = false; apply(state.restart(), Haptic.Warning) }

    /** Won or lost by hand, like iOS's classic buttons: the game is recorded and Next game shows. */
    fun end(winner: Int) { gameMenu = false; apply(state.end(winner), null) }

    /** From Settings: an open who-goes-first duel has one die per seat, so it closes. */
    fun setPlayers(count: Int) {
        closeDuel()
        Prefs.put("playerCount", count)
        apply(state.withPlayerCount(count), null)
    }

    // --- who goes first ----------------------------------------------------------------------------

    fun openDuel() {
        stopTumbles()
        duel = DuelState.start(state.players.size)
    }

    fun closeDuel() { stopTumbles(); duel = null }

    fun duelType(type: DieType) {
        val d = duel ?: return
        if (d.busy) return
        stopTumbles()
        duel = DuelState.start(d.dice.size, type)
    }

    fun rollAll() { duel?.dice?.indices?.forEach(::roll) }

    fun roll(slot: Int) {
        val d = duel ?: return
        if (!d.canRoll(slot)) return
        duel = d.rolling(slot)
        val sides = d.type.sides
        val final = 1 + random.nextInt(sides)
        tumbles += scope.launch {
            DuelState.tumbleWaits.forEachIndexed { i, wait ->
                delay(wait)
                val cur = duel ?: return@launch
                val last = i == DuelState.tumbleWaits.lastIndex
                val face = if (last) final else DuelState.face(sides, cur.dice[slot].value, random)
                duel = cur.shown(slot, face, done = last)
                haptic(if (last) Haptic.Success else Haptic.Tick)
            }
            if (duel?.tie == true) {
                delay(1600)
                duel = duel?.rerolled()
            }
        }
    }

    /** The winner of the roll picks first or second, and the game starts (no second question). */
    fun choose(choice: DuelState.Choice) {
        duel = duel?.copy(choice = choice) ?: return
        startGame()
    }

    fun rollAgain() { val d = duel ?: return; stopTumbles(); duel = DuelState.start(d.dice.size, d.type) }

    fun startGame() {
        val d = duel ?: return
        val starter = d.starter()
        if (starter < 0) return
        stopTumbles()
        duel = null
        if (state.isDuel) pickTurnOrder(if (starter == YOU) "first" else "second")
        apply(state.withStarter(starter, now()), Haptic.Success)
        show(startsText(starter))
    }

    private fun startsText(starter: Int) =
        if (state.isDuel && starter == YOU && legend(YOU) == "You") "You start · good game" else "${shortName(starter)} starts · good game"

    private fun stopTumbles() { tumbles.forEach { it.cancel() }; tumbles.clear() }

    // --- plumbing ----------------------------------------------------------------------------------

    fun show(text: String) { toast = Toast(text) }
    fun clearToast(id: Long) { if (toast?.id == id) toast = null }

    private fun apply(next: ScoreState, buzz: Haptic?) {
        if (next == state) return
        val wonNow = !state.gameOver && next.gameOver
        state = next
        Prefs.put(STATE_KEY, SwiftJson.encodeToString(ScoreState.serializer(), next))
        if (wonNow) { record(next.winner, next); haptic(Haptic.Success) } else buzz?.let(haptic)
    }

    /** The finished game into `games.json`, from your side (slot 1), like iOS Won/Lost. */
    private fun record(winner: Int, s: ScoreState) {
        if (!s.isDuel) return
        val deck = decks.find(deckId)
        val startedFirst = if (s.starter >= 0) s.starter == YOU else when (turnOrder) {
            "first" -> true
            "second" -> false
            else -> null
        }
        games.record(
            GameRecord(
                date = now(), deckId = deck?.id, deckName = deck?.name,
                opponent = opponent.trim(),
                result = if (winner == YOU) "won" else "lost",
                durationSeconds = s.gameSeconds(now()), events = s.events, startedFirst = startedFirst,
            ),
        )
    }

    private fun restore(): ScoreState {
        val saved = runCatching { SwiftJson.decodeFromString(ScoreState.serializer(), Prefs.string(STATE_KEY, "")) }.getOrNull()
        return (saved ?: ScoreState()).withPlayerCount(Prefs.int("playerCount", 2))
    }

    companion object {
        private const val STATE_KEY = "native.scoreboard"

        /** "Darius - Hand of Noxus" or "Darius, Hand of Noxus" reads "Darius · Hand of Noxus". */
        fun displayName(card: String): String =
            card.replace(Regex("\\s*\\(.*?\\)\\s*$"), "").replace(" - ", " · ").replaceFirst(", ", " · ").trim()
    }
}
