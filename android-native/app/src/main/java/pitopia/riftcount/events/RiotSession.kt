package pitopia.riftcount.events

import android.util.Base64
import android.webkit.CookieManager
import java.net.URLDecoder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/** The player's PlayRiftbound session, read from the web view's cookies at call time and kept in memory only. */
class Credentials(
    /** `name=value; …` as a browser sends it to https://playriftbound.com. */
    val cookieHeader: String,
    /** The sooner of `__Secure-session_expiry` and the access token's own `exp` (minus a minute). */
    val expiresAt: Long?,
    /** Riot ID from `__Secure-id_hint`, only to find the player in an event's lists; never sent anywhere. */
    val gameName: String?,
    val tagLine: String?,
) {
    val isExpired: Boolean get() = expiresAt?.let { it <= System.currentTimeMillis() } ?: false
}

/**
 * iOS `PlayRiftboundSession`. The web view is the only place the session lives: signing out there (or the
 * cookies expiring) ends the app's access too. An expired session is renewed by an off-screen page load,
 * since the site's own code refreshes its cookies on every load. Main thread only.
 */
object RiotSession {
    const val ACCESS = "__Secure-access_token"
    private const val EXPIRY = "__Secure-session_expiry"
    private const val IDENTITY = "__Secure-id_hint"
    private const val SITE = "https://playriftbound.com"
    private const val FAILED_RENEWAL_PAUSE_MS = 20_000L

    /** Debug builds can stand in recorded credentials (see [DebugEvents]). */
    var override: (() -> Credentials?)? = null

    private var warmedUp = 0L
    private var warmUp: Deferred<Credentials?>? = null
    private var renewal: Deferred<Credentials?>? = null
    private var lastFailedRenewal = 0L
    // Warm-up and renewal belong to no caller (iOS: unstructured Tasks): every caller waits for the same one,
    // and one that leaves early (a screen closing) does not end it for the others.
    private val scope = CoroutineScope(SupervisorJob())

    /** Nil without a session cookie. */
    fun read(): Credentials? {
        override?.let { return it() }
        val header = runCatching { CookieManager.getInstance().getCookie(SITE) }.getOrNull().orEmpty()
        val cookies = header.split(";").mapNotNull { part ->
            val i = part.indexOf('=')
            if (i <= 0) null else part.substring(0, i).trim() to part.substring(i + 1).trim()
        }.toMap()
        val token = cookies[ACCESS] ?: return null
        val sessionExpiry = cookies[EXPIRY]?.let { IsoTime.parse(decode(it)) }
        val tokenExpiry = jwtExpiry(token)?.minus(60_000)
        val (name, tag) = cookies[IDENTITY]?.let(::identity) ?: (null to null)
        return Credentials(header, listOfNotNull(sessionExpiry, tokenExpiry).minOrNull(), name, tag)
    }

    /** Any PlayRiftbound cookie at all: someone has used the site in the app. */
    private fun hasSiteCookies(): Boolean =
        override != null || runCatching { CookieManager.getInstance().getCookie(SITE) }.getOrNull().orEmpty().isNotBlank()

    /**
     * Credentials good to use now: an expired session is renewed once. Nil when signed out; throws
     * [RiftError.SessionExpired] when the renewal did not help.
     */
    suspend fun valid(browser: RiftBrowser): Credentials? {
        var found = read()
        // The access cookie lives an hour; the site's silent sign-in brings it back on a page load. One warm-up
        // per ten minutes for someone who has cookies of the site, then an empty jar means signed out.
        if (found == null && hasSiteCookies()) {
            val running = warmUp?.takeIf { it.isActive }
                ?: if (System.currentTimeMillis() - warmedUp > 600_000) {
                    warmedUp = System.currentTimeMillis()
                    pageLoad(browser, 12) { read() }.also { warmUp = it }
                } else {
                    null
                }
            found = running?.await()
        }
        val credentials = found ?: return null
        return if (credentials.isExpired) renewed(browser) else credentials
    }

    /** One renewal at a time; for a while after one failed, callers fail at once (offline, or a new sign-in is needed). */
    suspend fun renewed(browser: RiftBrowser): Credentials {
        val task = renewal?.takeIf { it.isActive } ?: run {
            if (System.currentTimeMillis() - lastFailedRenewal < FAILED_RENEWAL_PAUSE_MS) throw RiftError.SessionExpired()
            pageLoad(browser, 16) { read()?.takeIf { !it.isExpired } }.also { renewal = it }
        }
        val result = task.await()
        if (result == null) {
            lastFailedRenewal = System.currentTimeMillis()
            throw RiftError.SessionExpired()
        }
        lastFailedRenewal = 0
        return result
    }

    /** A page load of the site in the web view, then the cookie jar read every half second until [get] answers. */
    private fun pageLoad(browser: RiftBrowser, tries: Int, get: () -> Credentials?): Deferred<Credentials?> =
        scope.async(Dispatchers.Main.immediate) {
            browser.refreshSession()
            repeat(tries) {
                get()?.let { return@async it }
                delay(500)
            }
            get()
        }

    /** For public operations: the session if still valid, else nothing. Never renews, never fails. */
    fun publicCredentials(): Credentials? = read()?.takeIf { !it.isExpired }

    private fun decode(value: String) = runCatching { URLDecoder.decode(value, "UTF-8") }.getOrDefault(value)

    /** `exp` of a JWT, unverified: only to know when to renew. */
    fun jwtExpiry(token: String): Long? {
        val payload = token.split('.').getOrNull(1) ?: return null
        val json = runCatching { String(Base64.decode(payload, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)) }.getOrNull() ?: return null
        val exp = runCatching { CompeteJson.parseToJsonElement(json).jsonObject["exp"]?.jsonPrimitive?.doubleOrNull }.getOrNull() ?: return null
        return (exp * 1000).toLong()
    }

    /** `{"acct":{"game_name":…,"tag_line":…}}`, percent-encoded. */
    private fun identity(raw: String): Pair<String?, String?> {
        val acct = runCatching { CompeteJson.parseToJsonElement(decode(raw)).jsonObject["acct"]?.jsonObject }.getOrNull() ?: return null to null
        fun field(vararg keys: String) = keys.firstNotNullOfOrNull { k -> acct[k]?.jsonPrimitive?.contentOrNull }
        return field("game_name", "gameName") to field("tag_line", "tagLine")
    }
}
