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
internal import Combine

@MainActor
final class PlayRiftboundBrowser: ObservableObject {
    @Published private(set) var model: PlayRiftboundWebModel?
    /// Set by `open(_:)`; EventsHomeView consumes it by switching to New Events and loading it.
    @Published var pendingURL: URL?

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

    /// Reload the site off-screen so its own code renews the session cookies.
    /// Returns once the page finished loading (or after a timeout); the caller re-reads the cookies.
    func refreshSession() async {
        let model = ensureModel()
        model.load(Self.refreshPage)
        // Poll instead of a delegate continuation: one call site, and a stuck load must not hang it.
        for _ in 0..<60 {
            try? await Task.sleep(for: .milliseconds(250))
            if !model.isLoading { return }
        }
    }
}
