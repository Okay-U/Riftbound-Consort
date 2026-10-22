package pitopia.riftcount.cards

import android.os.SystemClock
import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.BlurEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.toSize
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import pitopia.riftcount.data.DeckRules
import pitopia.riftcount.data.DecklistStore
import pitopia.riftcount.ui.common.LinkButton
import pitopia.riftcount.ui.common.Pill
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.theme.RiftEase
import pitopia.riftcount.ui.theme.RiftType

/** What the Cards tab remembers while another tab is open (iOS keeps the tab alive). */
class CardsUi {
    var query by mutableStateOf("")
    var filters by mutableStateOf(CardFilters())
    var sort by mutableStateOf(CardSort.Set)
    var shown by mutableStateOf<List<Card>>(emptyList())
    val grid = LazyGridState()

    /** Tiles play their entrance when this changes (tab opened, search or filters changed). */
    var generation by mutableIntStateOf(0)
        private set
    var generationAt by mutableLongStateOf(0L)
        private set

    fun replay() {
        generation++
        generationAt = SystemClock.uptimeMillis()
    }
}

private class OpenCard(val card: Card, val from: Rect)

private val CloseEase = CubicBezierEasing(0.2f, 0f, 0f, 1f)

@Composable
fun CardsScreen(
    ui: CardsUi,
    store: CardStore,
    errata: ErrataStore,
    decks: DecklistStore,
    bottomReserve: Dp,
    onOverlay: (Boolean) -> Unit,
    onNewDeck: (Card) -> Unit,
) {
    var open by remember { mutableStateOf<OpenCard?>(null) }
    var detailShown by remember { mutableStateOf(false) }
    var filtering by remember { mutableStateOf(false) }
    var adding by remember { mutableStateOf(false) }
    var replayPending by remember { mutableStateOf(false) }
    val hero = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()
    val overlay by rememberUpdatedState(onOverlay)
    val focus = LocalFocusManager.current
    // The keyboard goes away once the grid scrolls, as on iOS.
    LaunchedEffect(ui.grid.isScrollInProgress) { if (ui.grid.isScrollInProgress) focus.clearFocus() }

    LaunchedEffect(Unit) { ui.replay() }
    DisposableEffect(Unit) { onDispose { overlay(false) } }
    // Filtering 1400 cards per keystroke or slider step is wasted work: wait for a pause, like iOS.
    var appliedKey by remember { mutableStateOf<Any?>(null) }
    LaunchedEffect(store.revision, ui.query, ui.filters, ui.sort) {
        val key = Triple(ui.query, ui.filters, ui.sort)
        if (ui.shown.isNotEmpty()) delay(120)
        val next = withContext(Dispatchers.Default) { CardQuery.filter(store.cards, ui.query, ui.filters, ui.sort) }
        ui.shown = next
        if (key != appliedKey) {
            if (appliedKey != null) {
                ui.grid.scrollToItem(0)
                if (filtering) replayPending = true else ui.replay()
            }
            appliedKey = key
        }
    }

    fun openCard(card: Card, from: Rect) {
        if (open != null) return
        focus.clearFocus()
        open = OpenCard(card, from)
        detailShown = true
        overlay(true)
        scope.launch {
            hero.snapTo(0f)
            hero.animateTo(1f, tween(680, easing = RiftEase))
        }
    }

    fun closeCard() {
        if (!detailShown) return
        detailShown = false
        adding = false
        scope.launch {
            // The tab bar comes back once the detail's own bar has faded (the mock draws it under the backdrop).
            delay(180)
            overlay(false)
        }
        scope.launch {
            hero.animateTo(0f, tween(540, easing = CloseEase))
            open = null
        }
    }
    BackHandler(enabled = detailShown) { closeCard() }

    val pageAlpha by animateFloatAsState(if (detailShown) 0.16f else 1f, tween(520, easing = RiftEase), label = "behind")
    // Three columns on a phone like the mock, more in landscape or on a tablet (tiles stay about 100dp).
    val density = LocalDensity.current
    val widthPx = LocalWindowInfo.current.containerSize.width
    val columns = with(density) { ((widthPx - 22.dp.toPx()) / 106.dp.toPx()).toInt() }.coerceAtLeast(3)
    val tilePx = with(density) { ((widthPx - 32.dp.toPx() - 10.dp.toPx() * (columns - 1)) / columns).toInt() }

    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().graphicsLayer { alpha = pageAlpha }) {
            CardsHeader(ui.shown.size.takeIf { store.cards.isNotEmpty() })
            SearchField(ui.query) { ui.query = it }
            RuneRow(
                selected = ui.filters.domains,
                onAll = { ui.filters = ui.filters.copy(domains = emptySet()) },
                onToggle = { d -> ui.filters = ui.filters.copy(domains = ui.filters.domains.toggle(d)) },
            )
            CardControls(ui.sort, { ui.sort = it }, ui.filters.sheetCount) { filtering = true }
            when {
                store.cards.isEmpty() && store.error != null -> LoadState(store.error, onRetry = store::load)
                store.cards.isEmpty() -> LoadState(null, onRetry = null)
                ui.shown.isEmpty() && appliedKey != null -> NoMatches {
                    ui.query = ""
                    ui.filters = CardFilters()
                }
                else -> CardGrid(ui, errata, columns, tilePx, bottomReserve, open?.card?.id, ::openCard)
            }
        }
        open?.let { o ->
            CardDetail(
                card = o.card, from = o.from, progress = { hero.value }, shown = detailShown, tilePx = tilePx,
                erratum = errata.forCard(o.card), inDecks = decks.lists.count { DeckRules.count(o.card, it) > 0 },
                onClose = ::closeCard, onAdd = { adding = true },
            )
        }
    }
    if (filtering) {
        FilterSheet(
            filters = ui.filters, onChange = { ui.filters = it }, store = store,
            count = remember(store.revision, ui.query, ui.filters) { CardQuery.count(store.cards, ui.query, ui.filters) },
            onDismiss = {
                filtering = false
                if (replayPending) {
                    replayPending = false
                    ui.replay()
                }
            },
        )
    }
    val adding0 = open
    if (adding && adding0 != null && detailShown) {
        AddToDeckSheet(adding0.card, decks, store.index, onNewDeck = { onNewDeck(adding0.card) }) { adding = false }
    }
}

internal fun Set<String>.toggle(v: String) = if (v in this) this - v else this + v

@Composable
private fun CardGrid(ui: CardsUi, errata: ErrataStore, columns: Int, tilePx: Int, bottomReserve: Dp, hiddenId: String?, onOpen: (Card, Rect) -> Unit) {
    LazyVerticalGrid(
        columns = GridCells.Fixed(columns),
        state = ui.grid,
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 2.dp, bottom = bottomReserve + 32.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        itemsIndexed(ui.shown, key = { _, c -> c.id }) { i, card ->
            val coords = remember { arrayOfNulls<LayoutCoordinates>(1) }
            val art by rememberCardArt(card, tilePx)
            val t = rememberEntrance(i, ui.generation, ui.generationAt)
            Pressable(
                // The whole tile, also when the grid edge cuts it: boundsInRoot() would clip it.
                onClick = { coords[0]?.takeIf { it.isAttached }?.let { onOpen(card, Rect(it.positionInRoot(), it.size.toSize())) } },
                modifier = Modifier.aspectRatio(CARD_ASPECT)
                    .onGloballyPositioned { coords[0] = it }
                    .graphicsLayer {
                        val v = t.value
                        alpha = if (card.id == hiddenId) 0f else v
                        translationY = 16.dp.toPx() * (1f - v)
                        scaleX = 0.96f + 0.04f * v
                        scaleY = scaleX
                        val blur = 6.dp.toPx() * (1f - v)
                        renderEffect = if (blur > 0.5f) BlurEffect(blur, blur) else null
                    }
                    .semantics { contentDescription = tileLabel(card) },
                pressedScale = 0.96f,
            ) {
                CardFace(card, errata.forCard(card) != null, art, Modifier.fillMaxSize())
            }
        }
    }
}

private fun tileLabel(card: Card) = buildString {
    append(card.name).append(", ").append(CardStyle.kind(card))
    card.attributes?.energy?.let { append(", ").append(it).append(" energy") }
}

/** Staggered rise of the first 15 tiles; tiles that scroll in later just appear. */
@Composable
private fun rememberEntrance(index: Int, generation: Int, startedAt: Long): Animatable<Float, *> {
    val play = remember(generation) { SystemClock.uptimeMillis() - startedAt < 400 }
    val t = remember(generation) { Animatable(if (play) 0f else 1f) }
    if (play) {
        LaunchedEffect(generation) {
            delay(minOf(index, 14) * 34L)
            t.animateTo(1f, tween(760, easing = RiftEase))
        }
    }
    return t
}

@Composable
private fun LoadState(error: String?, onRetry: (() -> Unit)?) {
    Column(Modifier.fillMaxWidth().padding(horizontal = 32.dp, vertical = 80.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        BasicText(
            error ?: "Loading card database…",
            style = RiftType.Body.copy(fontSize = 15.sp, color = Color.White.copy(alpha = 0.8f), textAlign = TextAlign.Center),
        )
        if (error != null && onRetry != null) {
            Spacer(Modifier.height(16.dp))
            Pill("Retry", onRetry, Modifier.height(44.dp))
        }
    }
}

@Composable
private fun NoMatches(onReset: () -> Unit) {
    Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 60.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        BasicText("No cards match.", style = RiftType.Body.copy(fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.8f)))
        Spacer(Modifier.height(6.dp))
        LinkButton("Clear search and filters", onReset)
    }
}
