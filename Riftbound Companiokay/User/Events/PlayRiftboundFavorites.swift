//
//  PlayRiftboundFavorites.swift
//  Riftbound Companiokay
//
//  The player's favourite stores on PlayRiftbound, shared by the Stores list, the
//  store finder and every store page, so a heart changed in one place shows in all.
//

import SwiftUI
internal import Combine

@MainActor
final class PlayRiftboundFavorites: ObservableObject {
    @Published private(set) var stores: [CompeteOrganizer] = []
    /// nil until the list was loaded once; false without a PlayRiftbound session. True only
    /// with the list in hand, so a heart is never shown (or tapped) before its state is known.
    @Published private(set) var signedIn: Bool?
    /// Stores whose heart is being changed right now.
    @Published private(set) var pending: Set<String> = []

    private let api = PlayRiftboundAPI()
    /// Counts heart changes, so a list requested before one cannot overwrite it afterwards.
    private var changes = 0

    func contains(_ id: String) -> Bool { stores.contains { $0.id == id } }

    /// Keeps the current list when the session cannot be renewed (offline), the request fails
    /// or a heart changed meanwhile; a signed-out player's list is dropped.
    func load(browser: PlayRiftboundBrowser) async {
        let credentials: PlayRiftboundCredentials?
        do { credentials = try await PlayRiftboundSession.validCredentials(refreshingVia: browser) }
        catch { return }
        guard let credentials else {
            signedIn = false
            stores = []
            return
        }
        let before = changes
        guard let fresh = try? await api.favoritedOrganizers(credentials: credentials),
              before == changes, pending.isEmpty else { return }
        stores = fresh
        signedIn = true
    }

    /// Flips the heart at once and takes it back if Riot refuses.
    func toggle(_ organizer: CompeteOrganizer, browser: PlayRiftboundBrowser) async throws {
        guard pending.insert(organizer.id).inserted else { return }
        defer { pending.remove(organizer.id) }
        changes += 1
        guard let credentials = try await PlayRiftboundSession.validCredentials(refreshingVia: browser) else {
            throw PlayRiftboundError.notSignedIn
        }
        let on = !contains(organizer.id)
        let without = stores.filter { $0.id != organizer.id }
        stores = on ? stores + [organizer] : without
        do {
            try await api.setFavorite(organizerID: organizer.id, on: on, credentials: credentials)
        } catch {
            stores = on ? stores.filter { $0.id != organizer.id } : stores + [organizer]
            throw error
        }
    }
}
