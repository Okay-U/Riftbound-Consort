package pitopia.riftcount.events

import android.annotation.SuppressLint
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.net.Uri
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.RenderProcessGoneDetail
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebStorage
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.net.toUri
import kotlinx.coroutines.delay
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/**
 * Domain lock of the in-app browser (iOS `PlayRiftboundPolicy`): top-level pages only on playriftbound.com,
 * Riot's Riftbound content site and the two Riot sign-in hosts; anything else goes to the system browser.
 */
object RiftPolicy {
    /** The events page, not the site's front page (Okay): lighter, and it asks to sign in. Riot adds the locale. */
    const val HOME = "https://playriftbound.com/events?tab=my-events"
    const val ADD_PASSWORD = "https://account.riotgames.com/"
    const val REFRESH_PAGE = "https://playriftbound.com/en-US/events?tab=my-events"
    private val allowedHosts = listOf("playriftbound.com", "riftbound.leagueoflegends.com", "authenticate.riotgames.com", "auth.riotgames.com")
    private val handOffSchemes = setOf("http", "https", "mailto", "tel")
    const val SOCIAL_BLOCKED =
        "Google, Apple, Facebook, Xbox and PlayStation sign-in don't work inside the app. Sign in with your Riot ID and password."

    private fun matches(host: String?, hosts: List<String>) = host?.lowercase()?.let { h -> hosts.any { h == it || h.endsWith(".$it") } } == true

    /** A top-level page the web view may show: https on the allowlist, or `about:` while a page sets up. */
    fun isAllowed(scheme: String?, host: String?): Boolean = when (scheme?.lowercase()) {
        "about" -> true
        "https" -> matches(host, allowedHosts)
        else -> false
    }

    fun isRiotHost(host: String?): Boolean = matches(host, listOf("riotgames.com"))

    fun canHandOff(scheme: String?) = scheme?.lowercase() in handOffSchemes

    fun isAllowed(url: Uri) = isAllowed(url.scheme, url.host)

    fun isRiotDomain(url: String?): Boolean = url != null && isRiotHost(url.toUri().host)
}

/**
 * The one PlayRiftbound web view (iOS `PlayRiftboundBrowser` + `PlayRiftboundWebModel`), kept while the app runs
 * so the page survives tab switches. The Riot session lives in the WebView's own cookie store (the Skip app's
 * too, so the update keeps the sign-in). The app never injects JavaScript and never sees credentials.
 */
class RiftBrowser(private val context: Context) {
    var url by mutableStateOf<String?>(null)
        private set
    var loading by mutableStateOf(false)
        private set
    var progress by mutableIntStateOf(0)
        private set
    var canGoBack by mutableStateOf(false)
        private set
    var canGoForward by mutableStateOf(false)
        private set
    /** A short notice (a blocked social sign-in); cleared on the next page. */
    var notice by mutableStateOf<String?>(null)
    var loadError by mutableStateOf<String?>(null)
        private set
    /** Set by [open]; the Events tab consumes it by switching to the PlayRiftbound section. */
    var pending by mutableStateOf<String?>(null)
    /** Bumped when the page process died and a fresh web view replaced it. */
    var generation by mutableIntStateOf(0)
        private set

    private var visible: WebView? = null
    private var refresher: WebView? = null
    private var refresherLoading = false

    /** The visible web view, created on first use. */
    fun webView(): WebView = visible ?: create(onScreen = true).also { visible = it }

    fun loadHomeIfNeeded() {
        if (webView().url == null) load(RiftPolicy.HOME)
    }

    fun load(target: String) {
        loadError = null
        webView().loadUrl(target)
    }

    /** Show a PlayRiftbound page in the app (deep links from the scoreboard and the event screens). */
    fun open(target: String) {
        pending = target
    }

    fun goBack() = visible?.goBack()
    fun goForward() = visible?.goForward()
    fun stop() = visible?.stopLoading()

    fun reload() {
        loadError = null
        val view = webView()
        if (view.url == null) load(RiftPolicy.HOME) else view.reload()
    }

    fun openOutside(target: String? = url) {
        target?.let { handOff(it.toUri()) }
    }

    /** Removes the Riot session and site data (only PlayRiftbound and Riot use this cookie store), then reloads home. */
    suspend fun signOut() {
        suspendCancellableCoroutine { cont -> CookieManager.getInstance().removeAllCookies { cont.resume(Unit) } }
        CookieManager.getInstance().flush()
        WebStorage.getInstance().deleteAllData()
        visible?.clearCache(true)
        visible?.clearHistory()
        load(RiftPolicy.HOME)
    }

    /**
     * Reloads the site so its own code renews the session cookies; returns once the page loaded (at most 15 s).
     * While the PlayRiftbound section shows nothing yet its web view does it, otherwise an invisible second one,
     * so the page the player looks at is never replaced.
     */
    suspend fun refreshSession() {
        val view = visible
        if (view == null || view.url == null) {
            load(RiftPolicy.REFRESH_PAGE)
            waitWhile { loading }
            return
        }
        val off = refresher ?: create(onScreen = false).also { refresher = it }
        refresherLoading = true
        off.loadUrl(RiftPolicy.REFRESH_PAGE)
        waitWhile { refresherLoading }
    }

    private suspend fun waitWhile(busy: () -> Boolean) {
        delay(250)
        for (i in 0 until 60) {
            if (!busy()) return
            delay(250)
        }
    }

    fun destroy() {
        listOfNotNull(visible, refresher).forEach { (it.parent as? ViewGroup)?.removeView(it); it.destroy() }
        visible = null
        refresher = null
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun create(onScreen: Boolean): WebView = WebView(context).apply {
        // Compose adds a view without its own params as wrap_content, and a wrap_content WebView lays pages out at
        // zero height: 100vh is 0, so Riot's sign-in form (in a 100vh scroller) collapsed under its background.
        layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        setBackgroundColor(Color.BLACK)
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.setSupportMultipleWindows(false)
        settings.javaScriptCanOpenWindowsAutomatically = false
        settings.mediaPlaybackRequiresUserGesture = !onScreen
        if (!onScreen) layout(0, 0, 390, 844)
        CookieManager.getInstance().setAcceptCookie(true)
        CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
        webViewClient = Client(onScreen)
        if (onScreen) webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView, newProgress: Int) {
                this@RiftBrowser.progress = newProgress
            }
        }
    }

    private inner class Client(private val onScreen: Boolean) : WebViewClient() {
        /** Sub-frames (captcha, consent) load freely; only top-level pages are policed. */
        override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
            if (!request.isForMainFrame) return false
            val target = request.url
            if (RiftPolicy.isAllowed(target)) return false
            // Nothing is ever handed out from the invisible web view.
            if (onScreen) decideHandOff(target)
            return true
        }

        override fun onPageStarted(view: WebView, url: String?, favicon: Bitmap?) {
            if (!onScreen) return
            notice = null
            loadError = null
            loading = true
            sync(view, url)
        }

        override fun onPageFinished(view: WebView, url: String?) {
            if (!onScreen) {
                refresherLoading = false
                return
            }
            loading = false
            sync(view, url)
        }

        override fun doUpdateVisitedHistory(view: WebView, url: String?, isReload: Boolean) {
            if (onScreen) sync(view, url)
        }

        override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
            if (!request.isForMainFrame) return
            if (!onScreen) {
                refresherLoading = false
                return
            }
            loading = false
            loadError = error.description?.toString()?.takeIf { it.isNotBlank() } ?: "The page could not be loaded."
        }

        /** The page process died (memory pressure): a fresh web view takes over, reloading where it was. */
        override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
            val last = view.url
            (view.parent as? ViewGroup)?.removeView(view)
            view.destroy()
            if (view === refresher) {
                refresher = null
                refresherLoading = false
            } else {
                visible = null
                generation++
                load(last ?: RiftPolicy.HOME)
            }
            return true
        }

        private fun sync(view: WebView, current: String?) {
            url = current ?: view.url
            canGoBack = view.canGoBack()
            canGoForward = view.canGoForward()
        }
    }

    /**
     * A non-Riot destination reached from a riotgames.com page is a third-party sign-in provider: blocked with a
     * notice, never handed off (the Riot session would land in the system browser). Riot's own off-allowlist pages
     * (password recovery, signup, legal) open outside like any other link.
     */
    private fun decideHandOff(target: Uri) {
        if (!RiftPolicy.canHandOff(target.scheme)) return
        val web = target.scheme?.lowercase() == "http" || target.scheme?.lowercase() == "https"
        if (web && RiftPolicy.isRiotDomain(url) && !RiftPolicy.isRiotHost(target.host)) {
            notice = RiftPolicy.SOCIAL_BLOCKED
            return
        }
        handOff(target)
    }

    private fun handOff(target: Uri) {
        try {
            context.startActivity(Intent(Intent.ACTION_VIEW, target))
        } catch (_: ActivityNotFoundException) {
            notice = "No app on this phone can open that link."
        }
    }
}
