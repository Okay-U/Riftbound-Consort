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
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import pitopia.riftcount.cards.CardStore
import pitopia.riftcount.data.AppSettings
import pitopia.riftcount.data.Decklist
import pitopia.riftcount.ui.theme.RiftEase

/** The Score tab. [bottomReserve] is the room the tab bar takes at the bottom; both halves end above it. */
@Composable
fun ScoreScreen(c: ScoreController, bottomReserve: Dp, decks: List<Decklist>, cards: CardStore, match: MatchInfo?) {
    BackHandler(enabled = c.duel != null || c.gameMenu || c.state.asking >= 0) {
        when {
            c.gameMenu -> c.closeGameMenu()
            c.state.asking >= 0 -> c.finalPoint(false)
            else -> c.closeDuel()
        }
    }
    val slots = c.state.players.size
    val swatches = List(slots) { PlayerColors.forSlot(it, slots) }
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val area = maxHeight - bottomReserve
        if (c.state.isDuel) Duel(c, swatches, area, maxHeight, match) else FourPlayers(c, swatches, area, maxHeight - area)
        // Centred on the seam like the mock, so it never covers a player's own controls.
        BoardToast(c.toast, c::clearToast, Modifier.align(Alignment.TopCenter).offset(y = area / 2 - 20.dp))
        if (c.gameMenu) GameDialog(c.state.isDuel, swatches, c::closeGameMenu, c::end, c::restart)
    }
    when (c.setupSlot) {
        YOU -> DeckPickSheet(c, decks, cards.index, c::closeSetup)
        OPPONENT -> OpponentPickSheet(c, cards.legendNames, cards.cards, c::closeSetup)
    }
}

@Composable
private fun BoxScope.Duel(c: ScoreController, swatches: List<Swatch>, area: Dp, screen: Dp, match: MatchInfo?) {
    val s = c.state
    val d = c.duel
    // Legend art by seat, loaded as soon as the switch is on and a legend is picked.
    val art = List(2) { slot -> rememberLegendPicture(if (AppSettings.legendArt.on) c.legendArtUrl(slot) else null).value }
    // Colour model C: the fields take the seat colours deep, what the board draws in them is lifted to show. Over a
    // picture the field is the seat's colour at 22 %.
    val fields = List(2) { slot -> if (art[slot] != null) swatches[slot].color.copy(alpha = 0.22f) else SeatShade.deep(swatches[slot].color) }
    val board = swatches.map { it.copy(color = SeatShade.lift(it.color)) }
    val colors = board.map { it.color }
    val center = area / 2
    val target = when {
        d != null && d.winner == YOU -> 210.dp
        d != null && d.winner == OPPONENT -> area - 210.dp
        d != null -> center
        s.gameOver -> if (s.winner == YOU) 64.dp else area - 64.dp
        else -> (center + 26.dp * (s.players[OPPONENT].score - s.players[YOU].score)).coerceIn(130.dp, maxOf(130.dp, area - 130.dp))
    }
    val line by animateDpAsState(target, tween(1100, easing = RiftEase), label = "territory")
    val leader = when {
        d != null -> d.winner
        s.players[YOU].score > s.players[OPPONENT].score -> YOU
        s.players[OPPONENT].score > s.players[YOU].score -> OPPONENT
        else -> -1
    }
    val lineColor by animateColorAsState(if (leader < 0) Color.White.copy(alpha = 0.7f) else colors[leader], tween(600), label = "lineColor")
    LegendPicture(art[OPPONENT], turned = true, middle = center, line = { line }, screen = screen)
    LegendPicture(art[YOU], turned = false, middle = center, line = { line }, screen = screen)
    // Each field is one screen tall, so the opponent's reaches the top and yours runs under the tab bar.
    Box(Modifier.fillMaxWidth().height(screen).graphicsLayer { translationY = (line - screen).toPx() }.background(fields[OPPONENT]))
    Box(Modifier.fillMaxWidth().height(screen).graphicsLayer { translationY = line.toPx() }.background(fields[YOU]))
    Box(
        Modifier.fillMaxWidth().height(2.dp)
            .graphicsLayer { translationY = (line - 1.dp).toPx() }
            .dropShadow(RectangleShape, Shadow(radius = 22.dp, color = lineColor, spread = 3.dp))
            .background(lineColor),
    )
    Column(Modifier.fillMaxWidth().height(area)) {
        Half(c, OPPONENT, board, Modifier.weight(1f).graphicsLayer { rotationZ = 180f }, art = art[OPPONENT] != null)
        Half(c, YOU, board, Modifier.weight(1f), art = art[YOU] != null, extend = screen - area)
    }
    Seam(c, match, Modifier.align(Alignment.TopCenter).offset(y = center - 27.dp).padding(horizontal = 10.dp))
}

/**
 * [art]: its legend's picture is behind it, so a shade behind the number and the mock's pills for art. [extend]: how
 * far its field runs on past its outer edge (under the tab bar), so the shade does too.
 */
@Composable
private fun Half(c: ScoreController, slot: Int, swatches: List<Swatch>, modifier: Modifier, art: Boolean = false, extend: Dp = 0.dp) {
    val s = c.state
    val d = c.duel
    val accent = swatches[slot].color
    val ink = swatches[slot].ink
    val dim = if (d != null) d.winner >= 0 && d.winner != slot else s.gameOver && s.winner != slot
    val alpha by animateFloatAsState(if (dim) 0.32f else 1f, tween(900, easing = RiftEase), label = "dim")
    // A tap on the score asks the action pills to light up.
    var cue by remember { mutableIntStateOf(0) }
    val shade by animateFloatAsState(if (art) 1f else 0f, tween(600), label = "shade")
    Box(modifier.fillMaxWidth().drawBehind { if (shade > 0f) legendShade(shade, extend.toPx()) }) {
        Column(Modifier.fillMaxSize().padding(start = 20.dp, end = 20.dp, top = 34.dp, bottom = 18.dp).graphicsLayer { this.alpha = alpha }) {
            if (d != null) {
                DuelSide(c, d, slot, accent, ink, Modifier.fillMaxSize())
            } else {
                TopLine(
                    c.legend(slot), accent, ink, s.starter == slot, s.players[slot].xp, { c.xp(slot, it) },
                    shown = !s.gameOver, onName = { c.openSetup(slot) },
                )
                Box(Modifier.weight(1f).fillMaxWidth().pointerInput(Unit) { detectTapGestures { cue++ } }, contentAlignment = Alignment.Center) {
                    ScoreNumber(s.players[slot].score, accent, won = s.winner == slot, label = "${haves(c.shortName(slot))} ${s.players[slot].score} of $TARGET points", shadowed = art)
                }
                when {
                    !s.gameOver -> ActionRow(accent, ink, { c.score(slot, PointKind.Conquer) }, { c.score(slot, PointKind.Hold) }, { c.score(slot, PointKind.Effect) }, { c.fix(slot) }, cue = cue, art = art)
                    s.winner == slot -> NextGameButton("Next game", accent, ink, c::nextGame)
                    else -> Spacer(Modifier.height(54.dp))
                }
            }
        }
        if (d == null && s.winner == slot) {
            ResultText("WIN", "${s.players[slot].score}–${s.players[1 - slot].score}", accent, Modifier.align(Alignment.TopCenter).padding(top = 80.dp))
        }
        if (d == null && s.asking == slot) {
            FinalPointSheet(accent, ink, { c.finalPoint(true) }, { c.finalPoint(false) }, Modifier.align(Alignment.BottomCenter).padding(12.dp))
        }
        if (d == null && c.startChooser() == slot && !s.gameOver) {
            StartChoiceSheet(accent, ink, { c.pickStart(true) }, { c.pickStart(false) }, Modifier.align(Alignment.BottomCenter).padding(12.dp))
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
        won || d.tie || (lost && d.dice.size > 2) -> null
        die.rolling -> "Rolling"
        die.value == null -> if (d.dice.size == 2) "Tap your half to roll" else "Tap your side to roll"
        d.winner < 0 -> "Waiting for $others"
        lost -> "$others rolled higher"
        else -> null
    }
    val head = when {
        d.tie -> "Tie · roll again"
        won -> "Higher roll"
        else -> null
    }
    val name = c.shortName(slot).let { if (slot == YOU && d.dice.size == 2 && it != "You") "$it · you" else it }
    DuelHalf(
        name, d.type, die, accent, ink, hint, head, if (d.tie) Color.White else accent,
        choosing = won && d.dice.size == 2, highlight = won,
        onRoll = { c.roll(slot) }, onFirst = { c.choose(DuelState.Choice.First) }, onSecond = { c.choose(DuelState.Choice.Second) },
        modifier = modifier, dieSize = dieSize,
    )
}

/**
 * Four players (no mock): a 2×2 table, the far side turned around, every corner in its own colour, the leading seat's
 * a little lighter. The near row's colours run on under the tab bar ([reserve]) like the duel's fields.
 */
@Composable
private fun BoxScope.FourPlayers(c: ScoreController, swatches: List<Swatch>, area: Dp, reserve: Dp) {
    val s = c.state
    val d = c.duel
    val top = s.players.maxOf { it.score }
    // Per seat: a tap on its score asks its action pills to light up.
    val cues = remember { mutableStateListOf(0, 0, 0, 0) }
    Column(Modifier.fillMaxWidth().height(area)) {
        listOf(listOf(0, 1), listOf(2, 3)).forEachIndexed { row, slots ->
            Row(Modifier.weight(1f).fillMaxWidth().graphicsLayer { rotationZ = if (row == 0) 180f else 0f }) {
                // The far row is turned as a whole, so its seats keep their places for the players across.
                (if (row == 0) slots.reversed() else slots).forEach { slot ->
                    val sw = swatches[slot].let { it.copy(color = SeatShade.lift(it.color)) }
                    val leading = top > 0 && s.players[slot].score == top
                    val field by animateColorAsState(SeatShade.deep(swatches[slot].color, if (leading) 1.125f else 1f), tween(600), label = "field")
                    val lost = d != null && d.winner >= 0 && d.winner != slot
                    val alpha by animateFloatAsState(if (lost) 0.32f else 1f, tween(900, easing = RiftEase), label = "dim")
                    Box(Modifier.weight(1f).fillMaxHeight().drawBehind { drawRect(field, size = size.copy(height = size.height + if (row == 1) reserve.toPx() else 0f)) }) {
                        Column(Modifier.fillMaxSize().padding(start = 12.dp, end = 12.dp, top = 22.dp, bottom = 14.dp).graphicsLayer { this.alpha = alpha }) {
                            if (d != null) {
                                DuelSide(c, d, slot, sw.color, sw.ink, Modifier.fillMaxSize(), dieSize = 110f)
                            } else {
                                TopLine(c.legend(slot), sw.color, sw.ink, s.starter == slot, s.players[slot].xp, { c.xp(slot, it) })
                                Box(Modifier.weight(1f).fillMaxWidth().pointerInput(Unit) { detectTapGestures { cues[slot]++ } }, contentAlignment = Alignment.Center) {
                                    ScoreNumber(s.players[slot].score, sw.color, won = false, label = s.players[slot].score.let { n -> "${haves(c.legend(slot))} $n ${if (n == 1) "point" else "points"}" }, showTarget = false, sizeDp = 112f)
                                }
                                ActionGrid(sw.color, sw.ink, { c.score(slot, PointKind.Conquer) }, { c.score(slot, PointKind.Hold) }, { c.score(slot, PointKind.Effect) }, { c.fix(slot) }, cue = cues[slot])
                            }
                        }
                    }
                }
            }
        }
    }
    Box(Modifier.width(1.dp).height(area).align(Alignment.TopCenter).background(Color.White.copy(alpha = 0.08f)))
    Seam(c, null, Modifier.align(Alignment.TopCenter).offset(y = area / 2 - 27.dp))
    if (d != null && d.winner >= 0) {
        val starter = d.starter()
        val drawn = swatches[starter].let { it.copy(color = SeatShade.lift(it.color)) }
        DuelBanner(
            title = "${c.shortName(starter)} starts",
            text = "${c.shortName(starter)} rolled ${d.dice[starter].value} on the ${d.type.label}, the highest roll at the table.",
            accent = drawn.color, ink = drawn.ink,
            onAgain = c::rollAgain, onStart = c::startGame,
            modifier = Modifier.align(Alignment.TopCenter).offset(y = area / 2 - 80.dp).padding(horizontal = 16.dp),
        )
    }
}

/** "You have", "Lee Sin has": the score labels read by TalkBack. */
private fun haves(name: String) = if (name == "You") "You have" else "$name has"
