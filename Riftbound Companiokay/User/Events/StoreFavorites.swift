//
//  StoreFavorites.swift
//  Riftbound Companiokay
//
//  Local favorite stores, persisted as JSON in @AppStorage (key
//  "favoriteStoresJSON"). Both the store page (heart) and the Stores segment
//  read the same key, so changes propagate automatically.
//

import Foundation

nonisolated struct FavoriteStore: Codable, Sendable, Identifiable, Equatable {
    let id: String        // game-store UUID (route id)
    let name: String
    let subtitle: String?
    let numericID: Int?   // inner store.id — used to fetch the store's events
}

nonisolated enum StoreFavorites {
    static let key = "favoriteStoresJSON"

    static func decode(_ raw: String) -> [FavoriteStore] {
        guard let data = raw.data(using: .utf8),
              let list = try? JSONDecoder().decode([FavoriteStore].self, from: data)
        else { return [] }
        return list
    }

    static func encode(_ list: [FavoriteStore]) -> String {
        guard let data = try? JSONEncoder().encode(list),
              let string = String(data: data, encoding: .utf8)
        else { return "[]" }
        return string
    }

    static func contains(_ id: String, in raw: String) -> Bool {
        decode(raw).contains { $0.id == id }
    }

    /// Returns the new JSON with the store added (front) or removed.
    static func toggling(_ store: FavoriteStore, in raw: String) -> String {
        var list = decode(raw)
        if let index = list.firstIndex(where: { $0.id == store.id }) {
            list.remove(at: index)
        } else {
            list.insert(store, at: 0)
        }
        return encode(list)
    }
}
