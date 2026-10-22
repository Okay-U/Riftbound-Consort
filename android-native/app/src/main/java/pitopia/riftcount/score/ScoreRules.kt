package pitopia.riftcount.score

import kotlinx.serialization.Serializable
import pitopia.riftcount.data.ScoreEvent

/** Points to win a game in a duel. */
const val TARGET = 8
/** How long after a game its loser is asked who starts the next one; later the question is stale. */
const val START_CHOICE_MS = 10 * 60_000L
private const val UNDO_DEPTH = 50
private const val XP_MAX = 99

/** 2 players: slot 0 is the opponent (top, rotated), slot 1 is you. 4 players: slots 0-1 top, 2-3 bottom. */
const val YOU = 1
const val OPPONENT = 0

enum class PointKind(val eventType: String) { Conquer("conquer"), Hold("hold"), Effect("manual") }

@Serializable
data class Player(val score: Int = 0, val xp: Int = 0)

@Serializable
data class Snapshot(val scores: List<Int>, val xps: List<Int>, val events: List<ScoreEvent>)

/** A finished game of the match; [winner] is a slot or -1 for a draw, [scores] null when set by hand. */
@Serializable
data class GameResult(val winner: Int, val scores: List<Int>? = null)

/**
 * The scoreboard, immutable: every action returns a new state. Rules follow the iOS app (undo of
 * 50 steps including XP, a score never below 0, unchanged scores are not recorded) and the chosen mock
 * (a duel ends at 8, the 8th point by conquering is asked for). Always casual, every game on its own; a
 * series (best of 1 or 3, its summary and report) only for a live PlayRiftbound match (Okay, 2026-10-22).
 */
@Serializable
data class ScoreState(
    val players: List<Player> = List(2) { Player() },
    val events: List<ScoreEvent> = emptyList(),
    val history: List<Snapshot> = emptyList(),
    val log: List<GameResult> = emptyList(),
    val gameNo: Int = 1,
    val winner: Int = -1,
    val asking: Int = -1,
    val starter: Int = -1,
    val clock: MatchClock = MatchClock(),
    val lastGameEndSeconds: Int = 0,
    /** The match was ended by hand ("End the match"): the summary shows, scoring stops. */
    val ended: Boolean = false,
    /** 0 casual; 1 or 3 a best-of match with its series, summary and report. */
    val bestOf: Int = 0,
    /** The PlayRiftbound pairing ("R3 · T5") this match was started for; null for any other. */
    val liveTag: String? = null,
    /** The last game's loser, who picks who starts this one (Riftbound's rule); -1 once picked or played. */
    val chooser: Int = -1,
    /** When [chooser] was asked (wall clock); a state saved without it never asks again. */
    val chooserSinceMs: Long = 0,
) {
    val isDuel get() = players.size == 2
    val isSeries get() = isDuel && bestOf > 0
    /** Games to win the match: one of a best of one, two of a best of three. */
    val winsNeeded get() = (bestOf + 1) / 2
    val gameOver get() = winner >= 0
    val matchOver get() = isSeries && seriesWins().any { it >= winsNeeded }
    val canUndo get() = history.isNotEmpty() && !gameOver && !ended
    val showSummary get() = matchOver || ended

    /**
     * Who is asked who starts, or -1: only within [START_CHOICE_MS] of the last game, so coming back to the
     * board hours later does not find the question still open (Okay, 2026-10-22).
     */
    fun startChooser(nowMs: Long): Int = if (chooser >= 0 && nowMs - chooserSinceMs < START_CHOICE_MS) chooser else -1

    fun seriesWins(): List<Int> = List(players.size) { slot -> log.count { it.winner == slot } }

    /** Conquer, Hold or a card effect for [slot]; the 8th point by conquering waits for [confirmFinalPoint]. */
    fun score(slot: Int, kind: PointKind, nowMs: Long): ScoreState {
        if (gameOver || matchOver || ended) return this
        if (isDuel && kind == PointKind.Conquer && players[slot].score == TARGET - 1) return copy(asking = slot)
        return commit(slot, 1, kind.eventType, nowMs)
    }

    fun confirmFinalPoint(scoreIt: Boolean, nowMs: Long): ScoreState {
        val slot = asking
        val cleared = copy(asking = -1)
        return if (scoreIt && slot >= 0) cleared.commit(slot, 1, PointKind.Conquer.eventType, nowMs) else cleared
    }

    /** "Fix": take a point back by hand. */
    fun fix(slot: Int, nowMs: Long): ScoreState = commit(slot, -1, "manual", nowMs)

    private fun commit(slot: Int, delta: Int, type: String, nowMs: Long): ScoreState {
        if (gameOver && delta > 0) return this
        val old = players[slot].score
        val new = maxOf(0, old + delta)
        if (new == old) return this
        val clockNow = if (clock.isRunning || clock.elapsedSeconds(nowMs) > 0) clock else clock.start(nowMs)
        val event = ScoreEvent(elapsedSeconds = clockNow.elapsedSeconds(nowMs), slot = slot, type = type, delta = new - old)
        val next = copy(
            players = players.mapIndexed { i, p -> if (i == slot) p.copy(score = new) else p },
            events = events + event,
            history = pushed(),
            asking = -1,
            chooser = -1,
            clock = clockNow,
        )
        return if (isDuel && new >= TARGET && !gameOver) next.copy(winner = slot, log = log + GameResult(slot, next.players.map { it.score })) else next
    }

    fun xp(slot: Int, delta: Int): ScoreState {
        val new = (players[slot].xp + delta).coerceIn(0, XP_MAX)
        return copy(players = players.mapIndexed { i, p -> if (i == slot) p.copy(xp = new) else p }, history = pushed())
    }

    fun undo(): ScoreState {
        if (!canUndo) return this
        val last = history.last()
        if (last.scores.size != players.size) return copy(history = emptyList())
        return copy(
            players = players.mapIndexed { i, p -> p.copy(score = last.scores[i], xp = last.xps[i]) },
            events = last.events,
            history = history.dropLast(1),
            asking = -1,
        )
    }

    /** Scores and XP back to 0 in the same game; undoable like the iOS reset. The match clock keeps running. */
    fun restart(): ScoreState {
        if (gameOver || matchOver || ended) return this
        return copy(players = players.map { Player() }, events = emptyList(), history = pushed(), asking = -1)
    }

    /** After a won game: the next one. A series keeps its games, a casual game nothing; the clock runs on (iOS). */
    fun nextGame(nowMs: Long): ScoreState {
        if (!gameOver || matchOver || ended) return this
        return copy(
            players = players.map { Player() }, events = emptyList(), history = emptyList(),
            log = if (isSeries) log else emptyList(),
            gameNo = gameNo + 1, winner = -1, asking = -1, starter = -1, chooser = if (isDuel) 1 - winner else -1, chooserSinceMs = nowMs,
            lastGameEndSeconds = clock.elapsedSeconds(nowMs),
        )
    }

    fun newMatch(): ScoreState = ScoreState(players = List(players.size) { Player() })

    /** One ↔ three games in a live match: the event's setting is not always what the table plays. */
    fun withBestOf(n: Int): ScoreState = if (isSeries && (n == 1 || n == 3) && !ended) copy(bestOf = n) else this

    /** A fresh match for a PlayRiftbound pairing in the event's format; who goes first stays as rolled. */
    fun startLive(tag: String, bestOf: Int): ScoreState =
        ScoreState(players = List(players.size) { Player() }, starter = starter, bestOf = if (bestOf == 1) 1 else 3, liveTag = tag)

    fun withPlayerCount(count: Int): ScoreState {
        val n = if (count == 4) 4 else 2
        if (n == players.size) return this
        return ScoreState(players = List(n) { players.getOrNull(it) ?: Player() }, clock = clock)
    }

    fun withStarter(slot: Int, nowMs: Long): ScoreState =
        copy(starter = slot, chooser = -1, clock = if (clock.isRunning) clock else clock.start(nowMs))

    fun toggleClock(nowMs: Long): ScoreState = copy(clock = if (clock.isRunning) clock.pause(nowMs) else clock.start(nowMs))

    /** Seconds this game took: match clock minus the end of the previous game (iOS `lastGameEnd`). */
    fun gameSeconds(nowMs: Long): Int {
        val now = clock.elapsedSeconds(nowMs)
        return if (now >= lastGameEndSeconds) now - lastGameEndSeconds else now
    }

    private fun pushed(): List<Snapshot> =
        (history + Snapshot(players.map { it.score }, players.map { it.xp }, events)).takeLast(UNDO_DEPTH)
}

/** Stopwatch for the whole match that survives restarts: accumulated time plus the running stretch. */
@Serializable
data class MatchClock(val accumulatedMs: Long = 0, val runningSinceMs: Long? = null) {
    val isRunning get() = runningSinceMs != null
    fun elapsedMs(nowMs: Long): Long = accumulatedMs + (runningSinceMs?.let { (nowMs - it).coerceAtLeast(0) } ?: 0)
    fun elapsedSeconds(nowMs: Long): Int = (elapsedMs(nowMs) / 1000).toInt()
    fun start(nowMs: Long) = if (isRunning) this else copy(runningSinceMs = nowMs)
    fun pause(nowMs: Long) = if (!isRunning) this else MatchClock(accumulatedMs = elapsedMs(nowMs))
}

fun clockText(seconds: Int): String = "%02d:%02d".format(seconds / 60, seconds % 60)
