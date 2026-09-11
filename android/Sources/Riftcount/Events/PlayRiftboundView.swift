import SwiftUI
import SkipWeb

// Domain-locked in-app browser for PlayRiftbound.com, ported from iOS. Top-level
// navigation only on playriftbound.com, Riot's official Riftbound content site and
// the two Riot sign-in hosts; anything else goes to the system browser. The Riot
// session lives in the WebView's own cookie store (Android CookieManager, app
// sandbox). The app never reads cookies, never injects JavaScript, never sees
// credentials. Riot ID + password is the supported sign-in (Google refuses embedded
// web views); social-only accounts add a password at account.riotgames.com first.
// See docs/PLAYRIFTBOUND.md.

// MARK: - Policy (identical to iOS)

enum PlayRiftboundPolicy {
    static let home = URL(string: "https://playriftbound.com/")!
    static let addPasswordURL = URL(string: "https://account.riotgames.com/")!

    /// Hosts allowed as top-level pages. Suffix match covers subdomains.
    static let allowedHosts = [
        "playriftbound.com",
        "riftbound.leagueoflegends.com",
        "authenticate.riotgames.com",
        "auth.riotgames.com",
    ]

    /// Android's shouldOverrideUrlLoading also fires for iframe navigations, so the
    /// frames Riot's pages embed (captcha, consent, tag manager) must pass silently.
    static let frameHosts = ["hcaptcha.com", "osano.com", "googletagmanager.com"]

    /// Schemes handed to the system when a page links off the allowlist.
    static let handOffSchemes: Set<String> = ["http", "https", "mailto", "tel"]

    static let socialBlockedNotice =
        "Google, Apple, Facebook, Xbox and PlayStation sign-in don't work inside the app. Sign in with your Riot ID and password."

    static func matches(_ url: URL, _ hosts: [String]) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return hosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    static func isAllowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        if scheme == "about" { return true }
        return scheme == "https" && matches(url, allowedHosts)
    }

    static func isFrameHost(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && matches(url, frameHosts)
    }

    static func isRiotDomain(_ url: URL?) -> Bool {
        guard let url else { return false }
        return matches(url, ["riotgames.com"])
    }
}

// MARK: - Model

@Observable @MainActor final class PlayRiftboundWebModel {
    let config = WebEngineConfiguration(
        javaScriptCanOpenWindowsAutomatically: false,
        allowsPullToRefresh: false,
        isOpaque: false
    )
    let navigator = WebViewNavigator(initialURL: PlayRiftboundPolicy.home)
    let webState = WebViewState()
    /// Short in-app notice (e.g. a blocked social sign-in). Cleared on the next navigation.
    var notice: String? = nil
    var showMenu = false

    func loadHome() { navigator.load(url: PlayRiftboundPolicy.home) }
    func reload() {
        if webState.url == nil { loadHome() } else { navigator.reload() }
    }
    func stop() { navigator.stopLoading() }
    func goBack() { navigator.goBack() }
    func goForward() { navigator.goForward() }

    /// Clears cookies and site data (CookieManager has no per-host removal; only Riot
    /// cookies ever live in this WebView), then reloads home.
    func signOutOfRiot() async {
        await navigator.clearCookies()
        try? await navigator.removeData(ofTypes: Set(WebSiteDataType.allCases), modifiedSince: Date.distantPast)
        logger.info("Riot web session cleared")
        loadHome()
    }

    /// SkipWeb's shouldOverrideUrlLoading contract: return true to cancel the navigation.
    /// A non-Riot destination reached from a riotgames.com page is a third-party identity
    /// provider: blocked with a notice, never handed off (the Riot session would land in the
    /// system browser). Riot's own off-allowlist pages (recovery, signup, legal) hand off.
    func shouldBlock(_ url: URL, open: (URL) -> Void) -> Bool {
        if PlayRiftboundPolicy.isAllowed(url) || PlayRiftboundPolicy.isFrameHost(url) { return false }
        guard let scheme = url.scheme?.lowercased(), PlayRiftboundPolicy.handOffSchemes.contains(scheme) else { return true }
        if PlayRiftboundPolicy.isRiotDomain(webState.url), !PlayRiftboundPolicy.isRiotDomain(url),
           scheme == "http" || scheme == "https" {
            notice = PlayRiftboundPolicy.socialBlockedNotice
            logger.info("Blocked third-party sign-in hop to \(url.host ?? "-")")
            return true
        }
        logger.info("Off-allowlist navigation handed to the system: \(url.host ?? url.scheme ?? "-")")
        open(url)
        return true
    }
}

// MARK: - View

struct PlayRiftboundView: View {
    let model: PlayRiftboundWebModel
    @Environment(\.openURL) var openURL
    @AppStorage("didDismissNewEventsIntro") var didDismissIntro = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            loadingBar
            if model.showMenu {
                menuPanel
            }
            if let notice = model.notice {
                noticeCard(notice)
            } else if PlayRiftboundPolicy.isRiotDomain(model.webState.url) {
                signInHint
            } else if LocatorSunset.isUpcoming, !didDismissIntro {
                introCard
            }
            SkipWeb.WebView(
                configuration: model.config,
                navigator: model.navigator,
                url: PlayRiftboundPolicy.home,
                state: Binding(get: { model.webState }, set: { _ in }),
                onNavigationCommitted: { model.notice = nil },
                shouldOverrideUrlLoading: { url in
                    model.shouldBlock(url) { openURL($0) }
                },
                // Keeps the engine (and the page) alive while the segment is switched away.
                persistentWebViewID: "playriftbound"
            )
        }
        .background(EventsTheme.bg)
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            navButton("chevron.left", enabled: model.webState.canGoBack) { model.goBack() }
            navButton("chevron.right", enabled: model.webState.canGoForward) { model.goForward() }

            HStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold))
                Text(model.webState.url?.host ?? "playriftbound.com")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(EventsTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .padding(.horizontal, 10)
            .eventsCard(radius: 10)

            // "arrow.clockwise" is unmapped on SkipUI; the .circle variant maps to Material Refresh.
            navButton(model.webState.isLoading ? "xmark" : "arrow.clockwise.circle", enabled: true) {
                if model.webState.isLoading { model.stop() } else { model.reload() }
            }
            navButton("ellipsis", enabled: true) { model.showMenu.toggle() }
        }
        .padding(.horizontal, 18).padding(.vertical, 8)
    }

    private func navButton(_ symbol: String, enabled: Bool, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(enabled ? EventsTheme.textPrimary : EventsTheme.textTertiary)
                .frame(width: 34, height: 34)
                .eventsCard(radius: 10)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    /// Thin green bar while a page loads. (Android only reports progress at page start
    /// and end, so a real progress fraction would just jump.)
    private var loadingBar: some View {
        Rectangle()
            .fill(EventsTheme.green)
            .frame(height: 2)
            .opacity(model.webState.isLoading ? 1 : 0)
    }

    /// Inline panel instead of Menu (Menu collapses sibling layout on Compose).
    private var menuPanel: some View {
        HStack(spacing: 8) {
            menuButton("Home") { model.showMenu = false; model.loadHome() }
            menuButton("Open in browser") {
                model.showMenu = false
                if let url = model.webState.url { openURL(url) }
            }
            Spacer(minLength: 0)
            Button {
                model.showMenu = false
                Task { await model.signOutOfRiot() }
            } label: {
                Text("Sign out of Riot")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.red)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(Color.red.opacity(0.15)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .eventsCard(radius: 13)
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }

    private func menuButton(_ title: String, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(EventsTheme.textPrimary)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(EventsTheme.cardInset))
        }
        .buttonStyle(.plain)
    }

    /// Shown on Riot's sign-in pages: in-app login is Riot ID + password only.
    private var signInHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill").foregroundStyle(EventsTheme.green)
            Text("Sign in with your Riot ID and password. Signed up with Google, Apple or another provider? Add a Riot password first.")
                .font(.system(size: 12))
                .foregroundStyle(EventsTheme.textSecondary)
            Spacer(minLength: 4)
            addPasswordLink
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .eventsCard(radius: 12)
        .padding(.horizontal, 18).padding(.bottom, 8)
    }

    /// Shown until Sept 14: what this segment is for. Same style as the sign-in hint.
    private var introCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar").foregroundStyle(EventsTheme.green)
            Text("From September 14, your events, pairings and results appear here. Sign in with your Riot ID.")
                .font(.system(size: 12))
                .foregroundStyle(EventsTheme.textSecondary)
            Spacer(minLength: 4)
            Button {
                didDismissIntro = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(EventsTheme.textSecondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .eventsCard(radius: 12)
        .padding(.horizontal, 18).padding(.bottom, 8)
    }

    private func noticeCard(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(EventsTheme.gold)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(EventsTheme.textPrimary)
            Spacer(minLength: 4)
            addPasswordLink
            Button {
                model.notice = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(EventsTheme.textSecondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .eventsCard(radius: 12)
        .padding(.horizontal, 18).padding(.bottom, 8)
    }

    private var addPasswordLink: some View {
        Link(destination: PlayRiftboundPolicy.addPasswordURL) {
            Text("Add")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(EventsTheme.matchFillBottom)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(EventsTheme.green))
        }
    }
}
