//
//  PlayRiftboundBrowser.swift
//  Riftbound Companiokay
//
//  App-wide owner of the single PlayRiftbound web view. Created lazily on first
//  use, then kept so the page survives tab and segment switches. Two jobs beyond
//  hosting: deep links from other tabs into New Events, and refreshing the Riot
//  session without the player doing anything (the site renews its cookies on any
//  page load, so an off-screen load of the events page is enough).
//

import SwiftUI
import WebKit
internal import Combine

@MainActor
final class PlayRiftboundBrowser: ObservableObject {
    @Published private(set) var model: PlayRiftboundWebModel?
    /// Set by `open(_:)`; EventsHomeView consumes it by switching to New Events and loading it.
    @Published var pendingURL: URL?
    /// Set by `openEvent(_:)`; the redesign's Events tab pushes its native event screen.
    @Published var pendingEventID: String?

    @AppStorage("currentTab") private var currentTab: String = "score"

    private static let refreshPage = URL(string: "https://playriftbound.com/en-US/events?tab=my-events")!

    func ensureModel() -> PlayRiftboundWebModel {
        if let model { return model }
        let created = PlayRiftboundWebModel()
        model = created
        return created
    }

    /// Show a PlayRiftbound page inside the app: switch to the Events tab, New Events segment.
    func open(_ url: URL) {
        pendingURL = url
        currentTab = "events"
    }

    /// Show an event's native screen (redesign): switch to the Events tab, which pushes it.
    func openEvent(_ id: String) {
        pendingEventID = id
        currentTab = "events"
    }

    /// Reload the site off-screen so its own code renews the session cookies.
    /// Returns once the page finished loading (or after a timeout); the caller re-reads the cookies.
    /// While the PlayRiftbound segment has nothing loaded yet this loads its web view (which
    /// pre-loads the segment); once it shows a page, a second, invisible web view on the same
    /// data store does the work, so the page the player is looking at is never replaced.
    func refreshSession() async {
        let model = ensureModel()
        if model.currentURL == nil {
            model.load(Self.refreshPage)
            await waitWhileLoading { model.isLoading }
            return
        }
        let view = refresher ?? makeRefresher()
        view.load(URLRequest(url: Self.refreshPage))
        await waitWhileLoading { view.isLoading }
    }

    private var refresher: WKWebView?
    private let refresherPolicy = OffscreenPolicy()

    private func makeRefresher() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore(forIdentifier: PlayRiftboundPolicy.dataStoreID)
        config.mediaTypesRequiringUserActionForPlayback = .all
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        view.navigationDelegate = refresherPolicy
        refresher = view
        return view
    }

    /// Poll instead of a delegate continuation: a stuck load must not hang the caller.
    private func waitWhileLoading(_ isLoading: () -> Bool) async {
        for _ in 0..<60 {
            try? await Task.sleep(for: .milliseconds(250))
            if !isLoading() { return }
        }
    }
}

/// Same top-level allowlist as the visible web view; nothing is ever handed to Safari
/// from the invisible one.
private final class OffscreenPolicy: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .cancel }
        let isTopLevel = navigationAction.targetFrame == nil || navigationAction.targetFrame?.isMainFrame == true
        guard isTopLevel else { return .allow }
        if url.scheme?.lowercased() == "about" { return .allow }
        return PlayRiftboundPolicy.isAllowed(url) ? .allow : .cancel
    }
}
