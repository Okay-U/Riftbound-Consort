//
//  CardRepository.swift
//  Riftbound Companiokay
//
//  The card database is one hosted JSON file, rebuilt daily from Riot's
//  official card gallery by tools/build-cards.py in the okay-u.github.io repo.
//  New sets and spoilers appear as soon as Riot lists them, no app update.
//

import Foundation

protocol CardRepository: Sendable {
    /// The whole database, or nil when the server says it has not changed
    /// since `etag` (HTTP 304).
    func allCards(ifChangedSince etag: String?) async throws -> (page: CardPage, etag: String?)?
}

// nonisolated so the 1.7 MB decode stays off the main actor under the
// project's default-MainActor isolation.
nonisolated final class HostedCardRepository: CardRepository {
    static let feed = URL(string: "https://okay-u.github.io/cards.json")!
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        self.session = URLSession(configuration: config)
    }

    func allCards(ifChangedSince etag: String?) async throws -> (page: CardPage, etag: String?)? {
        var request = URLRequest(url: Self.feed)
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CardRepositoryError.badResponse }
        if http.statusCode == 304 { return nil }
        guard http.statusCode == 200 else { throw CardRepositoryError.badResponse }
        let page = try JSONDecoder().decode(CardPage.self, from: data)
        return (page, http.value(forHTTPHeaderField: "ETag"))
    }
}

enum CardRepositoryError: LocalizedError {
    case badResponse

    var errorDescription: String? {
        switch self {
        case .badResponse: return "Could not reach the card database. Check your connection."
        }
    }
}
