package pitopia.riftcount.decks

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.Dp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import pitopia.riftcount.cards.CardStore
import pitopia.riftcount.data.AppSettings
import pitopia.riftcount.data.DeckText
import pitopia.riftcount.data.Decklist
import pitopia.riftcount.data.DecklistStore
import pitopia.riftcount.data.GameRecord
import pitopia.riftcount.data.GameRecordStore
import pitopia.riftcount.tour.BuilderTip
import pitopia.riftcount.ui.common.ToastHost
import pitopia.riftcount.ui.common.Toaster
import pitopia.riftcount.ui.theme.RiftEase

private class Opened(val id: String, val from: Rect)
private class LogOpen(val deckId: String?, val from: Rect, val tile: String?)

private val MorphBack = CubicBezierEasing(0.2f, 0f, 0f, 1f)

/** The Decks tab: the table of piles with everything that opens from it. */
@Composable
fun DecksScreen(ui: DecksUi, decks: DecklistStore, games: GameRecordStore, cards: CardStore, bottomReserve: Dp, onOverlay: (Boolean) -> Unit) {
    val index = cards.index
    val pool = cards.cards
    val toaster = remember { Toaster() }
    val scope = rememberCoroutineScope()
    val now = { System.currentTimeMillis() }

    var opened by remember { mutableStateOf<Opened?>(null) }
    var detailShown by remember { mutableStateOf(false) }
    val morph = remember { Animatable(0f) }
    var sheet by remember { mutableStateOf<DeckTool?>(null) }

    var log by remember { mutableStateOf<LogOpen?>(null) }
    var logShown by remember { mutableStateOf(false) }
    var logDeck by remember { mutableStateOf<String?>(null) }
    var reviewId by remember { mutableStateOf<String?>(null) }
    var reviewShown by remember { mutableStateOf(false) }
    var editing by remember { mutableStateOf<GameRecord?>(null) }
    var importing by remember { mutableStateOf(false) }
    var builderShown by remember { mutableStateOf(false) }
    var shortlistShown by remember { mutableStateOf(false) }

    LaunchedEffect(ui.draft != null) { builderShown = ui.draft != null }
    val overlay = detailShown || logShown || builderShown
    val report by rememberUpdatedState(onOverlay)
    LaunchedEffect(overlay) {
        // The tab bar comes back once the overlay's own controls have faded.
        if (!overlay) delay(180)
        report(overlay)
    }
    DisposableEffect(Unit) { onDispose { report(false) } }

    fun openDeck(deck: Decklist, from: Rect) {
        if (opened != null) return
        opened = Opened(deck.id, from)
        detailShown = true
        scope.launch {
            morph.snapTo(0f)
            morph.animateTo(1f, tween(700, easing = RiftEase))
        }
    }
    fun closeDeck() {
        if (!detailShown) return
        detailShown = false
        sheet = null
        scope.launch {
            delay(80)
            morph.animateTo(0f, tween(560, easing = MorphBack))
            opened = null
        }
    }
    fun openLog(deckId: String?, from: Rect, tile: String?) {
        log = LogOpen(deckId, from, tile)
        logDeck = deckId
        logShown = true
    }
    fun closeLog() {
        logShown = false
        scope.launch {
            delay(520)
            if (!logShown) log = null
        }
    }
    fun closeReview() {
        reviewShown = false
        scope.launch {
            delay(620)
            if (!reviewShown) reviewId = null
        }
    }
    fun closeBuilder() {
        builderShown = false
        scope.launch {
            delay(640)
            if (!builderShown) ui.close()
        }
    }

    BackHandler(enabled = builderShown || reviewShown || logShown || detailShown) {
        when {
            builderShown -> if (ui.step.ordinal > 0) ui.step = BuildStep.entries[ui.step.ordinal - 1] else closeBuilder()
            reviewShown -> closeReview()
            logShown -> closeLog()
            else -> closeDeck()
        }
    }

    val awayAlpha by animateFloatAsState(if (detailShown) 0f else if (logShown && opened == null) 0.12f else 1f, tween(520, easing = RiftEase), label = "home")
    val awayScale by animateFloatAsState(if (detailShown) 0.94f else 1f, tween(620, easing = RiftEase), label = "homeScale")

    Box(Modifier.fillMaxSize()) {
        DecksHome(
            decks.lists, games.records, index,
            // The tile is back under the closing panel at once, so the two cross-fade.
            hiddenDeck = opened?.id, hiddenTile = log?.tile?.takeIf { logShown },
            bottomReserve = bottomReserve,
            onOpenDeck = ::openDeck,
            onNewDeck = { ui.startBuilder() },
            onShortlist = { shortlistShown = true },
            onImport = { importing = true },
            onOpenLog = { tile, from -> openLog(null, from, tile) },
            modifier = Modifier.graphicsLayer { alpha = awayAlpha; scaleX = awayScale; scaleY = awayScale },
        )
        opened?.let { o ->
            val deck = decks.find(o.id)
            if (deck == null) {
                LaunchedEffect(Unit) { closeDeck() }
            } else {
                DeckDetail(
                    deck, index, Tally.of(games.records.filter { it.deckId.equals(deck.id, true) }), o.from, detailShown, { morph.value },
                    onClose = ::closeDeck,
                    onTool = { tool, rect ->
                        if (tool == DeckTool.Log) openLog(deck.id, rect ?: o.from, null) else sheet = tool
                    },
                )
            }
        }
        log?.let { l ->
            LogPanel(
                l.from, logShown, logDeck, decks.lists, games.records,
                onFilter = { logDeck = it },
                onClose = ::closeLog,
                onOpenGame = { g ->
                    reviewId = g.id
                    reviewShown = true
                },
            )
        }
        reviewId?.let { id ->
            games.records.firstOrNull { it.id == id }?.let { g ->
                GameReview(g, decks.lists, reviewShown, onBack = ::closeReview, onEdit = { editing = g })
            }
        }
        if (ui.draft != null) {
            BuilderView(
                ui, builderShown, pool, index, onToast = toaster::show,
                onSave = { d ->
                    val deck = Builder.toDeck(d, pool, now())
                    if (d.editing != null) decks.replace(deck) else decks.add(deck)
                    toaster.show(if (d.editing != null) "Saved ${deck.name}" else "${deck.name} is on your table")
                    closeBuilder()
                },
                onClose = ::closeBuilder,
            )
        }
        if (builderShown && !AppSettings.didSeeBuilderTip.on) BuilderTip { AppSettings.didSeeBuilderTip.on = true }
        ToastHost(toaster)
    }

    val open = opened?.let { decks.find(it.id) }
    if (open != null && detailShown) {
        when (sheet) {
            DeckTool.Hand -> HandSheet(open, index) { sheet = null }
            DeckTool.Odds -> OddsSheet(open, index) { sheet = null }
            DeckTool.Stats -> StatsSheet(open, index) { sheet = null }
            DeckTool.Champion -> ChampionSheet(open, index, pool, onPick = { c ->
                decks.replace(DeckEdits.champion(open, c, now()))
                toaster.show("${c.title} is your champion")
            }) { sheet = null }
            DeckTool.Fields -> FieldsSheet(open, pool, onToggle = { c ->
                DeckEdits.toggleBattlefield(open, c, now())?.let { decks.replace(it); true } ?: false
            }) { sheet = null }
            DeckTool.Export -> ExportSheet(open, index, onCopied = { toaster.show("Deck list copied") }) { sheet = null }
            DeckTool.Menu -> DeckMenuSheet(
                open,
                onRename = { decks.rename(open.id, it) },
                onEdit = { ui.edit(Builder.fromDeck(open, index)) },
                onDelete = {
                    decks.delete(open.id)
                    toaster.show("Deleted ${open.name}")
                },
            ) { sheet = null }
            DeckTool.Issues -> IssuesSheet(open, index) { sheet = null }
            DeckTool.Log, null -> Unit
        }
    }
    editing?.let { g ->
        EditGameDialog(
            g, decks.lists, cards.legendNames,
            onSave = {
                games.update(it)
                editing = null
                toaster.show("Game updated")
            },
            onDelete = {
                games.delete(g.id)
                editing = null
                closeReview()
                toaster.show("Game deleted")
            },
        ) { editing = null }
    }
    if (shortlistShown) ShortlistSheet(index) { shortlistShown = false }
    if (importing) {
        ImportDialog(pool, onImport = { parsed ->
            val name = parsed.legend?.let { "Imported · ${it.title}" } ?: "Imported deck"
            val deck = DeckText.toDeck(parsed, name, pool, now())
            decks.add(deck)
            toaster.show("Imported ${deck.mainDeck.sumOf { it.count }} cards, open the pile to finish it")
        }) { importing = false }
    }
}
