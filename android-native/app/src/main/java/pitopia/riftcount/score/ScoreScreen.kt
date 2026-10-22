package pitopia.riftcount.score

import androidx.activity.compose.BackHandler
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import pitopia.riftcount.data.AppSettings
import pitopia.riftcount.cards.CardStore
import pitopia.riftcount.data.Decklist
import pitopia.riftcount.platform.ShakeEffect
import pitopia.riftcount.ui.theme.RiftEase

/** The Score tab. [bottomReserve] is the room the tab bar takes at the bottom; both halves end above it. */
@Composable
fun ScoreScreen(c: ScoreController, bottomReserve: Dp, decks: List<Decklist>, cards: CardStore) {
    BackHandler(enabled = c.duel != null || c.picker != null || c.confirmRestart || c.state.asking >= 0) {
        when {
            c.picker != null -> c.closePicker()
            c.confirmRestart -> c.cancelRestart()
            c.state.asking >= 0 -> c.finalPoint(false)
            else -> c.closeDuel()
        }
    }
    ShakeEffect(enabled = c.duel?.canRollAll == true && AppSettings.shakeToRoll.on) { c.rollAll() }
    val slots = c.state.players.size
    val swatches = List(slots) { PlayerColors.forSlot(it, slots) }
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val area = maxHeight - bottomReserve
        if (c.state.isDuel) Duel(c, swatches, area, maxHeight) else FourPlayers(c, swatches, area)
        // Centred on the seam like the mock, so it never covers a player's own controls.
        BoardToast(c.toast, c::clearToast, Modifier.align(Alignment.TopCenter).offset(y = area / 2 - 20.dp))
        if (c.confirmRestart) RestartDialog(c.state.gameNo, c::cancelRestart, c::restart)
        c.picker?.let { ResultPickerDialog(c, it, swatches.map { s -> s.color }) }
    }
    when (c.setupSlot) {
        YOU -> DeckPickSheet(c, decks, cards.index, c::closeSetup)
        OPPONENT -> OpponentPickSheet(c, cards.legendNames, cards.cards, c::closeSetup)
    }
}

@Composable
private fun BoxScope.Duel(c: ScoreController, swatches: List<Swatch>, area: Dp, screen: Dp) {
    val s = c.state
    val d = c.duel
    val colors = swatches.map { it.color }
    val center = area / 2
    val sweep = if (d?.choice != null) 120.dp else 210.dp
    val target = when {
        d != null && d.winner == YOU -> sweep
        d != null && d.winner == OPPONENT -> area - sweep
        d != null -> center
        s.showSummary -> s.seriesWins().let { w -> if (w[YOU] > w[OPPONENT]) 64.dp else if (w[OPPONENT] > w[YOU]) area - 64.dp else center }
        s.gameOver -> if (s.winner == YOU) 64.dp else area - 64.dp
        else -> (center + 26.dp * (s.players[OPPONENT].score - s.players[YOU].score)).coerceIn(130.dp, area - 130.dp)
    }
    val line by animateDpAsState(target, tween(1100, easing = RiftEase), label = "territory")
    val leader = when {
        d != null -> d.winner
        s.players[YOU].score > s.players[OPPONENT].score -> YOU
        s.players[OPPONENT].score > s.players[YOU].score -> OPPONENT
        else -> -1
    }
    val lineColor by animateColorAsState(if (leader < 0) Color.White.copy(alpha = 0.7f) else colors[leader], tween(600), label = "lineColor")
    val lineAlpha by animateFloatAsState(if (s.showSummary) 0f else 1f, tween(500), label = "lineAlpha")
    // Each field is one screen tall, so the opponent's reaches the top and yours runs under the tab bar.
    Box(Modifier.fillMaxWidth().height(screen).graphicsLayer { translationY = (line - screen).toPx() }.background(colors[OPPONENT].copy(alpha = 0.13f)))
    Box(Modifier.fillMaxWidth().height(screen).graphicsLayer { translationY = line.toPx() }.background(colors[YOU].copy(alpha = 0.13f)))
    Box(
        Modifier.fillMaxWidth().height(2.dp)
            .graphicsLayer { translationY = (line - 1.dp).toPx(); alpha = lineAlpha }
            .dropShadow(RectangleShape, Shadow(radius = 22.dp, color = lineColor, spread = 3.dp))
            .background(lineColor),
    )
    Column(Modifier.fillMaxWidth().height(area)) {
        Half(c, OPPONENT, swatches, Modifier.weight(1f).graphicsLayer { rotationZ = 180f })
        Half(c, YOU, swatches, Modifier.weight(1f))
    }
    Seam(c, Modifier.align(Alignment.TopCenter).offset(y = center - 27.dp))
    if (d != null && d.winner >= 0 && d.choice != null) {
        val starter = d.starter()
        val roll = { slot: Int -> d.dice[slot].value ?: 0 }
        DuelBanner(
            title = "${c.shortName(starter)} ${if (c.shortName(starter) == "You") "start" else "starts"}",
            text = "${c.shortName(d.winner)} rolled ${roll(d.winner)} against ${roll(1 - d.winner)} and chose to go ${if (d.choice == DuelState.Choice.First) "first" else "second"}.",
            accent = colors[starter], ink = swatches[starter].ink,
            onAgain = c::rollAgain, onStart = c::startGame,
            modifier = Modifier.align(Alignment.TopCenter).offset(y = center - 80.dp).padding(horizontal = 16.dp),
        )
    }
    if (s.showSummary) MatchSummary(c, colors, center)
}

@Composable
private fun Half(c: ScoreController, slot: Int, swatches: List<Swatch>, modifier: Modifier) {
    val s = c.state
    val d = c.duel
    val accent = swatches[slot].color
    val ink = swatches[slot].ink
    val dim = if (d != null) d.winner >= 0 && d.winner != slot else s.gameOver && s.winner != slot
    // The summary is the focus: both halves fade to a ghost behind it.
    val alpha by animateFloatAsState(if (s.showSummary) 0.18f else if (dim) 0.32f else 1f, tween(900, easing = RiftEase), label = "dim")
    val wins = s.seriesWins()
    Box(modifier.fillMaxWidth()) {
        Column(Modifier.fillMaxSize().padding(start = 20.dp, end = 20.dp, top = 34.dp, bottom = 18.dp).graphicsLayer { this.alpha = alpha }) {
            if (d != null) {
                DuelSide(c, d, slot, accent, ink, Modifier.fillMaxSize())
            } else {
                TopLine(
                    c.legend(slot), accent, ink, s.starter == slot, s.players[slot].xp, { c.xp(slot, it) }, wins[slot], seriesPips = true,
                    shown = !s.gameOver && !s.showSummary, onName = { c.openSetup(slot) },
                )
                Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                    ScoreNumber(s.players[slot].score, accent, won = s.winner == slot, label = "${haves(c.shortName(slot))} ${s.players[slot].score} of $TARGET points")
                }
                when {
                    s.showSummary -> Spacer(Modifier.height(54.dp))
                    !s.gameOver -> ActionRow(accent, ink, { c.score(slot, PointKind.Conquer) }, { c.score(slot, PointKind.Hold) }, { c.score(slot, PointKind.Effect) }, { c.fix(slot) })
                    s.winner == slot -> NextGameButton("Next game · Game ${s.gameNo + 1}", accent, ink, c::nextGame)
                    else -> Spacer(Modifier.height(54.dp))
                }
            }
        }
        if (d == null && s.winner == slot && !s.showSummary) {
            ResultText("GAME ${s.gameNo}", "Series ${wins[slot]}–${wins[1 - slot]}", accent, Modifier.align(Alignment.TopCenter).padding(top = 80.dp))
        }
        if (d == null && s.asking == slot) {
            FinalPointSheet(accent, ink, { c.finalPoint(true) }, { c.finalPoint(false) }, Modifier.align(Alignment.BottomCenter).padding(12.dp))
        }
        if (c.drew == slot) HalfToast("No point · draw a card instead", Modifier.align(Alignment.TopCenter).padding(top = 70.dp))
    }
}

@Composable
private fun DuelSide(c: ScoreController, d: DuelState, slot: Int, accent: Color, ink: Color, modifier: Modifier, dieSize: Float = 190f) {
    val die = d.dice[slot]
    val won = d.winner == slot
    val lost = d.winner >= 0 && !won
    val others = if (d.dice.size == 2) c.shortName(1 - slot) else "the others"
    val hint = when {
        won || d.tie || (lost && (d.choice != null || d.dice.size > 2)) -> null
        die.rolling -> "Rolling"
        die.value == null -> if (d.dice.size == 2) "Tap your half to roll" else "Tap your side to roll"
        d.winner < 0 -> "Waiting for $others"
        lost -> "$others rolled higher"
        else -> null
    }
    val head = when {
        d.tie -> "Tie · roll again"
        won && d.choice != null -> c.shortName(slot).let { n -> "$n ${if (n == "You") "go" else "goes"} ${if (d.choice == DuelState.Choice.First) "first" else "second"}" }
        won -> "Higher roll"
        else -> null
    }
    val name = c.shortName(slot).let { if (slot == YOU && d.dice.size == 2 && it != "You") "$it · you" else it }
    DuelHalf(
        name, d.type, die, accent, ink, hint, head, if (d.tie) Color.White else accent,
        choosing = won && d.choice == null && d.dice.size == 2, highlight = won,
        onRoll = { c.roll(slot) }, onFirst = { c.choose(DuelState.Choice.First) }, onSecond = { c.choose(DuelState.Choice.Second) },
        modifier = modifier, dieSize = dieSize,
    )
}

/** Four players (no mock): a 2×2 table, the far side turned around, every corner in its own colour. */
@Composable
private fun BoxScope.FourPlayers(c: ScoreController, swatches: List<Swatch>, area: Dp) {
    val s = c.state
    val d = c.duel
    val top = s.players.maxOf { it.score }
    Column(Modifier.fillMaxWidth().height(area)) {
        listOf(listOf(0, 1), listOf(2, 3)).forEachIndexed { row, slots ->
            Row(Modifier.weight(1f).fillMaxWidth().graphicsLayer { rotationZ = if (row == 0) 180f else 0f }) {
                // The far row is turned as a whole, so its seats keep their places for the players across.
                (if (row == 0) slots.reversed() else slots).forEach { slot ->
                    val sw = swatches[slot]
                    val leading = top > 0 && s.players[slot].score == top
                    val tint by animateFloatAsState(if (leading) 0.2f else 0.09f, tween(600), label = "tint")
                    val lost = d != null && d.winner >= 0 && d.winner != slot
                    val alpha by animateFloatAsState(if (lost) 0.32f else 1f, tween(900, easing = RiftEase), label = "dim")
                    Box(Modifier.weight(1f).fillMaxHeight().background(sw.color.copy(alpha = tint))) {
                        Column(Modifier.fillMaxSize().padding(start = 12.dp, end = 12.dp, top = 22.dp, bottom = 14.dp).graphicsLayer { this.alpha = alpha }) {
                            if (d != null) {
                                DuelSide(c, d, slot, sw.color, sw.ink, Modifier.fillMaxSize(), dieSize = 110f)
                            } else {
                                TopLine(c.legend(slot), sw.color, sw.ink, s.starter == slot, s.players[slot].xp, { c.xp(slot, it) }, 0, seriesPips = false)
                                Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                                    ScoreNumber(s.players[slot].score, sw.color, won = false, label = s.players[slot].score.let { n -> "${haves(c.legend(slot))} $n ${if (n == 1) "point" else "points"}" }, showTarget = false, sizeDp = 112f)
                                }
                                ActionGrid(sw.color, sw.ink, { c.score(slot, PointKind.Conquer) }, { c.score(slot, PointKind.Hold) }, { c.score(slot, PointKind.Effect) }, { c.fix(slot) })
                            }
                        }
                    }
                }
            }
        }
    }
    Box(Modifier.width(1.dp).height(area).align(Alignment.TopCenter).background(Color.White.copy(alpha = 0.08f)))
    Seam(c, Modifier.align(Alignment.TopCenter).offset(y = area / 2 - 27.dp))
    if (d != null && d.winner >= 0) {
        val starter = d.starter()
        DuelBanner(
            title = "${c.shortName(starter)} starts",
            text = "${c.shortName(starter)} rolled ${d.dice[starter].value} on the ${d.type.label}, the highest roll at the table.",
            accent = swatches[starter].color, ink = swatches[starter].ink,
            onAgain = c::rollAgain, onStart = c::startGame,
            modifier = Modifier.align(Alignment.TopCenter).offset(y = area / 2 - 80.dp).padding(horizontal = 16.dp),
        )
    }
}

/** "You have", "Lee Sin has": the score labels read by TalkBack. */
private fun haves(name: String) = if (name == "You") "You have" else "$name has"
