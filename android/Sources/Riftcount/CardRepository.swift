//
//  CardRepository.swift
//  Riftbound Companiokay
//

import Foundation
#if canImport(FoundationNetworking)
// URLSession lives in FoundationNetworking on Android (as on Linux).
import FoundationNetworking
#endif

protocol CardRepository: Sendable {
    func search(query: String, page: Int) async throws -> CardPage
    func cards(page: Int) async throws -> CardPage
    func card(id: String) async throws -> Card
}

final class RiftcodexCardRepository: CardRepository, @unchecked Sendable {
    private let base = URL(string: "https://api.riftcodex.com")!
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
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

    func cards(page: Int = 1) async throws -> CardPage {
        var components = URLComponents(url: base.appendingPathComponent("cards"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: "50")
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
