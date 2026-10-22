package pitopia.riftcount.events

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import pitopia.riftcount.ui.common.DialogFrame
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.Sheet
import pitopia.riftcount.ui.common.Toaster
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

private val H3 = RiftType.Body.copy(fontSize = 17.sp, fontWeight = FontWeight.Bold, color = Color.White)
private val P = RiftType.Body.copy(fontSize = 13.sp, lineHeight = 19.sp, fontWeight = FontWeight.Normal, color = Color.White.copy(alpha = 0.72f))
private val Foot = RiftType.Body.copy(fontSize = 12.sp, lineHeight = 17.4.sp, color = Color.White.copy(alpha = 0.55f))

private enum class Stage { Pick, Confirm, Sending }

/** A game as reported: me, the opponent, a draw; null = not marked. */
private enum class Game { Me, Opponent, Draw }

/**
 * Report the player's own result (iOS `PlayRiftboundReportSheet`, the mock's dialog): one row per game in
 * play order, nothing after the deciding game, only marked games are sent. The pairing is fetched again on
 * open and right before sending, so marks never go to a re-paired match.
 */
@Composable
fun ReportDialog(data: EventsData, tournamentId: String, start: Pairing, toaster: Toaster, onDone: () -> Unit) {
    val scope = rememberCoroutineScope()
    var pairing by remember { mutableStateOf(start) }
    var games by remember { mutableStateOf(List<Game?>(maxOf(1, minOf(start.bestOf, start.gameIds.size))) { null }) }
    var stage by remember { mutableStateOf(Stage.Pick) }
    var error by remember { mutableStateOf<String?>(null) }
    val opponent = pairing.opponentName ?: "Opponent"

    /** False when the player's match changed under the open dialog: the marks are cleared. */
    suspend fun refresh(): Boolean {
        val t = runCatching { data.tournament(tournamentId, force = true) }.getOrNull() ?: return true
        val fresh = data.playerId(t)?.let { Pairing.latest(t, it) } ?: return true
        val same = fresh.matchId == pairing.matchId && fresh.gameIds == pairing.gameIds
        if (!same) games = List(maxOf(1, minOf(fresh.bestOf, fresh.gameIds.size))) { null }
        pairing = fresh
        return same
    }
    LaunchedEffect(Unit) { refresh() }

    val series = games.size > 1
    val winsNeeded = games.size / 2 + 1
    val decided = run {
        if (!series) return@run -1
        var mine = 0
        var theirs = 0
        games.forEachIndexed { i, g ->
            when (g) {
                Game.Me -> mine++
                Game.Opponent -> theirs++
                Game.Draw -> Unit
                null -> return@run -1
            }
            if (mine >= winsNeeded || theirs >= winsNeeded) return@run i
        }
        -1
    }
    val me = games.count { it == Game.Me }
    val them = games.count { it == Game.Opponent }
    val draws = games.count { it == Game.Draw }
    val summary = "You $me – $them $opponent" + if (draws > 0) " ($draws ${if (draws == 1) "draw" else "draws"})" else ""
    val any = games.any { it != null }

    fun send() {
        stage = Stage.Sending
        error = null
        scope.launch {
            try {
                if (!refresh()) {
                    error = "Your pairing changed. Check the games and submit again."
                    stage = Stage.Pick
                    return@launch
                }
                if (pairing.isComplete) {
                    toaster.show("Already reported on PlayRiftbound" + (pairing.scoreText?.let { ": You $it $opponent" } ?: ""))
                    onDone()
                    return@launch
                }
                val mine = pairing.myParticipantId
                val theirs = pairing.opponentParticipantId
                if (mine == null || theirs == null) {
                    error = "Couldn't find your match in the current round."
                    stage = Stage.Pick
                    return@launch
                }
                val played = if (decided >= 0) games.take(decided + 1) else games
                val results = pairing.gameIds.zip(played).mapNotNull { (id, g) ->
                    when (g) {
                        Game.Me -> RiftApi.GameResult(id, false, mine)
                        Game.Opponent -> RiftApi.GameResult(id, false, theirs)
                        Game.Draw -> RiftApi.GameResult(id, true, null)
                        null -> null
                    }
                }
                if (results.isEmpty()) {
                    error = "Mark at least one game."
                    stage = Stage.Pick
                    return@launch
                }
                val credentials = RiotSession.valid(data.browser) ?: throw RiftError.NotSignedIn()
                try {
                    data.api.submitGameResults(tournamentId, results, credentials)
                } catch (_: RiftError.SessionExpired) {
                    // The site renews its token on a page load; once, then again.
                    data.api.submitGameResults(tournamentId, results, RiotSession.renewed(data.browser))
                }
                toaster.show("Reported to PlayRiftbound · $me–$them")
                runCatching { data.tournament(tournamentId, force = true) }
                data.refreshStrip(force = true)
                onDone()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = e.message ?: "Couldn't submit the result. Please try again."
                stage = Stage.Pick
            }
        }
    }

    // A result on its way is sent either way; the dialog stays until the answer is in.
    DialogFrame({ if (stage != Stage.Sending) onDone() }, fullScreen = false) {
        when (stage) {
            Stage.Pick -> {
                BasicText("Report result", style = H3)
                BasicText(
                    (if (series) "Games (best of ${games.size})" else "Result (best of 1)") + " · ${pairing.roundTitle}" + (pairing.tableNumber?.let { " · Table $it" } ?: ""),
                    Modifier.padding(top = 6.dp, bottom = 14.dp), style = P,
                )
                games.forEachIndexed { i, g ->
                    val locked = (i > 0 && games[i - 1] == null) || (decided >= 0 && i > decided)
                    val fade by animateFloatAsState(if (locked) 0.35f else 1f, tween(300), label = "locked")
                    Column(Modifier.padding(bottom = 12.dp).graphicsLayer { alpha = fade }, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        if (series) BasicText("GAME ${i + 1}", style = RiftType.Body.copy(fontSize = 12.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.06.em, color = Color.White.copy(alpha = 0.72f)))
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            listOf(Game.Me to "You", Game.Draw to "Draw", Game.Opponent to opponent).forEach { (value, label) ->
                                Option(label, g == value, value, !locked, Modifier.weight(1f)) {
                                    // Changing a game clears the ones after it: they belonged to another course of the series.
                                    games = games.mapIndexed { j, old -> if (j < i) old else if (j == i) (if (g == value) null else value) else null }
                                }
                            }
                        }
                    }
                }
                SummaryBox(if (any) "You report · $summary" else "Pick the result of each game")
                BasicText(
                    error ?: if (decided in 0 until games.lastIndex) "Match is decided at $winsNeeded game wins. The remaining game is disabled."
                    else "Enter the games in the order you played them. Only the games you mark are sent.",
                    Modifier.padding(bottom = 14.dp),
                    style = if (error != null) Foot.copy(color = Ev.Red) else Foot,
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    EvButton("Cancel", BtnKind.Ghost, Modifier.weight(1f), onClick = onDone)
                    EvButton("Submit", BtnKind.Green, Modifier.weight(1f), enabled = any && !pairing.isComplete) { stage = Stage.Confirm }
                }
            }
            Stage.Confirm -> {
                BasicText("Submit this result?", style = H3)
                BasicText("This reports your ${pairing.roundTitle} result to PlayRiftbound. The organizer can still adjust it.", Modifier.padding(top = 6.dp, bottom = 14.dp), style = P)
                SummaryBox(summary)
                Row(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    EvButton("Cancel", BtnKind.Ghost, Modifier.weight(1f)) { stage = Stage.Pick }
                    EvButton("Submit", BtnKind.Green, Modifier.weight(1f), onClick = ::send)
                }
            }
            Stage.Sending -> {
                BasicText("Report result", style = H3)
                Box(Modifier.padding(top = 12.dp)) { SummaryBox(summary) }
                Row(Modifier.fillMaxWidth().height(46.dp), horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                    Spinner(size = 18)
                    BasicText("Sending to PlayRiftbound", style = RiftType.Body.copy(fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Ev.Green))
                }
            }
        }
    }
}

@Composable
private fun Option(label: String, on: Boolean, value: Game, enabled: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(22.dp)
    val color = when (value) {
        Game.Me -> Ev.Green
        Game.Draw -> Color.White
        Game.Opponent -> Ev.Violet
    }
    val bg by animateColorAsState(if (on) color else Color.White.copy(alpha = 0.06f), tween(250), label = "optBg")
    val ink by animateColorAsState(if (on) Color.Black else Color.White, tween(250), label = "optInk")
    Pressable(onClick, modifier.height(44.dp).background(bg, shape).border(1.dp, Color.White.copy(alpha = 0.18f), shape), enabled = enabled, pressedScale = 0.96f) {
        BasicText(label, Modifier.padding(horizontal = 6.dp), style = RiftType.Body.copy(fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = ink), maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun SummaryBox(text: String) {
    BasicText(
        text,
        Modifier.fillMaxWidth().padding(top = 4.dp, bottom = 6.dp).background(Color.White.copy(alpha = 0.05f), RoundedCornerShape(16.dp)).padding(horizontal = 14.dp, vertical = 10.dp),
        style = RiftType.Body.copy(fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Color.White),
    )
}

/** Register / cancel / drop, confirmed first (mock's `.dlg`, iOS confirmation dialog). */
@Composable
fun ActionDialog(title: String, text: String, label: String, danger: Boolean, onKeep: () -> Unit, onDo: () -> Unit) {
    DialogFrame(onKeep, fullScreen = false) {
        BasicText(title, style = H3)
        BasicText(text, Modifier.padding(top = 6.dp, bottom = 14.dp), style = P)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            EvButton("Keep", BtnKind.Ghost, Modifier.weight(1f), onClick = onKeep)
            EvButton(label, if (danger) BtnKind.Danger else BtnKind.Green, Modifier.weight(1f), onClick = onDo)
        }
    }
}

/**
 * "Can I draw?" (iOS standings outlook): the player picks the cut size (Riot's data has none), each line is
 * the same result in every match left. Open matches of the running round count as still to play.
 */
@Composable
fun DrawSheet(t: Tournament, myTeam: String, onDismiss: () -> Unit) {
    val running = t.rounds.lastOrNull()?.takeIf { !t.isElimination(it) } ?: return
    val table = remember(t) { Standings.compute(t, running.number) }
    val roundsAfter = maxOf(0, t.plannedSwissRounds - running.number)
    fun out(team: String) = t.participant(team)?.status?.uppercase().orEmpty().let { "DROP" in it || "ELIM" in it }
    fun remaining(team: String) = if (out(team)) 0 else roundsAfter + if (team in table.pending) 1 else 0
    val cuts = listOf(4, 8, 16).filter { it < table.rows.size }
    var cut by remember { mutableIntStateOf(if (8 in cuts) 8 else cuts.lastOrNull() ?: 0) }
    val mine = table.rows.firstOrNull { it.esportsTeamId == myTeam }
    val myLeft = remaining(myTeam)
    Sheet("Can I draw?", onDismiss) {
        BasicText("Can I draw?", style = H3)
        BasicText("Top cut math on the live round. Open matches count as still to play.", Modifier.padding(top = 4.dp, bottom = 12.dp), style = P)
        if (mine == null || cuts.isEmpty() || myLeft < 1) {
            BasicText("Nothing left to work out for you in this event.", style = P)
            return@Sheet
        }
        CutSegments(cuts, cut) { cut = it }
        val points = mine.matchPoints ?: 0
        val others = table.rows.filter { it.esportsTeamId != myTeam }.map { Contender(it.matchPoints ?: 0, remaining(it.esportsTeamId)) }
        val outlook = DrawCalc.outlook(points, myLeft, others, cut)
        val suffix = if (myLeft == 1) "" else " out"
        BasicText(
            "Top $cut · $myLeft ${if (myLeft == 1) "match" else "matches"} left · you have $points pts",
            Modifier.padding(start = 2.dp, top = 14.dp, bottom = 6.dp),
            style = RiftType.Body.copy(fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.75f)),
        )
        listOf("Win", "Draw", "Lose").zip(outlook).forEach { (label, chance) -> Verdict(label + suffix, chance) }
        BasicText(
            (if (table.reportedMatches < table.totalMatches) "Uses the ${table.reportedMatches} of ${table.totalMatches} results already reported in round ${table.roundNumber}; open matches count as still to play. " else "") +
                "“Locked in” is guaranteed regardless of other results. “Bubble” depends on other matches and tiebreakers.",
            Modifier.padding(top = 12.dp),
            style = Foot.copy(color = Color.White.copy(alpha = 0.5f)),
        )
    }
}

/** `.cutseg`: Top 4 / 8 / 16 with a white knob that slides. */
@Composable
private fun CutSegments(cuts: List<Int>, cut: Int, onPick: (Int) -> Unit) {
    val shape = RoundedCornerShape(21.dp)
    BoxWithConstraints(Modifier.fillMaxWidth().height(42.dp).background(Color.White.copy(alpha = 0.06f), shape).border(1.dp, Color.White.copy(alpha = 0.1f), shape).padding(3.dp)) {
        val w = maxWidth / cuts.size
        val x by animateFloatAsState(cuts.indexOf(cut).toFloat(), tween(500, easing = RiftEase), label = "cut")
        Box(Modifier.width(w).fillMaxHeight().graphicsLayer { translationX = x * w.toPx() }.background(Color.White, RoundedCornerShape(17.dp)))
        Row(Modifier.fillMaxSize()) {
            cuts.forEach { c ->
                val ink by animateColorAsState(if (c == cut) Color.Black else Color.White.copy(alpha = 0.8f), tween(300), label = "cutInk")
                Pressable({ onPick(c) }, Modifier.weight(1f).fillMaxHeight(), pressedScale = 0.97f) {
                    BasicText("Top $c", style = RiftType.Body.copy(fontSize = 13.sp, fontWeight = FontWeight.Bold, color = ink))
                }
            }
        }
    }
}

@Composable
private fun Verdict(label: String, chance: CutChance) {
    val (bg, ink, glow) = when (chance) {
        CutChance.Locked -> Triple(Ev.Green, Color.Black, Ev.Green.copy(alpha = 0.55f))
        CutChance.Bubble -> Triple(Ev.Gold, Color.Black, Ev.Gold.copy(alpha = 0.4f))
        CutChance.Out -> Triple(Color.White.copy(alpha = 0.06f), Color.White.copy(alpha = 0.7f), Color.Transparent)
    }
    val shape = RoundedCornerShape(15.dp)
    Row(
        Modifier.fillMaxWidth().height(56.dp).drawBehind {
            drawRect(Color.White.copy(alpha = 0.07f), Offset(0f, size.height - 1.dp.toPx()), Size(size.width, 1.dp.toPx()))
        },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        BasicText(label, Modifier.weight(1f), style = RiftType.Body.copy(fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Color.White))
        Box(
            Modifier.height(30.dp).dropShadow(shape, Shadow(16.dp, glow)).background(bg, shape)
                .border(1.dp, if (chance == CutChance.Out) Color.White.copy(alpha = 0.18f) else bg, shape).padding(horizontal = 14.dp),
            contentAlignment = Alignment.Center,
        ) { BasicText(chance.label, style = RiftType.Body.copy(fontSize = 12.5.sp, fontWeight = FontWeight.Bold, color = ink)) }
    }
}
