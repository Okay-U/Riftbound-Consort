//
//  PlayRiftboundView.swift
//  Riftbound Companiokay
//
//  Domain-locked in-app browser for PlayRiftbound.com (Riot's organized-play
//  site). Top-level navigation is allowed only on playriftbound.com and the two
//  Riot sign-in hosts; anything else is handed to Safari. The Riot session lives
//  in a web-view data store private to this feature, inside the app sandbox and
//  separate from the app's own URLSession cookie jar. The app never reads
//  cookies, never injects JavaScript, never sees credentials.
//
//  Known ceiling: third-party sign-in providers refuse embedded web views
//  (Google enforces it; the others are not supported here either). Riot ID +
//  password is the supported path; social-only accounts add a password at
//  account.riotgames.com first. See docs/IN_APP_BROWSER.md.
//

import SwiftUI
import WebKit
import os
internal import Combine

// MARK: - Policy

nonisolated enum PlayRiftboundPolicy {
    static let home = URL(string: "https://playriftbound.com/")!
    static let addPasswordURL = URL(string: "https://account.riotgames.com/")!

    /// Fixed identifier for this feature's own persistent web data store. Changing it
    /// orphans the stored Riot session (user signs in again).
    static let dataStoreID = UUID(uuidString: "6B1F3C2A-9D44-4E0B-8C7A-5F2E1D0B9A31")!

    /// Hosts allowed as top-level pages. Suffix match covers rgn./xsso. subdomains.
    /// playriftbound.com's own nav sends Card Gallery, News and Rules Hub to
    /// riftbound.leagueoflegends.com, so that official content site is included.
    /// Riot side is deliberately the two sign-in hosts only, not all of riotgames.com.
    static let allowedHosts = [
        "playriftbound.com",
        "riftbound.leagueoflegends.com",
        "authenticate.riotgames.com",
        "auth.riotgames.com",
    ]

    /// Registrable domains whose site data "Sign out of Riot" removes.
    static let sessionDomains = ["playriftbound.com", "riotgames.com"]

    /// Schemes handed to the system when a page links off the allowlist.
    static let handOffSchemes: Set<String> = ["http", "https", "mailto", "tel"]

    static func isAllowed(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return false }
        return allowedHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    static func isRiotDomain(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        return host == "riotgames.com" || host.hasSuffix(".riotgames.com")
    }

    static func ownsSiteData(named displayName: String) -> Bool {
        sessionDomains.contains { displayName == $0 || displayName.hasSuffix("." + $0) }
    }

    static let socialBlockedNotice =
        "Google, Apple, Facebook, Xbox and PlayStation sign-in don't work inside the app. Sign in with your Riot ID and password."
}

// MARK: - Model (owns the web view, is its delegate)

final class PlayRiftboundWebModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView

    @Published private(set) var progress: Double = 0
    @Published private(set) var isLoading = false
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var currentURL: URL?
    @Published var loadError: String?
    /// Short in-app notice (e.g. a blocked social sign-in). Cleared on the next navigation.
    @Published var notice: String?

    private var cancellables = Set<AnyCancellable>()
    private let log = Logger(subsystem: "pitopia.Riftcount", category: "PlayRiftbound")

    override init() {
        let config = WKWebViewConfiguration()
        // Own persistent store: keeps the Riot session across launches, isolated from
        // HTTPCookieStorage.shared and every URLSession in the app.
        config.websiteDataStore = WKWebsiteDataStore(forIdentifier: PlayRiftboundPolicy.dataStoreID)
        // iPhone default is fullscreen-only video: the site's muted background video then pops
        // into the system player whenever the app returns from Safari. Match Safari instead.
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        // WKWebView posts these on the main thread already; a RunLoop.main hop would stall
        // them while the page is being scrolled (tracking run-loop mode).
        webView.publisher(for: \.estimatedProgress).assign(to: &$progress)
        webView.publisher(for: \.isLoading).assign(to: &$isLoading)
        webView.publisher(for: \.canGoBack).assign(to: &$canGoBack)
        webView.publisher(for: \.canGoForward).assign(to: &$canGoForward)
        webView.publisher(for: \.url).assign(to: &$currentURL)
    }

    // MARK: Actions

    func loadHomeIfNeeded() {
        if webView.url == nil { loadHome() }
    }

    func loadHome() {
        loadError = nil
        webView.load(URLRequest(url: PlayRiftboundPolicy.home))
    }

    func goBack()    { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload() {
        loadError = nil
        if webView.url == nil { loadHome() } else { webView.reload() }
    }
    func stop() { webView.stopLoading() }

    func openCurrentInSafari() {
        guard let url = webView.url else { return }
        UIApplication.shared.open(url)
    }

    /// Removes cookies and site data for the Riot and PlayRiftbound domains, then reloads home.
    func signOutOfRiot() async {
        let store = webView.configuration.websiteDataStore
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await store.dataRecords(ofTypes: types)
        let ours = records.filter { PlayRiftboundPolicy.ownsSiteData(named: $0.displayName) }
        await store.removeData(ofTypes: types, for: ours)
        log.info("Riot web session cleared (\(ours.count) records)")
        loadHome()
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .cancel }
        // Sub-frames (captcha, consent) load freely; only top-level pages are policed.
        let isTopLevel = navigationAction.targetFrame == nil || navigationAction.targetFrame?.isMainFrame == true
        guard isTopLevel else { return .allow }
        #if DEBUG
        log.debug("policy type=\(navigationAction.navigationType.rawValue) \(url.host ?? "-")\(url.path)")
        #endif
        if url.scheme?.lowercased() == "about" { return .allow }   // about:blank during page setup
        if PlayRiftboundPolicy.isAllowed(url) { return .allow }
        handOff(url)
        return .cancel
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        loadError = nil
        notice = nil
        #if DEBUG
        navStart = Date()
        log.debug("nav start")
        #endif
    }

    #if DEBUG
    // Debug-only timing to see which navigations are real page loads (a back that
    // restores from the back/forward cache never reaches these) and how long they take.
    private var navStart: Date?
    private func elapsedMs() -> Int { Int((Date().timeIntervalSince(navStart ?? Date())) * 1000) }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        log.debug("nav commit \(webView.url?.host ?? "-")\(webView.url?.path ?? "") after \(self.elapsedMs()) ms")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        log.debug("nav finish \(webView.url?.host ?? "-")\(webView.url?.path ?? "") after \(self.elapsedMs()) ms")
    }
    #endif

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        report(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        report(error)
    }

    /// iOS kills a backgrounded app's web process under memory pressure; reload instead of
    /// showing an error. `url` reads nil after termination, the back-forward list survives.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        log.info("Web content process terminated, reloading")
        if webView.backForwardList.currentItem == nil { loadHome() } else { webView.reload() }
    }

    // MARK: WKUIDelegate

    /// target=_blank / window.open: allowed https pages load in this web view, the rest
    /// is handed to Safari. `about:blank` popups (scripts that set the URL later) are dropped
    /// rather than loaded over the current page.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }
        if PlayRiftboundPolicy.isAllowed(url) {
            webView.load(navigationAction.request)
        } else {
            handOff(url)
        }
        return nil
    }

    // MARK: Helpers

    /// Off-allowlist destination. A non-Riot destination reached from Riot's sign-in pages
    /// is a social provider, which cannot complete in an embedded web view, so it is blocked
    /// with a notice instead of leaking the sign-in into Safari's cookie jar. Riot's own
    /// off-allowlist pages (password recovery, signup, legal) open in Safari like any other link.
    private func handOff(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), PlayRiftboundPolicy.handOffSchemes.contains(scheme) else { return }
        if PlayRiftboundPolicy.isRiotDomain(webView.url), !PlayRiftboundPolicy.isRiotDomain(url),
           scheme == "http" || scheme == "https" {
            notice = PlayRiftboundPolicy.socialBlockedNotice
            log.info("Blocked third-party sign-in hop to \(url.host ?? "-")")
            return
        }
        log.info("Off-allowlist navigation handed to the system: \(url.host ?? url.scheme ?? "-")")
        UIApplication.shared.open(url)
    }

    private func report(_ error: Error) {
        let ns = error as NSError
        // -999 = cancelled (user navigated again); 102 = load interrupted by our own policy decision.
        if ns.code == NSURLErrorCancelled || (ns.domain == "WebKitErrorDomain" && ns.code == 102) { return }
        log.error("Navigation failed: \(ns.domain, privacy: .public) \(ns.code)")
        loadError = ns.localizedDescription
    }
}

// MARK: - View

struct PlayRiftboundView: View {
    @ObservedObject var model: PlayRiftboundWebModel

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            progressBar
            if let notice = model.notice {
                noticeCard(notice)
            } else if PlayRiftboundPolicy.isRiotDomain(model.currentURL) {
                signInHint
            }
            ZStack {
                WebViewContainer(webView: model.webView)
                if let message = model.loadError {
                    errorCard(message)
                }
            }
            // Keep the web view's frame fixed; WKWebView scrolls the focused field into view itself.
            .ignoresSafeArea(.keyboard)
        }
        .background(EventsTheme.bg)
        .onAppear { model.loadHomeIfNeeded() }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            navButton("chevron.left", label: "Back", enabled: model.canGoBack) { model.goBack() }
            navButton("chevron.right", label: "Forward", enabled: model.canGoForward) { model.goForward() }

            HStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold))
                Text(model.currentURL?.host ?? "playriftbound.com")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1).truncationMode(.middle)
            }
            .foregroundStyle(EventsTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .padding(.horizontal, 10)
            .eventsCard(radius: 10)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Current site \(model.currentURL?.host ?? "playriftbound.com")")

            navButton(model.isLoading ? "xmark" : "arrow.clockwise",
                      label: model.isLoading ? "Stop loading" : "Reload", enabled: true) {
                model.isLoading ? model.stop() : model.reload()
            }
            menu
        }
        .padding(.horizontal, 18).padding(.vertical, 8)
    }

    private func navButton(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(enabled ? EventsTheme.textPrimary : EventsTheme.textTertiary)
                .frame(width: 34, height: 34)
                .eventsCard(radius: 10)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private var menu: some View {
        Menu {
            Button("Home", systemImage: "house") { model.loadHome() }
            Button("Open in Safari", systemImage: "arrow.up.forward.app") { model.openCurrentInSafari() }
            Divider()
            Button("Sign out of Riot", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                Task { await model.signOutOfRiot() }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(EventsTheme.textPrimary)
                .frame(width: 34, height: 34)
                .eventsCard(radius: 10)
        }
        .accessibilityLabel("More")
    }

    @ViewBuilder
    private var progressBar: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(EventsTheme.green)
                .frame(width: geo.size.width * model.progress)
                .animation(.linear(duration: 0.15), value: model.progress)
        }
        .frame(height: 2)
        .opacity(model.isLoading ? 1 : 0)
    }

    /// Shown on Riot's sign-in pages: in-app login is Riot ID + password only.
    private var signInHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "key.fill").foregroundStyle(EventsTheme.green)
            Text("Sign in with your Riot ID and password. Signed up with Google, Apple or another provider? Add a Riot password first.")
                .font(.system(size: 12))
                .foregroundStyle(EventsTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            addPasswordLink
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
                .fixedSize(horizontal: false, vertical: true)
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
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .eventsCard(radius: 12)
        .padding(.horizontal, 18).padding(.bottom, 8)
    }

    private var addPasswordLink: some View {
        Link(destination: PlayRiftboundPolicy.addPasswordURL) {
            Label("Add", systemImage: "arrow.up.forward")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(EventsTheme.matchFillBottom)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(EventsTheme.green, in: Capsule())
        }
        .accessibilityLabel("Add a Riot password, opens Safari")
    }

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(EventsTheme.textSecondary)
            Text("Couldn't load PlayRiftbound")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(EventsTheme.textPrimary)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(EventsTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                model.reload()
            } label: {
                Text("Try again")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(EventsTheme.matchFillBottom)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(EventsTheme.green, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: 320)
        .eventsCard()
        .padding()
    }
}

private struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
