//
//  GameRecordStore.swift
//  Riftbound Companiokay
//

import Foundation
internal import Combine
import os

@MainActor
final class GameRecordStore: ObservableObject {
    @Published private(set) var records: [GameRecord] = []

    private let fileURL: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("games.json")
    }()

    private let logger = Logger(subsystem: "com.okay.riftbound", category: "GameRecordStore")

    init() { load() }

    // MARK: - CRUD

    func record(_ game: GameRecord) {
        records.append(game)
        save()
    }

    func delete(_ game: GameRecord) {
        records.removeAll { $0.id == game.id }
        save()
    }

    // MARK: - Queries

    /// Records for a specific deck (or `nil` for unlinked games).
    func records(for deckId: UUID?) -> [GameRecord] {
        records.filter { $0.deckId == deckId }
    }

    /// Win/loss counts for a specific deck (or `nil` for unlinked games).
    func winLoss(for deckId: UUID?) -> (wins: Int, losses: Int) {
        let scoped = records(for: deckId)
        let wins = scoped.count { $0.result == .won }
        let losses = scoped.count { $0.result == .lost }
        return (wins, losses)
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("GameRecordStore save failed: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            records = try JSONDecoder().decode([GameRecord].self, from: data)
        } catch {
            logger.error("GameRecordStore load failed: \(error.localizedDescription)")
        }
    }
}
