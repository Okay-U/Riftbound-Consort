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

/**
 * Picker behind "End the match" and "Set them yourself": one result per game (1 you, 0 opponent, -1 draw),
 * as many games as the format has; [need] wins decide it.
 */
data class ResultPicker(val ending: Boolean, val picks: List<Int?>, val need: Int) {
    fun decidedAt(): Int {
        var me = 0
        var them = 0
        picks.forEachIndexed { i, v ->
            if (v == null) return -1
            if (v == YOU) me++
            if (v == OPPONENT) them++
            if (me >= need || them >= need) return i
        }
        return -1
    }

    fun locked(i: Int) = (i > 0 && picks[i - 1] == null) || decidedAt().let { it >= 0 && i > it }

    fun choose(i: Int, v: Int) =
        copy(picks = picks.mapIndexed { j, old -> if (j == i) (if (old == v) null else v) else if (j > i) null else old })
}

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
    var picker by mutableStateOf<ResultPicker?>(null)
        private set
    var toast by mutableStateOf<Toast?>(null)
        private set
    var drew by mutableStateOf(-1)
        private set
    var confirmRestart by mutableStateOf(false)
        private set
    /** The series this scoreboard reported to PlayRiftbound; in memory only, any other series is not it. */
    var sentReport by mutableStateOf<SentReport?>(null)
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
    fun toggleClock() = apply(state.toggleClock(now()), Haptic.Tick)
    fun nextGame() = apply(state.nextGame(now()), Haptic.Tick)

    /** The event says one game but the table plays three: game 1 no longer ends the live match. */
    fun playBestOfThree() {
        apply(state.withBestOf(3), Haptic.Tick)
        if (state.bestOf == 3) show("Best of 3 · first to two games")
    }

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

    /** "Start match" in the seam: a fresh match for the PlayRiftbound pairing, in its event's format. */
    fun startLive(link: TableLink) {
        picker = null
        sentReport = null
        closeDuel()
        apply(state.startLive(link.tag, link.bestOf), Haptic.Success)
        show("Live match · ${link.tag} · best of ${state.bestOf}")
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

    fun askRestart() { if (!state.gameOver && !state.matchOver && !state.ended) confirmRestart = true }
    fun cancelRestart() { confirmRestart = false }
    fun restart() { confirmRestart = false; apply(state.restart(), Haptic.Warning) }

    fun newMatch() {
        picker = null
        // The next series may end with the same games; it is not reported until it is sent.
        sentReport = null
        apply(state.newMatch(), Haptic.Warning)
    }

    /** From Settings: an open who-goes-first duel has one die per seat, so it closes. */
    fun setPlayers(count: Int) {
        closeDuel()
        Prefs.put("playerCount", count)
        apply(state.withPlayerCount(count), null)
    }

    // --- ending a match by hand ------------------------------------------------------------------

    /** End or set the results of a live series, one row per game it can have. */
    fun openPicker(ending: Boolean) {
        val s = state
        if (!s.isSeries) return
        picker = ResultPicker(ending, List(s.bestOf) { i -> s.log.getOrNull(i)?.winner }, s.winsNeeded)
    }

    fun choose(i: Int, v: Int) { picker = picker?.choose(i, v) }
    fun closePicker() { picker = null }

    fun pickDone() {
        val p = picker ?: return
        val set = p.picks.takeWhile { it != null }.filterNotNull()
        if (set.isEmpty()) return
        val playing = state.log.size
        val log = set.mapIndexed { i, w -> state.log.getOrNull(i)?.takeIf { it.winner == w } ?: GameResult(w) }
        // The game being played when the match was ended counts too (a concession), like iOS Won/Lost.
        if (set.size > playing && !state.gameOver && set[playing] != -1) record(set[playing], state)
        picker = null
        apply(state.copy(log = log, ended = true, asking = -1), Haptic.Success)
    }

    // --- who goes first ----------------------------------------------------------------------------

    fun openDuel() {
        stopTumbles()
        picker = null
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
    fun reported(r: SentReport) { sentReport = r }
    /** Only while the games on the board are the ones sent. */
    fun reportedSeries(): SentReport? = sentReport?.takeIf { it.log == state.log }
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
        // A best of three started by hand (an earlier test build) reads as casual: series are for live matches only.
        val casual = saved?.takeIf { it.bestOf > 0 && it.liveTag == null }?.copy(bestOf = 0, log = emptyList())
        return (casual ?: saved ?: ScoreState()).withPlayerCount(Prefs.int("playerCount", 2))
    }

    companion object {
        private const val STATE_KEY = "native.scoreboard"

        /** "Darius - Hand of Noxus" or "Darius, Hand of Noxus" reads "Darius · Hand of Noxus". */
        fun displayName(card: String): String =
            card.replace(Regex("\\s*\\(.*?\\)\\s*$"), "").replace(" - ", " · ").replaceFirst(", ", " · ").trim()
    }
}
