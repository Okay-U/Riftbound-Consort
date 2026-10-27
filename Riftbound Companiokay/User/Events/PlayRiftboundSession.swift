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
    /// Riot ID from the site's `__Secure-id_hint` cookie; used only to find the player in a
    /// tournament's registrant list. Never sent anywhere.
    let gameName: String?
    let tagLine: String?

    var isExpired: Bool { expiry.map { $0 <= Date() } ?? false }
}

nonisolated enum PlayRiftboundSession {
    static let accessCookie = "__Secure-access_token"
    static let expiryCookie = "__Secure-session_expiry"
    static let identityCookie = "__Secure-id_hint"

    private struct IDHint: Decodable {
        struct Account: Decodable { let gameName: String?; let tagLine: String? }
        let acct: Account?
        enum CodingKeys: String, CodingKey { case acct }
    }

    private static func identity(from value: String) -> (String?, String?) {
        guard let json = value.removingPercentEncoding?.data(using: .utf8) else { return (nil, nil) }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let hint = try? decoder.decode(IDHint.self, from: json)
        return (hint?.acct?.gameName, hint?.acct?.tagLine)
    }

    /// nil when the player has never signed in on New Events (or signed out there).
    /// One off-screen warm-up load per process, shared by every caller; afterwards an empty
    /// cookie jar means signed out. The site's silent sign-in finishes after the page load,
    /// so the warm-up keeps polling for cookies a few seconds.
    @MainActor private static var warmUp: Task<Void, Never>?
    @MainActor private static var warmUpStarted: Date?

    @MainActor
    private static func warmUpOnce(via browser: PlayRiftboundBrowser) async {
        // A warm-up that found nothing (offline at launch, or signed out) may run again later.
        if let started = warmUpStarted, Date().timeIntervalSince(started) > 600 { warmUp = nil }
        if warmUp == nil {
            warmUpStarted = Date()
            warmUp = Task {
                await browser.refreshSession()
                for _ in 0..<12 {
                    if await credentials() != nil { return }
                    try? await Task.sleep(for: .milliseconds(500))
                }
            }
        }
        await warmUp?.value
    }

    /// Credentials that are good to use now: an expired session is renewed once
    /// through an off-screen page load. Nil when the player is signed out, or
    /// `.sessionExpired` when the renewal did not help.
    @MainActor
    static func validCredentials(refreshingVia browser: PlayRiftboundBrowser) async throws -> PlayRiftboundCredentials? {
        var found = await credentials()
        if found == nil {
            // WebKit hands out a data store's cookies only after a web view has used it in
            // this process, so a cold start looks signed out until the PlayRiftbound segment
            // was opened once. Load the site off-screen in our own web view (the one that
            // segment shows), then read again.
            await warmUpOnce(via: browser)
            found = await credentials()
        }
        guard let credentials = found else { return nil }
        guard credentials.isExpired else { return credentials }
        return try await renewed(via: browser)
    }

    /// Reloads the site off-screen and waits for fresh cookies. Riot's silent sign-in
    /// (xsso iframe → auth.riotgames.com, prompt=none) finishes after the page load, so a
    /// single read right after the load can still see the old token. One renewal at a time.
    @MainActor private static var renewal: Task<PlayRiftboundCredentials?, Never>?
    /// When the last renewal failed. For a short while callers fail at once instead of each
    /// loading the site again: offline, or a Riot session that needs a new sign-in.
    @MainActor private static var lastFailedRenewal: Date?
    private static let failedRenewalPause: TimeInterval = 20

    @MainActor
    static func renewed(via browser: PlayRiftboundBrowser) async throws -> PlayRiftboundCredentials {
        if renewal == nil, let failed = lastFailedRenewal, Date().timeIntervalSince(failed) < failedRenewalPause {
            throw PlayRiftboundError.sessionExpired
        }
        let task = renewal ?? Task {
            await browser.refreshSession()
            for _ in 0..<16 {
                if let fresh = await credentials(), !fresh.isExpired { return fresh }
                try? await Task.sleep(for: .milliseconds(500))
            }
            return nil
        }
        renewal = task
        let result = await task.value
        // Only the renewal this caller waited for; a newer one may have started meanwhile.
        if renewal == task { renewal = nil }
        guard let result else {
            lastFailedRenewal = Date()
            throw PlayRiftboundError.sessionExpired
        }
        lastFailedRenewal = nil
        return result
    }

    /// For public operations (search, store details): the session if it is still valid,
    /// otherwise nothing. Never renews and never fails, so public data loads either way.
    @MainActor
    static func publicCredentials() async -> PlayRiftboundCredentials? {
        guard let found = await credentials(), !found.isExpired else { return nil }
        return found
    }

    /// `exp` claim of a JWT, without verifying it (we only need to know when to renew).
    nonisolated static func jwtExpiry(_ token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload += "=" }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? Double else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    /// WebKit's data store is main-thread only, hence the explicit isolation.
    @MainActor
    static func credentials() async -> PlayRiftboundCredentials? {
        let store = WKWebsiteDataStore(forIdentifier: PlayRiftboundPolicy.dataStoreID)
        let cookies = await store.httpCookieStore.allCookies()
        func bareDomain(_ cookie: HTTPCookie) -> String {
            var domain = cookie.domain.lowercased()
            if domain.hasPrefix(".") { domain.removeFirst() }
            return domain
        }
        // Everything Riot set for the site, for reading the session's own cookies…
        let site = cookies.filter { bareDomain($0) == "playriftbound.com" || bareDomain($0).hasSuffix(".playriftbound.com") }
        guard site.contains(where: { $0.name == accessCookie }) else { return nil }
        // …but the header carries only what a browser sends to https://playriftbound.com itself
        // (apex or domain-wide cookies, not host-only cookies of xsso. / events.). Should the
        // access token ever live elsewhere, fall back to the whole set as before.
        let apex = site.filter { bareDomain($0) == "playriftbound.com" }
        let sent = apex.contains(where: { $0.name == accessCookie }) ? apex : site
        let header = sent.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        let sessionExpiry = site.first { $0.name == expiryCookie }
            .flatMap { $0.value.removingPercentEncoding }
            .flatMap { ISO8601DateFormatter().date(from: $0) }
        // The access token is a JWT that expires after an hour; the session cookie lasts
        // longer, so the token's own `exp` (minus a minute of slack) is what counts.
        let tokenExpiry = site.first { $0.name == accessCookie }.flatMap { jwtExpiry($0.value) }?.addingTimeInterval(-60)
        let expiry = [sessionExpiry, tokenExpiry].compactMap { $0 }.min()
        let (gameName, tagLine) = site.first { $0.name == identityCookie }.map { identity(from: $0.value) } ?? (nil, nil)
        return PlayRiftboundCredentials(cookieHeader: header, expiry: expiry, gameName: gameName, tagLine: tagLine)
    }
}
