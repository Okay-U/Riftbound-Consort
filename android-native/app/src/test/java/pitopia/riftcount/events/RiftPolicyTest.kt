package pitopia.riftcount.events

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.yield
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RiftPolicyTest {
    @Test
    fun `the browser keeps to PlayRiftbound and Riot's two sign-in hosts`() {
        assertTrue(RiftPolicy.isAllowed("https", "playriftbound.com"))
        assertTrue(RiftPolicy.isAllowed("https", "events.playriftbound.com"))
        assertTrue(RiftPolicy.isAllowed("https", "riftbound.leagueoflegends.com"))
        assertTrue(RiftPolicy.isAllowed("https", "auth.riotgames.com"))
        assertTrue(RiftPolicy.isAllowed("HTTPS", "Authenticate.RiotGames.com"))
        assertTrue(RiftPolicy.isAllowed("about", null))
        // Not all of riotgames.com, no lookalikes, never plain http.
        assertFalse(RiftPolicy.isAllowed("https", "account.riotgames.com"))
        assertFalse(RiftPolicy.isAllowed("https", "www.riotgames.com"))
        assertFalse(RiftPolicy.isAllowed("https", "evilplayriftbound.com"))
        assertFalse(RiftPolicy.isAllowed("https", "playriftbound.com.example"))
        assertFalse(RiftPolicy.isAllowed("http", "playriftbound.com"))
        assertFalse(RiftPolicy.isAllowed("https", "accounts.google.com"))
        assertFalse(RiftPolicy.isAllowed("javascript", null))
    }

    @Test
    fun `only web, mail and phone links leave the app`() {
        assertTrue(RiftPolicy.canHandOff("https"))
        assertTrue(RiftPolicy.canHandOff("mailto"))
        assertTrue(RiftPolicy.canHandOff("tel"))
        assertFalse(RiftPolicy.canHandOff("intent"))
        assertFalse(RiftPolicy.canHandOff("file"))
        assertTrue(RiftPolicy.isRiotHost("auth.riotgames.com"))
        assertFalse(RiftPolicy.isRiotHost("accounts.google.com"))
    }
}

class OperationIdsTest {
    @Test
    fun `a first caller that leaves early does not cancel the feed for everyone else`() = runBlocking {
        val gate = CompletableDeferred<Unit>()
        val ids = OperationIds { gate.await(); mapOf("PlayerTournaments" to "f".repeat(64)) }
        val first = launch { ids.id("PlayerTournaments") }
        yield()
        first.cancelAndJoin()
        gate.complete(Unit)
        assertEquals("f".repeat(64), ids.id("PlayerTournaments"))
    }
}
