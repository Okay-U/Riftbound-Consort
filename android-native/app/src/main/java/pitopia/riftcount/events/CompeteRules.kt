package pitopia.riftcount.events

import kotlin.math.ceil
import kotlin.math.log2
import pitopia.riftcount.events.Tournament.Match
import pitopia.riftcount.events.Tournament.Participant
import pitopia.riftcount.events.Tournament.Round
import pitopia.riftcount.events.Tournament.Standing

/**
 * What the screens read out of a tournament, iOS `CompeteTournament` extensions. Top cut, 2v2 and
 * PENDING follow the site's client code (2026-10-20); see docs/PLAYRIFTBOUND.md.
 */

/** Rounds players can see, section by section (Swiss, then a top cut), PENDING ones hidden like on the site. */
val Tournament.rounds: List<Round>
    get() = stages.flatMap { it.sections }.flatMapIndexed { index, section ->
        section.rounds.filter { it.status?.uppercase() != "PENDING" }.sortedBy { it.number }.map { it.copy(sectionIndex = index) }
    }

/** Every match in the bracket, published or not, for name and team lookups. */
private val Tournament.allMatches: List<Match> get() = stages.flatMap { it.sections }.flatMap { it.rounds }.flatMap { it.matches }

private val Tournament.participants: List<Participant> get() = tournamentParticipants.orEmpty()

fun Tournament.participant(teamId: String): Participant? = participants.firstOrNull { it.esportsTeamId == teamId }

fun Tournament.participantOf(playerId: String): Participant? = participants.firstOrNull { it.player?.id == playerId }

fun Tournament.teamId(playerId: String): String? =
    participantOf(playerId)?.esportsTeamId
        ?: allMatches.asSequence().flatMap { it.teams }.firstOrNull { t -> t.players.any { it.id == playerId } }?.esportsTeamId

/** "Ann & Bo" in 2v2: the team's players from the participant list and the first match it played. */
fun Tournament.teamName(teamId: String): String {
    val listed = participants.filter { it.esportsTeamId == teamId }.mapNotNull { it.player?.displayName }
    val played = allMatches.asSequence().flatMap { it.teams }.firstOrNull { it.esportsTeamId == teamId }?.players?.mapNotNull { it.displayName }.orEmpty()
    val names = listed + played.filterNot { it in listed }
    return if (names.isEmpty()) "Player" else names.joinToString(" & ")
}

/** Swiss rounds the event plans: the configured count, else the site's default of ceil(log2(teams)). */
val Tournament.plannedSwissRounds: Int
    get() {
        config?.roundCount?.takeIf { it > 0 }?.let { return it }
        val teams = participants.mapNotNull { it.esportsTeamId }.toSet().size
        return if (teams > 1) ceil(log2(teams.toDouble())).toInt() else 0
    }

/** Single elimination: every round of a SINGLE_ELIM event, a later section, or past the planned Swiss rounds. */
fun Tournament.isElimination(round: Round): Boolean = when (config?.structure?.uppercase()) {
    "SINGLE_ELIM" -> true
    "SWISS_PLUS_SINGLE_ELIM" -> round.sectionIndex > 0 || (plannedSwissRounds > 0 && round.number > plannedSwissRounds)
    else -> round.sectionIndex > 0
}

val Tournament.swissRounds: List<Round> get() = rounds.filterNot { isElimination(it) }

/** Players a bracket round starts with, rounded up to the bracket size: 8 for a quarterfinal. */
private fun bracketSize(round: Round): Int {
    val players = round.matches.size * 2 + round.byeTeamIds.orEmpty().size
    return if (players <= 2) 2 else 1 shl ceil(log2(players.toDouble())).toInt()
}

/** "Round 3"; in a bracket the stage: "Quarterfinal", "Semifinal", "Final", "Top 16". */
fun Tournament.title(round: Round): String {
    if (!isElimination(round)) return "Round ${round.number}"
    return when (val size = bracketSize(round)) {
        2 -> "Final"
        4 -> "Semifinal"
        8 -> "Quarterfinal"
        else -> "Top $size"
    }
}

/** Chip label: "R3", "QF", "SF", "F", "T16". */
fun Tournament.shortTitle(round: Round): String {
    if (!isElimination(round)) return "R${round.number}"
    return when (val size = bracketSize(round)) {
        2 -> "F"
        4 -> "SF"
        8 -> "QF"
        else -> "T$size"
    }
}

/** Riot's own test: participants exist once the event runs. */
val Tournament.hasStarted: Boolean get() = participants.isNotEmpty() && stages.isNotEmpty()

/**
 * Over once nothing is left to play: the final of a bracket is in, or the last planned Swiss round has its
 * official table (Riot publishes it when the round is finalised). Not `endsAt`: events run late.
 */
val Tournament.isFinished: Boolean
    get() {
        val last = rounds.lastOrNull() ?: return false
        if (last.matches.isEmpty() || !last.matches.all { it.isComplete }) return false
        if (isElimination(last)) return bracketSize(last) <= 2
        if (config?.structure?.uppercase() == "SWISS_PLUS_SINGLE_ELIM") return false
        return plannedSwissRounds > 0 && swissRounds.size >= plannedSwissRounds && !last.endOfRoundStandings.isNullOrEmpty()
    }

/** The team's row in the last Swiss round's official table; nil until Riot finalises that round. */
fun Tournament.finalSwissStanding(teamId: String): Standing? =
    swissRounds.lastOrNull()?.endOfRoundStandings?.firstOrNull { it.esportsTeamId == teamId }

sealed interface Placement {
    data class Rank(val n: Int) : Placement
    data class Top(val n: Int) : Placement
}

/** Bracket result once the team played in a top cut (`Top(8)` for a quarterfinal loss), else its final Swiss rank. */
fun Tournament.placement(teamId: String): Placement? {
    for (round in rounds.asReversed()) {
        if (!isElimination(round)) continue
        val match = round.matches.firstOrNull { m -> m.teams.any { it.esportsTeamId == teamId } } ?: continue
        val won = match.teamOutcomes.orEmpty().any { it.esportsTeamId == teamId && it.isWin }
        val size = bracketSize(round)
        if (size <= 2) return if (match.isComplete) Placement.Rank(if (won) 1 else 2) else null
        // A won match with no later one: still playing.
        return if (match.isComplete && !won) Placement.Top(size) else null
    }
    return finalSwissStanding(teamId)?.rank?.let { Placement.Rank(it) }
}

enum class PlayerState { None, Registered, Waitlisted, Active, Dropped, Eliminated }

/** Participant status once the event runs (ACTIVE / DROPPED / ELIMINATED), registrant status before. */
fun Tournament.state(playerId: String): PlayerState {
    participantOf(playerId)?.let { p ->
        val s = p.status?.uppercase().orEmpty()
        return when {
            "DROP" in s -> PlayerState.Dropped
            "ELIM" in s -> PlayerState.Eliminated
            else -> PlayerState.Active
        }
    }
    val r = tournamentRegistrants.orEmpty().firstOrNull { it.player?.id == playerId } ?: return PlayerState.None
    val s = r.status?.uppercase() ?: "REGISTERED"
    return when {
        "WAIT" in s -> PlayerState.Waitlisted
        "REGISTER" in s && "UNREGISTER" !in s && "DEREGISTER" !in s -> PlayerState.Registered
        "CHECK" in s -> PlayerState.Registered
        else -> PlayerState.None
    }
}

/**
 * Compete player id for a Riot ID. Riot IDs are unique only with the tag: an exact name + tag match wins;
 * a name alone only when nobody else in the event has it. Nil when ambiguous.
 */
fun Tournament.playerId(gameName: String, tagLine: String?): String? {
    val byId = LinkedHashMap<String, Tournament.RegistrantPlayer>()
    (tournamentRegistrants.orEmpty().mapNotNull { it.player } + participants.mapNotNull { it.player }).forEach { byId.putIfAbsent(it.id, it) }
    val named = byId.values.filter { it.displayName.equals(gameName, ignoreCase = true) }
    if (tagLine != null) {
        val exact = named.filter { it.tagLine.equals(tagLine, ignoreCase = true) }
        if (exact.size == 1) return exact[0].id
        if (exact.isNotEmpty()) return null
        // Riot's data may omit the tag: the name alone only if unique and untagged.
        val untagged = named.filter { it.tagLine == null }
        return if (named.size == 1 && untagged.size == 1) untagged[0].id else null
    }
    return named.singleOrNull()?.id
}

/** Matches of a round in table order: Riot's `tableNumber` when every match has one, else ascending match id. */
fun tableOrder(matches: List<Match>): List<Pair<Int, Match>> {
    if (matches.all { it.tableNumber != null }) return matches.sortedBy { it.tableNumber }.map { (it.tableNumber ?: 0) to it }
    return matches.sortedWith(compareBy({ it.esportsMatchId.length }, { it.esportsMatchId })).mapIndexed { i, m -> (i + 1) to m }
}

/** The signed-in player's situation in one round (iOS `CompetePairing`). */
data class Pairing(
    val roundId: String,
    /** "Round 3", "Quarterfinal". */
    val roundTitle: String,
    val roundShort: String,
    val tableNumber: Int?,
    val matchId: String?,
    val opponentName: String?,
    /** The other players of the player's own team in 2v2. */
    val teammateName: String?,
    val isBye: Boolean,
    val isComplete: Boolean,
    /** What a report needs: game ids in play order, both participant ids, series length. */
    val gameIds: List<String>,
    val myParticipantId: String?,
    val opponentParticipantId: String?,
    val bestOf: Int,
    val myTeamId: String?,
    val opponentTeamId: String?,
    val myGameWins: Int,
    val opponentGameWins: Int,
    val result: Result?,
) {
    enum class Result { Win, Loss, Draw }

    /** "2–1", or nothing before a game is in. */
    val scoreText: String? get() = if (myGameWins + opponentGameWins > 0) "$myGameWins–$opponentGameWins" else null

    /** "You", "You & Bo" in 2v2. */
    val mySide: String get() = "You" + (teammateName?.let { " & $it" } ?: "")

    /** Never tied to the round status: Riot decides on submit and its refusal is shown. */
    val isReportable: Boolean
        get() = !isBye && !isComplete && matchId != null && gameIds.isNotEmpty() && myParticipantId != null && opponentParticipantId != null

    companion object {
        fun latest(t: Tournament, playerId: String): Pairing? = t.rounds.lastOrNull()?.let { resolve(t, playerId, it) }

        fun resolve(t: Tournament, playerId: String, round: Round): Pairing? {
            val myTeamId = t.teamId(playerId)
            val bye = Pairing(
                round.id, t.title(round), t.shortTitle(round), null, null, null, null, isBye = true, isComplete = true,
                gameIds = emptyList(), myParticipantId = null, opponentParticipantId = null, bestOf = 1,
                myTeamId = myTeamId, opponentTeamId = null, myGameWins = 0, opponentGameWins = 0, result = Result.Win,
            )
            val slot = tableOrder(round.matches).firstOrNull { (_, m) -> m.teams.any { tm -> tm.players.any { it.id == playerId } } }
            if (slot == null) return if (myTeamId != null && myTeamId in round.byeTeamIds.orEmpty()) bye else null
            val (table, match) = slot
            val myTeam = match.teams.first { tm -> tm.players.any { it.id == playerId } }
            // The site counts a match without an opponent as a bye.
            val oppTeam = match.teams.firstOrNull { tm -> tm.players.none { it.id == playerId } } ?: return bye
            val games = match.games.orEmpty().sortedBy { it.number ?: 0 }
            fun wins(team: String) = games.count { g -> g.teamOutcomes.orEmpty().any { it.esportsTeamId == team && it.isWin } }
            val mine = myTeam.esportsTeamId
            val theirs = oppTeam.esportsTeamId
            val result = match.teamOutcomes.orEmpty().firstOrNull { it.esportsTeamId == mine }?.outcome?.uppercase()?.let { o ->
                when {
                    "WIN" in o -> Result.Win
                    "LOS" in o || "FORFEIT" in o -> Result.Loss
                    "DRAW" in o || "TIE" in o -> Result.Draw
                    else -> null
                }
            }
            val teammates = myTeam.players.filter { it.id != playerId }.mapNotNull { it.displayName }
            // Like the site's report form: any player of a team stands for it.
            val opponent = oppTeam.players.firstNotNullOfOrNull { t.participantOf(it.id) } ?: t.participant(theirs)
            return Pairing(
                round.id, t.title(round), t.shortTitle(round), table, match.esportsMatchId,
                opponentName = t.teamName(theirs),
                teammateName = teammates.takeIf { it.isNotEmpty() }?.joinToString(" & "),
                isBye = false, isComplete = match.isComplete,
                gameIds = games.map { it.esportsGameId },
                myParticipantId = (t.participantOf(playerId) ?: t.participant(mine))?.id,
                opponentParticipantId = opponent?.id,
                bestOf = match.config?.count ?: maxOf(games.size, 1),
                myTeamId = mine, opponentTeamId = theirs,
                myGameWins = wins(mine), opponentGameWins = wins(theirs), result = result,
            )
        }
    }
}
