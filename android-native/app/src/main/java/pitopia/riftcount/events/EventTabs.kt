package pitopia.riftcount.events

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
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
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.Rise
import pitopia.riftcount.ui.theme.RiftType

/** Record a team had before [round] ("2-0-0"), from the standings through the round before. */
private fun recordBefore(t: Tournament, round: Tournament.Round, team: String?): String? {
    team ?: return null
    if (round.number <= 1 || t.isElimination(round)) return if (round.number <= 1) "0-0-0" else null
    return Standings.compute(t, round.number - 1).rows.firstOrNull { it.esportsTeamId == team }?.record
}

/**
 * Matches (iOS `PlayRiftboundMatchesTab`): the final standing once over, the open pairing with Report,
 * the round clock, and the player's earlier matches.
 */
@Composable
fun MatchesTab(t: Tournament, me: String?, isPast: Boolean, onReport: (Pairing) -> Unit) {
    val myTeam = me?.let(t::teamId)
    val rounds = t.rounds
    val pairings = if (me == null) emptyList() else rounds.mapNotNull { Pairing.resolve(t, me, it) }
    val dropped = me != null && t.state(me) == PlayerState.Dropped
    // Over for this player: the event ended, they are out of the top cut, or they dropped (mock).
    val isOver = isPast || t.isFinished || dropped || (me != null && t.state(me) == PlayerState.Eliminated)
    // The latest round stays up top until the next one, reported or not (mock); the list below has every round.
    val current = pairings.lastOrNull()?.takeIf { !isOver && it.roundId == rounds.lastOrNull()?.id }
    if (me == null) BasicText("You are not in this event's player list.", Modifier.padding(top = 12.dp), style = Ev.Muted)
    if (isOver && myTeam != null) t.placement(myTeam)?.let { FinalCard(t, it, myTeam) }
    if (dropped) {
        EvCard(Modifier.padding(top = 12.dp)) {
            CardLabel("You dropped")
            BasicText("Your earlier results stay in the standings. No more pairings for you in this event.", Modifier.padding(top = 6.dp), style = Ev.Muted)
        }
    }
    current?.let { p -> CurrentCard(t, p, rounds.last(), myTeam, onReport) }
    val last = rounds.lastOrNull()
    if (last != null && !isOver && (last.matches.isEmpty() || !last.matches.all { it.isComplete })) ClockCard(t.title(last), last)
    val history = pairings.asReversed()
    if (history.isNotEmpty()) {
        Caption("Your matches")
        EvCard {
            history.forEachIndexed { i, p ->
                val (label, bg, ink) = when (p.result) {
                    Pairing.Result.Win -> Triple("W", Ev.Green, Color.Black)
                    Pairing.Result.Loss -> Triple("L", Ev.Violet, Color.Black)
                    Pairing.Result.Draw -> Triple("D", Color.White.copy(alpha = 0.85f), Color.Black)
                    null -> if (p.isComplete) Triple("·", Color.White.copy(alpha = 0.1f), Color.White) else Triple("live", Ev.Green.copy(alpha = 0.16f), Ev.Green)
                }
                Row(
                    Modifier.fillMaxWidth().height(56.dp).drawBehind {
                        if (i < history.lastIndex) drawRect(Color.White.copy(alpha = 0.06f), Offset(0f, size.height - 1.dp.toPx()), Size(size.width, 1.dp.toPx()))
                    },
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        BasicText(p.roundTitle + if (p.isBye) " · Bye" else p.tableNumber?.let { " · Table $it" } ?: "", style = RiftType.Body.copy(fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Color.White))
                        BasicText(if (p.isBye) "Counts as a win" else "vs ${p.opponentName ?: "?"}", style = RiftType.Body.copy(fontSize = 12.sp, color = Color.White.copy(alpha = 0.58f)))
                    }
                    p.scoreText?.let { BasicText(it, Modifier.width(40.dp), style = Ev.Display.copy(fontSize = 20.sp, lineHeight = 20.sp, color = Color.White, textAlign = TextAlign.End)) }
                    Box(Modifier.heightIn(min = 26.dp).background(bg, RoundedCornerShape(13.dp)).padding(horizontal = 8.dp, vertical = 4.dp), contentAlignment = Alignment.Center) {
                        BasicText(label, style = RiftType.Body.copy(fontSize = 12.sp, fontWeight = FontWeight.ExtraBold, color = ink))
                    }
                }
            }
        }
    }
}

/** The round clock in its own scope: only this card redraws every second. */
@Composable
private fun ClockCard(title: String, round: Tournament.Round) {
    val now = rememberNow(running = round.startedAt != null)
    EvCard(Modifier.padding(top = 12.dp)) {
        CardLabel("$title clock")
        val clock = roundClock(round, now)
        if (clock == null) {
            BasicText("Not started yet", Modifier.padding(top = 6.dp), style = Ev.Muted)
        } else {
            val ink = if (clock.over) Ev.Red else Color.White
            Row(Modifier.fillMaxWidth().padding(top = 6.dp), verticalAlignment = Alignment.Bottom) {
                BasicText(clock.text, Modifier.weight(1f), style = Ev.Display.copy(fontSize = 64.sp, lineHeight = 64.sp, color = ink, fontFeatureSettings = "tnum"))
                BasicText(if (clock.over) "Time over" else "left · ends ${Fmt.time(clock.endsAt)}", Modifier.padding(bottom = 8.dp), style = RiftType.Body.copy(fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.6f)))
            }
            Rail(clock.fraction, ink, Modifier.padding(top = 8.dp))
        }
    }
}

@Composable
private fun FinalCard(t: Tournament, placement: Placement, team: String) {
    val (title, crown, medal) = when (placement) {
        is Placement.Rank -> Triple(Fmt.ordinal(placement.n), placement.n == 1, placement.n <= 3)
        is Placement.Top -> Triple("Top ${placement.n}", false, placement.n <= 4)
    }
    val standing = t.finalSwissStanding(team)
    val cut = t.rounds.any { t.isElimination(it) }
    EvCard(Modifier.padding(top = 12.dp)) {
        CardLabel("Final standing")
        Row(Modifier.padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            Box(
                Modifier.size(56.dp).background(if (crown) Ev.Gold else if (medal) Color(0xFFC9CDD2) else Color.White.copy(alpha = 0.2f), CircleShape),
                contentAlignment = Alignment.Center,
            ) { Image(if (crown) EvIcons.Crown else EvIcons.Medal, null, colorFilter = ColorFilter.tint(Color.Black)) }
            Column {
                BasicText(title, style = Ev.Display.copy(fontSize = 64.sp, lineHeight = 64.sp, color = Color.White))
                standing?.let { BasicText("${it.record} · ${it.matchPoints ?: 0} pts" + if (cut) " after Swiss" else "", style = Ev.Muted) }
            }
        }
    }
}

/** The open pairing: both sides with their record before this round, Report or what was reported. */
@Composable
private fun CurrentCard(t: Tournament, p: Pairing, round: Tournament.Round, myTeam: String?, onReport: (Pairing) -> Unit) {
    EvCard(Modifier.padding(top = 12.dp), glow = true) {
        CardLabel(p.roundTitle + (p.tableNumber?.let { " · Table $it" } ?: ""), Ev.Green)
        if (p.isBye) {
            BasicText("Bye this round", Modifier.padding(top = 8.dp), style = Ev.Display.copy(fontSize = 24.sp, lineHeight = 24.sp, color = Color.White))
            BasicText("Counts as a win. Your next pairing comes with the next round.", Modifier.padding(top = 4.dp), style = Ev.Muted)
            return@EvCard
        }
        val records = remember(t, round.id) { recordBefore(t, round, myTeam) to recordBefore(t, round, p.opponentTeamId) }
        Row(Modifier.fillMaxWidth().padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Side(p.mySide, records.first, Modifier.weight(1f), TextAlign.Start)
            BasicText("VS", style = Ev.Display.copy(fontSize = 13.sp, lineHeight = 13.sp, fontWeight = FontWeight.ExtraBold, letterSpacing = 0.1.em, color = Color.White.copy(alpha = 0.4f)))
            Side(p.opponentName ?: "?", records.second, Modifier.weight(1f), TextAlign.End)
        }
        when {
            p.isReportable -> EvButton("Report result", BtnKind.Green, Modifier.padding(top = 14.dp).fillMaxWidth()) { onReport(p) }
            p.isComplete -> {
                val shape = RoundedCornerShape(22.dp)
                Row(
                    Modifier.padding(top = 12.dp).fillMaxWidth().height(44.dp).background(Ev.Green.copy(alpha = 0.1f), shape).border(1.dp, Ev.Green.copy(alpha = 0.4f), shape).padding(horizontal = 14.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Image(EvIcons.Check, null, colorFilter = ColorFilter.tint(Ev.Green))
                    BasicText("Reported" + (p.scoreText?.let { " · You $it ${p.opponentName ?: ""}" } ?: ""), style = RiftType.Body.copy(fontSize = 13.5.sp, fontWeight = FontWeight.SemiBold, color = Ev.Green))
                }
            }
        }
    }
}

@Composable
private fun Side(name: String, record: String?, modifier: Modifier, align: TextAlign) {
    Column(modifier) {
        BasicText(name, Modifier.fillMaxWidth(), style = Ev.Display.copy(fontSize = 24.sp, lineHeight = 24.sp, color = Color.White, textAlign = align), maxLines = 2)
        record?.let { BasicText(it, Modifier.fillMaxWidth().padding(top = 3.dp), style = RiftType.Body.copy(fontSize = 12.sp, color = Color.White.copy(alpha = 0.6f), textAlign = align)) }
    }
}

/** Every round's pairings (iOS `PlayRiftboundRoundsTab`); rounds still to come show as dimmed chips. */
@Composable
fun RoundsTab(t: Tournament, myTeam: String?) {
    val rounds = t.rounds
    var chosen by rememberSaveable { mutableStateOf<String?>(null) }
    val round = rounds.firstOrNull { it.id == chosen } ?: rounds.lastOrNull() ?: return
    val swissPublished = t.swissRounds.size
    val upcoming = if (rounds.none { t.isElimination(it) }) (swissPublished + 1..t.plannedSwissRounds).map { "R$it" } else emptyList()
    Row(Modifier.padding(top = 12.dp).fillMaxWidth().bleed(16.dp).horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        rounds.forEach { r -> EvChip(t.shortTitle(r), r.id == round.id, display = true) { chosen = r.id } }
        upcoming.forEach { EvChip(it, false, enabled = false, display = true) {} }
    }
    val live = round.id == rounds.last().id && !t.isFinished
    Rise(true, 0, Modifier.padding(top = 8.dp)) {
        Column {
            tableOrder(round.matches).forEach { (table, m) ->
                val teams = m.teams
                val mine = teams.any { it.esportsTeamId == myTeam }
                fun wins(id: String) = m.games.orEmpty().count { g -> g.teamOutcomes.orEmpty().any { it.esportsTeamId == id && it.isWin } }
                val scored = teams.size == 2 && m.games.orEmpty().any { !it.teamOutcomes.isNullOrEmpty() }
                val result = when {
                    scored -> "${wins(teams[0].esportsTeamId)}–${wins(teams[1].esportsTeamId)}"
                    m.isComplete -> "done"
                    live -> null
                    else -> "no result"
                }
                TableRow(table.toString(), teams.map { tm -> t.teamName(tm.esportsTeamId) to m.teamOutcomes.orEmpty().any { it.esportsTeamId == tm.esportsTeamId && it.isWin } }, result, mine)
            }
            round.byeTeamIds.orEmpty().forEach { team -> TableRow("–", listOf(t.teamName(team) to true, "Bye" to false), "bye", team == myTeam, byeRow = true) }
        }
    }
}

@Composable
private fun TableRow(table: String, names: List<Pair<String, Boolean>>, result: String?, mine: Boolean, byeRow: Boolean = false) {
    val shape = RoundedCornerShape(14.dp)
    Row(
        Modifier.padding(top = 4.dp).fillMaxWidth().heightIn(min = 50.dp)
            .let { if (mine) it.background(Ev.Green.copy(alpha = 0.08f), shape).border(1.dp, Ev.Green.copy(alpha = 0.35f), shape) else it }
            .padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        BasicText(table, Modifier.width(26.dp), style = Ev.Display.copy(fontSize = 18.sp, lineHeight = 18.sp, color = Color.White.copy(alpha = 0.5f)))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            names.forEachIndexed { i, (name, won) ->
                val color = when {
                    byeRow && i == 1 -> Color.White.copy(alpha = 0.5f)
                    won -> Ev.Green
                    else -> Color.White
                }
                BasicText(name, style = RiftType.Body.copy(fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = color), maxLines = 1)
            }
        }
        if (result == null) {
            EvPill("live", Ev.Green.copy(alpha = 0.14f), Ev.Green)
        } else {
            BasicText(result, style = Ev.Display.copy(fontSize = 14.sp, lineHeight = 14.sp, fontWeight = FontWeight.ExtraBold, letterSpacing = 0.04.em, color = Color.White))
        }
    }
}

private sealed interface View {
    data object Live : View
    data class After(val roundId: String) : View
}

/**
 * Standings (iOS `PlayRiftboundStandingsTab`): Riot's table after a finished round, or a live preview of the
 * running round from the results reported so far, the player's line and "Can I draw?".
 */
@Composable
fun StandingsTab(t: Tournament, myTeam: String?, canDraw: Boolean, onDraw: () -> Unit) {
    val official = t.rounds.filter { !it.endOfRoundStandings.isNullOrEmpty() }
    val running = t.rounds.lastOrNull()?.takeIf { !t.isElimination(it) }
    val live = remember(t) {
        running?.takeIf { it.endOfRoundStandings.isNullOrEmpty() }?.let { Standings.compute(t, it.number) }?.takeIf { it.reportedMatches > 0 }
    }
    var view by remember { mutableStateOf<View?>(null) }
    val current = when (val v = view) {
        View.Live -> if (live != null) View.Live else null
        is View.After -> v.takeIf { a -> official.any { it.id == a.roundId } }
        null -> null
    } ?: if (live != null) View.Live else official.lastOrNull()?.let { View.After(it.id) }
    val rows = when (current) {
        View.Live -> live?.rows.orEmpty()
        is View.After -> official.first { it.id == current.roundId }.endOfRoundStandings.orEmpty().sortedBy { it.rank ?: Int.MAX_VALUE }
        null -> emptyList()
    }
    if (rows.isEmpty()) {
        BasicText("Standings appear once the first result is reported.", Modifier.padding(top = 14.dp), style = Ev.Muted)
        return
    }
    val pending = if (current == View.Live) live?.pending.orEmpty() else emptySet()
    if (official.size + (if (live != null) 1 else 0) > 1) {
        Row(Modifier.padding(top = 12.dp).fillMaxWidth().bleed(16.dp).horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            official.forEach { r -> EvChip("After ${t.shortTitle(r)}", current == View.After(r.id)) { view = View.After(r.id) } }
            live?.let { EvChip("Live R${it.roundNumber} •", current == View.Live) { view = View.Live } }
        }
    }
    if (current == View.Live && live != null) {
        val shape = RoundedCornerShape(16.dp)
        Column(Modifier.padding(top = 12.dp).fillMaxWidth().background(Ev.Gold.copy(alpha = 0.08f), shape).border(1.dp, Ev.Gold.copy(alpha = 0.32f), shape).padding(horizontal = 14.dp, vertical = 12.dp)) {
            BasicText("PREVIEW · NOT FINAL", Modifier.padding(bottom = 4.dp), style = RiftType.Body.copy(fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.14.em, color = Ev.Gold))
            BasicText(
                "Calculated in the app from ${live.reportedMatches} of ${live.totalMatches} results reported in round ${live.roundNumber}. PlayRiftbound publishes the official standings when the round ends; places can still change.",
                style = RiftType.Body.copy(fontSize = 12.5.sp, lineHeight = 18.sp, color = Color.White.copy(alpha = 0.82f)),
            )
        }
    }
    rows.firstOrNull { it.esportsTeamId == myTeam }?.let { mine ->
        EvCard(Modifier.padding(top = 12.dp)) {
            CardLabel("Your standing")
            Row(Modifier.padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                BasicText(mine.rank?.let(Fmt::ordinal) ?: "–", style = Ev.Display.copy(fontSize = 60.sp, lineHeight = 60.sp, color = Ev.Green))
                Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    if (current == View.Live) MiniPill("PREVIEW", Ev.Gold, Color.Black)
                    BasicText("${mine.record} · ${mine.matchPoints ?: 0} pts", style = RiftType.Body.copy(fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Color.White))
                    BasicText(tiebreakers(mine), style = RiftType.Body.copy(fontSize = 12.sp, color = Color.White.copy(alpha = 0.6f)))
                }
            }
        }
        if (current == View.Live && canDraw && t.plannedSwissRounds > 0) {
            val shape = RoundedCornerShape(27.dp)
            Pressable(onDraw, Modifier.padding(top = 12.dp).fillMaxWidth().height(54.dp).background(Ev.Green.copy(alpha = 0.08f), shape).border(1.dp, Ev.Green.copy(alpha = 0.5f), shape), pressedScale = 0.98f) {
                BasicText("Can I draw?", style = RiftType.Body.copy(fontSize = 15.sp, fontWeight = FontWeight.Bold, color = Ev.Green))
            }
        }
    }
    var open by remember { mutableStateOf(emptySet<String>()) }
    EvCard(Modifier.padding(top = 12.dp)) {
        rows.forEachIndexed { i, s ->
            val mine = myTeam != null && s.esportsTeamId == myTeam
            val dropped = t.participant(s.esportsTeamId)?.status?.uppercase()?.contains("DROP") == true
            val ink = when {
                mine -> Ev.Green
                dropped -> Color.White.copy(alpha = 0.4f)
                else -> Color.White
            }
            val expanded = s.esportsTeamId in open
            Pressable(
                { open = if (expanded) open - s.esportsTeamId else open + s.esportsTeamId },
                Modifier.fillMaxWidth(), pressedScale = 0.99f, label = if (expanded) "Hide tiebreakers" else "Show tiebreakers",
            ) {
                Row(
                    Modifier.fillMaxWidth().height(46.dp).padding(horizontal = 4.dp).drawBehind {
                        if (!expanded && i < rows.lastIndex) drawRect(Color.White.copy(alpha = 0.06f), Offset(0f, size.height - 1.dp.toPx()), Size(size.width, 1.dp.toPx()))
                    },
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    BasicText("${s.rank ?: i + 1}", Modifier.width(30.dp), style = Ev.Display.copy(fontSize = 18.sp, lineHeight = 18.sp, color = ink))
                    Row(Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        BasicText(t.teamName(s.esportsTeamId), Modifier.weight(1f, fill = false), style = RiftType.Body.copy(fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = ink), maxLines = 1)
                        when {
                            dropped -> MiniPill("DROPPED", Color.White.copy(alpha = 0.1f), Color.White.copy(alpha = 0.6f))
                            s.esportsTeamId in pending -> MiniPill("PLAYING", Ev.Green.copy(alpha = 0.14f), Ev.Green)
                        }
                    }
                    BasicText(s.record, Modifier.width(52.dp), style = RiftType.Body.copy(fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.7f), textAlign = TextAlign.End, fontFeatureSettings = "tnum"))
                    BasicText("${s.matchPoints ?: 0}", Modifier.width(34.dp), style = Ev.Display.copy(fontSize = 18.sp, lineHeight = 18.sp, color = ink, textAlign = TextAlign.End))
                }
            }
            if (expanded) {
                Rise(true, 0) {
                    BasicText(
                        tiebreakers(s),
                        Modifier.fillMaxWidth().drawBehind {
                            if (i < rows.lastIndex) drawRect(Color.White.copy(alpha = 0.06f), Offset(0f, size.height - 1.dp.toPx()), Size(size.width, 1.dp.toPx()))
                        }.padding(start = 44.dp, end = 6.dp, top = 2.dp, bottom = 10.dp),
                        style = RiftType.Body.copy(fontSize = 12.sp, color = Color.White.copy(alpha = 0.6f)),
                    )
                }
            }
        }
    }
    BasicText(
        "OMW: opponents' match-win rate. GW: your game-win rate. OGW: opponents' game-win rate. Each has a 33% floor.",
        Modifier.padding(top = 12.dp), style = RiftType.Body.copy(fontSize = 12.sp, lineHeight = 18.sp, color = Color.White.copy(alpha = 0.5f)),
    )
}

private fun tiebreakers(s: Tournament.Standing) =
    "OMW ${Fmt.pct(s.opponentMatchWinPercentage)} · GW ${Fmt.pct(s.gameWinPercentage)} · OGW ${Fmt.pct(s.opponentGameWinPercentage)}"
