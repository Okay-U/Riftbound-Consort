//
//  Errata.swift
//  Riftcount
//
//  Card errata published by Riot as articles, not as card data.
//
//  Riot's Origins errata says the corrections are "not planned to be included
//  on any future restocks" and that database integration "remains pending", so
//  neither the printed card nor the card database carries the corrected text —
//  the app was showing rules that no longer apply. This layer sits on top of
//  whatever card source we use and stays useful after any migration.
//
//  The data is hosted rather than bundled so a new set's errata reaches players
//  without an app release.
//

import Foundation
import SwiftUI
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

nonisolated public struct CardErratum: Codable, Hashable, Sendable, Identifiable {
    /// Canonical card name, without the variant suffix — errata applies to
    /// every printing, so "Annie - Dark Child" covers Metal and Starter too.
    public let card: String
    /// Normalised `card`, the value looked up at runtime.
    public let key: String
    public let set: String?
    public let newText: String
    public let oldText: String?
    public let note: String?
    /// Official article this was taken from, so players can check it.
    public let source: String

    public var id: String { key }
    public var sourceURL: URL? { URL(string: source) }
}

nonisolated public struct ErrataDocument: Codable, Sendable {
    public let version: Int
    public let updated: String?
    public let entries: [CardErratum]
}

@Observable @MainActor
public final class ErrataStore {
    public private(set) var byKey: [String: CardErratum] = [:]

    private let feed = URL(string: "https://okay-u.github.io/errata.json")!

    /// Errata are published a few times a year; a day-old copy is fine and a
    /// launch should never wait on this.
    private static let refreshInterval: TimeInterval = 24 * 60 * 60

    private nonisolated static var cacheURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("errata_v1.json")
    }

    public init() {}

    public func load() {
        Task {
            // Same lesson as the card snapshot: decoding on the main thread is
            // what makes a tab feel slow, so it happens off it.
            if let cached = await Task.detached(priority: .utility, operation: {
                Self.readCache()
            }).value {
                apply(cached)
            }
            guard Self.cacheIsStale(Self.refreshInterval) else { return }
            guard let fetched = await fetch() else { return }
            apply(fetched)
            let doc = fetched
            Task.detached(priority: .utility) { Self.writeCache(doc) }
        }
    }

    /// The erratum for a card, matched on its name with the printing suffix
    /// removed. Nil for the overwhelming majority of cards.
    func erratum(for card: Card) -> CardErratum? {
        byKey[Self.normalize(card.name)]
    }

    private func apply(_ doc: ErrataDocument) {
        var map: [String: CardErratum] = [:]
        for entry in doc.entries { map[entry.key] = entry }
        byKey = map
    }

    private func fetch() async -> ErrataDocument? {
        guard let (data, response) = try? await URLSession.shared.data(from: feed),
              let http = response as? HTTPURLResponse, http.statusCode == 200
        else { return nil }
        return try? JSONDecoder().decode(ErrataDocument.self, from: data)
    }

    /// Lowercased alphanumerics with the variant suffix dropped, so every
    /// printing of a card resolves to one entry. Must match the generator.
    nonisolated static func normalize(_ name: String) -> String {
        let withoutVariant = name.replacingOccurrences(
            of: #"\s*\([^)]*\)\s*$"#, with: "", options: .regularExpression)
        return withoutVariant.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private nonisolated static func readCache() -> ErrataDocument? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(ErrataDocument.self, from: data)
    }

    private nonisolated static func cacheIsStale(_ interval: TimeInterval) -> Bool {
        guard let modified = try? FileManager.default
            .attributesOfItem(atPath: cacheURL.path)[.modificationDate] as? Date
        else { return true }
        return Date().timeIntervalSince(modified) > interval
    }

    private nonisolated static func writeCache(_ doc: ErrataDocument) {
        guard let data = try? JSONEncoder().encode(doc) else { return }
        try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: cacheURL, options: .atomic)
    }
}
