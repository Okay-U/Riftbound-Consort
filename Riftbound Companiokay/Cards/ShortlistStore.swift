//
//  ShortlistStore.swift
//  Riftbound Companiokay
//

import Foundation
internal import Combine

/// Cards kept in mind for a deck to come (Okay's "Merkliste", 2026-10-22, as on Android): saved from a card's
/// Add to Deck sheet, found again in the builder's main and side deck, the card filters and the Decks tab.
@MainActor
final class ShortlistStore: ObservableObject {
    /// Card ids in the order they were saved.
    @Published private(set) var ids: [String]

    private static let key = "shortlistCardIds"

    init() {
        ids = UserDefaults.standard.stringArray(forKey: Self.key) ?? []
    }

    func contains(_ id: String) -> Bool { ids.contains(id) }

    /// Puts the card on the shortlist, or takes it off.
    func toggle(_ id: String) {
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
        } else {
            ids.append(id)
        }
        UserDefaults.standard.set(ids, forKey: Self.key)
    }
}
