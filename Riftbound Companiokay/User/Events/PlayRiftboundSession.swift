//
//  PlayRiftboundSession.swift
//  Riftbound Companiokay
//
//  Reads the player's PlayRiftbound session out of the New Events web view's own
//  data store, at call time, into memory. Nothing is copied anywhere else: the
//  web view remains the only place the session lives, and signing out there
//  (or the cookies expiring) ends the app's access as well.
//

import Foundation
import WebKit

nonisolated struct PlayRiftboundCredentials: Sendable {
    /// `name=value; …` for every cookie scoped to playriftbound.com.
    let cookieHeader: String
    /// From `__Secure-session_expiry`; the site refreshes the session on page loads.
    let expiry: Date?

    var isExpired: Bool { expiry.map { $0 <= Date() } ?? false }
}

nonisolated enum PlayRiftboundSession {
    static let accessCookie = "__Secure-access_token"
    static let expiryCookie = "__Secure-session_expiry"

    /// nil when the player has never signed in on New Events (or signed out there).
    /// WebKit's data store is main-thread only, hence the explicit isolation.
    @MainActor
    static func credentials() async -> PlayRiftboundCredentials? {
        let store = WKWebsiteDataStore(forIdentifier: PlayRiftboundPolicy.dataStoreID)
        let cookies = await store.httpCookieStore.allCookies()
        let site = cookies.filter { $0.domain.lowercased().hasSuffix("playriftbound.com") }
        guard site.contains(where: { $0.name == accessCookie }) else { return nil }

        let header = site.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        let expiry = site.first { $0.name == expiryCookie }
            .flatMap { $0.value.removingPercentEncoding }
            .flatMap { ISO8601DateFormatter().date(from: $0) }
        return PlayRiftboundCredentials(cookieHeader: header, expiry: expiry)
    }
}
