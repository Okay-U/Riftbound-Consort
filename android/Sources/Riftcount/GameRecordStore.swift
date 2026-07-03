import Foundation
import Observation
import SkipFuse

/// Port of the iOS GameRecordStore (ObservableObject → @Observable).
@Observable @MainActor
public final class GameRecordStore {
    private(set) var records: [GameRecord] = []

    private let fileURL: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("games.json")
    }()

    init() { load() }

    // MARK: - CRUD

    func record(_ game: GameRecord) {
        records.append(game)
        sortRecords()
        save()
    }

    func delete(_ game: GameRecord) {
        records.removeAll { $0.id == game.id }
        save()
    }

    func update(_ game: GameRecord) {
        guard let idx = records.firstIndex(where: { $0.id == game.id }) else {
            logger.warning("update: record \(game.id) not found")
            return
        }
        records[idx] = game
        sortRecords()
        save()
    }

    private func sortRecords() {
        records.sort { $0.date > $1.date }
    }

    // MARK: - Queries

    /// Records for a specific deck (or `nil` for unlinked games).
    func records(for deckId: UUID?) -> [GameRecord] {
        records.filter { $0.deckId == deckId }
    }

    /// Win/loss counts for a specific deck (or `nil` for unlinked games).
    func winLoss(for deckId: UUID?) -> (wins: Int, losses: Int) {
        let scoped = records(for: deckId)
        let wins = scoped.filter { $0.result == .won }.count
        let losses = scoped.filter { $0.result == .lost }.count
        return (wins, losses)
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(records)
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
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
            sortRecords()
        } catch {
            logger.error("GameRecordStore load failed: \(error.localizedDescription)")
        }
    }
}
