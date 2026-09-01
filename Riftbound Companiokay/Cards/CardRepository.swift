//
//  CardRepository.swift
//  Riftbound Companiokay
//

import Foundation

protocol CardRepository: Sendable {
    func search(query: String, page: Int) async throws -> CardPage
    func cards(page: Int, size: Int) async throws -> CardPage
    func card(id: String) async throws -> Card
}

// nonisolated so the network decode stays off the main actor under the
// project's default-MainActor isolation, matching RiftboundLocatorService.
nonisolated final class RiftcodexCardRepository: CardRepository {
    private let base = URL(string: "https://api.riftcodex.com")!
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        // riftcodex answers in ~2s on a good day and ~25s on a bad one;
        // 15s made the slow days look like an outage.
        config.timeoutIntervalForRequest = 60
        self.session = URLSession(configuration: config)
    }

    func search(query: String, page: Int = 1) async throws -> CardPage {
        var components = URLComponents(url: base.appendingPathComponent("cards/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page",  value: String(page)),
            URLQueryItem(name: "size",  value: "100")
        ]
        return try await fetch(components.url!)
    }

    func cards(page: Int = 1, size: Int = 50) async throws -> CardPage {
        var components = URLComponents(url: base.appendingPathComponent("cards"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(size))
        ]
        return try await fetch(components.url!)
    }

    func card(id: String) async throws -> Card {
        let url = base.appendingPathComponent("cards/\(id)")
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw CardRepositoryError.badResponse
        }
        return try JSONDecoder().decode(Card.self, from: data)
    }

    private func fetch(_ url: URL) async throws -> CardPage {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw CardRepositoryError.badResponse
        }
        return try JSONDecoder().decode(CardPage.self, from: data)
    }
}

enum CardRepositoryError: LocalizedError {
    case badResponse
    case notFound

    var errorDescription: String? {
        switch self {
        case .badResponse: return "Could not reach the card database. Check your connection."
        case .notFound:    return "Card not found."
        }
    }
}
