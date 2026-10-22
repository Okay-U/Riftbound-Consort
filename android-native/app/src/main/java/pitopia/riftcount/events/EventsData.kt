package pitopia.riftcount.events

import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit

/**
 * Everything the Events tab and the scoreboard read from PlayRiftbound: the player's registrations (iOS
 * `PlayRiftboundEventsStore`), tournaments by id, favourite stores (iOS `PlayRiftboundFavorites`) and the
 * scoreboard's pairing (iOS `PlayRiftboundMatchStore`). Main thread only.
 */
class EventsData(val api: RiftApi, val browser: RiftBrowser) {
    sealed interface State {
        data object Idle : State
        data object SignedOut : State
        data object Loading : State
        data object Loaded : State
        data class Failed(val message: String) : State
    }

    var state by mutableStateOf<State>(State.Idle)
        private set
    var upcoming by mutableStateOf(emptyList<TournamentEntry>())
        private set
    var past by mutableStateOf(emptyList<TournamentEntry>())
        private set
    /** Riot ID of the signed-in player, from the session cookie. */
    var me by mutableStateOf<Pair<String, String?>?>(null)
        private set

    val hasEvents get() = upcoming.isNotEmpty() || past.isNotEmpty()
    val signedIn get() = state != State.SignedOut && me != null

    private var lastLoaded = 0L
    private var inFlight: CompletableDeferred<Unit>? = null

    /** Callers always get a finished refresh; a forced one (after register / drop) loads again after a running one. */
    suspend fun refresh(force: Boolean = false) {
        inFlight?.let {
            it.await()
            if (!force) return
        }
        if (!force && System.currentTimeMillis() - lastLoaded < MIN_INTERVAL_MS) return
        val d = CompletableDeferred<Unit>()
        inFlight = d
        try {
            load()
        } finally {
            d.complete(Unit)
            if (inFlight === d) inFlight = null
        }
    }

    private suspend fun load() {
        if (!hasEvents) state = State.Loading
        try {
            val credentials = RiotSession.valid(browser)
            if (credentials == null) {
                upcoming = emptyList()
                past = emptyList()
                me = null
                state = State.SignedOut
                return
            }
            credentials.gameName?.let { me = it to credentials.tagLine }
            val mine = api.myTournaments(credentials)
            fun start(e: TournamentEntry) = e.tournament.startsAt ?: Long.MAX_VALUE
            upcoming = mine.playerTournaments.upcoming.nodes(TournamentEntry.serializer()).sortedBy(::start)
            past = mine.playerTournaments.past.nodes(TournamentEntry.serializer()).sortedByDescending(::start)
            lastLoaded = System.currentTimeMillis()
            state = State.Loaded
        } catch (e: CancellationException) {
            if (!hasEvents) state = State.Idle
            throw e
        } catch (e: Exception) {
            // A failed refresh keeps the last list; the error is for an empty screen.
            state = if (hasEvents) State.Loaded else State.Failed(e.message ?: "Couldn't load events.")
        }
    }

    // --- tournaments ----------------------------------------------------------------------------------

    private class Cached(val t: Tournament?, val at: Long)

    private val tournaments = mutableStateMapOf<String, Cached>()

    fun cached(id: String): Tournament? = tournaments[id]?.t

    /** One tournament, at most every 20 s unless [force]. Nil when Riot does not know it. */
    suspend fun tournament(id: String, force: Boolean = false): Tournament? {
        val hit = tournaments[id]
        if (!force && hit != null && System.currentTimeMillis() - hit.at < TOURNAMENT_TTL_MS) return hit.t
        val credentials = RiotSession.valid(browser) ?: throw RiftError.NotSignedIn()
        credentials.gameName?.let { me = it to credentials.tagLine }
        val fresh = api.tournament(id, credentials)
        tournaments[id] = Cached(fresh, System.currentTimeMillis())
        return fresh
    }

    /** Details of several list entries for their status and placement, two at a time; failures are skipped. */
    suspend fun prefetch(ids: List<String>) = coroutineScope {
        val gate = Semaphore(2)
        ids.map { id ->
            async { gate.withPermit { runCatching { tournament(id) } } }
        }.awaitAll()
    }

    fun playerId(t: Tournament): String? = me?.let { (name, tag) -> t.playerId(name, tag) }

    // --- favourite stores -----------------------------------------------------------------------------

    var favorites by mutableStateOf(emptyList<Organizer>())
        private set
    /** Nil until loaded once; false without a session. A heart shows only with the list in hand. */
    var favoritesSignedIn by mutableStateOf<Boolean?>(null)
        private set
    var favoritePending by mutableStateOf(emptySet<String>())
        private set
    private var favoriteChanges = 0

    fun isFavorite(id: String) = favorites.any { it.id == id }

    /** Keeps the list when the session cannot be renewed (offline) or a heart changed meanwhile. */
    suspend fun loadFavorites() {
        val credentials = try {
            RiotSession.valid(browser)
        } catch (_: RiftError) {
            return
        }
        if (credentials == null) {
            favoritesSignedIn = false
            favorites = emptyList()
            return
        }
        val before = favoriteChanges
        val fresh = runCatching { api.favorites(credentials) }.getOrNull() ?: return
        if (before != favoriteChanges || favoritePending.isNotEmpty()) return
        favorites = fresh
        favoritesSignedIn = true
    }

    /** Flips the heart at once and takes it back if Riot refuses. */
    suspend fun toggleFavorite(store: Organizer) {
        if (store.id in favoritePending) return
        favoritePending = favoritePending + store.id
        favoriteChanges++
        try {
            val credentials = RiotSession.valid(browser) ?: throw RiftError.NotSignedIn()
            val on = !isFavorite(store.id)
            favorites = if (on) favorites + store else favorites.filter { it.id != store.id }
            try {
                api.setFavorite(store.id, on, credentials)
            } catch (e: Exception) {
                favorites = if (on) favorites.filter { it.id != store.id } else favorites + store
                throw e
            }
        } finally {
            favoritePending = favoritePending - store.id
        }
    }

    // --- calendar: registered events and every favourite store's (iOS `PlayRiftboundCalendarView`) -------

    class CalEvent(val entry: TournamentEntry, val registered: Boolean) {
        val startsAt: Long get() = entry.tournament.startsAt ?: Long.MAX_VALUE
    }

    /** The favourite stores' events as last loaded. */
    private var storeEvents by mutableStateOf(emptyList<TournamentEntry>())

    /**
     * Registered events (always shown), then the favourite stores' others. Read from [upcoming] each time, so a
     * registration or a drop shows on the rail and in the month at once (they kept the state of the last load).
     */
    val calendar: List<CalEvent> by derivedStateOf { mergeCalendar(upcoming, storeEvents) }
    var calendarLoading by mutableStateOf(false)
        private set
    var calendarError by mutableStateOf<String?>(null)
        private set
    /** Favourite stores whose events could not be loaded this time. */
    var calendarFailedStores by mutableIntStateOf(0)
        private set
    private var calendarAt = 0L

    /** Registered events first (always shown), then each favourite store's, four stores at a time. */
    suspend fun loadCalendar(force: Boolean = false) {
        if (calendarLoading || (!force && System.currentTimeMillis() - calendarAt < CALENDAR_TTL_MS)) return
        calendarLoading = true
        calendarError = null
        try {
            refresh()
            val credentials = try {
                RiotSession.valid(browser)
            } catch (_: RiftError) {
                calendarError = "Couldn't refresh your PlayRiftbound session. Try again in a moment."
                null
            }
            if (credentials != null) {
                val stores = api.favorites(credentials)
                favorites = stores
                favoritesSignedIn = true
                val gate = Semaphore(4)
                val found = coroutineScope {
                    stores.map { store ->
                        async {
                            gate.withPermit {
                                runCatching {
                                    val summary = api.organizer(store.id, credentials)
                                    val lat = summary?.physicalAddress?.latitude
                                    val lng = summary?.physicalAddress?.longitude
                                    if (lat == null || lng == null) emptyList() else api.storeEvents(store.id, lat, lng, credentials)
                                }.getOrNull()
                            }
                        }
                    }.awaitAll()
                }
                calendarFailedStores = found.count { it == null }
                storeEvents = found.filterNotNull().flatten()
            } else if (calendarError == null) {
                // Signed out. A failed session refresh instead keeps the store events already shown.
                storeEvents = emptyList()
            }
            // Signed out there is nothing to keep: the first look after signing in loads at once.
            if (credentials != null) calendarAt = System.currentTimeMillis()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            calendarError = e.message
        } finally {
            calendarLoading = false
        }
    }

    // --- the scoreboard's event ------------------------------------------------------------------------

    /** The next registered event (running, or starting within three hours) and the player's pairing in it. */
    class Strip(val entry: TournamentEntry, val pairing: Pairing?)

    var strip by mutableStateOf<Strip?>(null)
        private set
    var stripRefreshing by mutableStateOf(false)
        private set
    var stripError by mutableStateOf<String?>(null)
        private set
    private var stripAt = 0L
    /** A forced refresh that came while another one was running (right after a report): it runs once more (iOS). */
    private var stripFollowUp = false

    /** Best effort: failures keep what is shown; only "no session" or "no event" clears it. */
    suspend fun refreshStrip(force: Boolean = false) {
        if (stripRefreshing) {
            if (force) stripFollowUp = true
            return
        }
        if (!force && System.currentTimeMillis() - stripAt < STRIP_INTERVAL_MS) return
        stripRefreshing = true
        try {
            loadStrip()
        } finally {
            stripRefreshing = false
        }
        if (stripFollowUp) {
            stripFollowUp = false
            refreshStrip(force = true)
        }
    }

    private suspend fun loadStrip() {
        try {
            val credentials = RiotSession.valid(browser)
            if (credentials == null) {
                strip = null
                stripError = null
                stripAt = System.currentTimeMillis()
                return
            }
            credentials.gameName?.let { me = it to credentials.tagLine }
            val mine = api.myTournaments(credentials)
            val horizon = System.currentTimeMillis() + LOOKAHEAD_MS
            val next = mine.playerTournaments.upcoming.nodes(TournamentEntry.serializer())
                .filter { (it.tournament.startsAt ?: Long.MAX_VALUE) <= horizon }
                .minByOrNull { it.tournament.startsAt ?: Long.MAX_VALUE }
            if (next == null) {
                strip = null
                stripError = null
                stripAt = System.currentTimeMillis()
                return
            }
            val t = tournament(next.tournament.id, force = true)
            strip = Strip(next, t?.let { tt -> playerId(tt)?.let { Pairing.latest(tt, it) } })
            stripError = null
            stripAt = System.currentTimeMillis()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            stripError = e.message
        }
    }

    /** An event still to play or running now: started at most eight hours ago, or starts within the hour (iOS). */
    fun isLive(e: TournamentEntry): Boolean {
        val start = e.tournament.startsAt ?: return false
        val now = System.currentTimeMillis()
        return start <= now + 3_600_000 && start >= now - 8 * 3_600_000
    }

    companion object {
        private const val MIN_INTERVAL_MS = 30_000L
        private const val TOURNAMENT_TTL_MS = 20_000L
        private const val STRIP_INTERVAL_MS = 45_000L
        private const val LOOKAHEAD_MS = 3 * 3_600_000L
        private const val CALENDAR_TTL_MS = 10 * 60_000L
    }
}

/** The calendar: the player's events marked registered, then the stores' others, once each, by start. */
internal fun mergeCalendar(mine: List<TournamentEntry>, stores: List<TournamentEntry>): List<EventsData.CalEvent> {
    val registered = mine.map { it.tournament.id }.toSet()
    val others = stores.filter { it.tournament.id !in registered }.distinctBy { it.tournament.id }
    return (mine.map { EventsData.CalEvent(it, true) } + others.map { EventsData.CalEvent(it, false) }).sortedBy { it.startsAt }
}
