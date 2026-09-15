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
        let (gameName, tagLine) = site.first { $0.name == identityCookie }.map { identity(from: $0.value) } ?? (nil, nil)
        return PlayRiftboundCredentials(cookieHeader: header, expiry: expiry, gameName: gameName, tagLine: tagLine)
    }
}
