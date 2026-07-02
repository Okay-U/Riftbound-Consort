import Foundation
import Observation
import SkipFuse

/// Port of the iOS DecklistStore (ObservableObject → @Observable).
/// createFromImport is deferred until DeckTextFormat ports.
@Observable @MainActor
public final class DecklistStore {
    private(set) var lists: [Decklist] = []

    private let fileURL: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("decklists_v2.json")
    }()

    init() { load() }

    // MARK: - CRUD

    @discardableResult
    func create(name: String) -> Decklist {
        let new = Decklist(name: name)
        lists.append(new)
        save()
        return new
    }

    func rename(_ list: Decklist, to newName: String) {
        guard let i = index(of: list) else { return }
        lists[i].name = newName
        lists[i].updatedAt = Date()
        save()
    }

    func delete(_ list: Decklist) {
        lists.removeAll { $0.id == list.id }
        save()
    }

    // MARK: - Slot-aware mutations

    /// Adds the card to its preferred slot (or an explicit slot if provided).
    /// For singular slots (champion / legend) the existing entry is replaced.
    func add(_ card: Card, to list: Decklist, slot: DeckSlot? = nil) {
        guard let i = index(of: list) else { return }
        let target = slot ?? card.preferredSlot
        let entry = DecklistEntry(cardId: card.id, cardName: card.name, count: 1)

        switch target {
        case .champion: lists[i].champion = entry
        case .legend: lists[i].legend = entry
        case .battlefield: incrementOrAppend(&lists[i].battlefields, entry: entry)
        case .mainDeck: incrementOrAppend(&lists[i].mainDeck, entry: entry)
        case .sideDeck: incrementOrAppend(&lists[i].sideDeck, entry: entry)
        case .rune: incrementOrAppend(&lists[i].runes, entry: entry)
        }
        lists[i].updatedAt = Date()
        save()
    }

    /// Removes one copy of the entry from its slot. Singular slots are cleared.
    func decrement(_ entry: DecklistEntry, in list: Decklist, slot: DeckSlot) {
        guard let i = index(of: list) else { return }
        switch slot {
        case .champion: lists[i].champion = nil
        case .legend: lists[i].legend = nil
        case .battlefield: decrementInArray(&lists[i].battlefields, cardId: entry.cardId)
        case .mainDeck: decrementInArray(&lists[i].mainDeck, cardId: entry.cardId)
        case .sideDeck: decrementInArray(&lists[i].sideDeck, cardId: entry.cardId)
        case .rune: decrementInArray(&lists[i].runes, cardId: entry.cardId)
        }
        lists[i].updatedAt = Date()
        save()
    }

    /// Removes all copies of the entry from its slot.
    func remove(_ entry: DecklistEntry, from list: Decklist, slot: DeckSlot) {
        guard let i = index(of: list) else { return }
        switch slot {
        case .champion: lists[i].champion = nil
        case .legend: lists[i].legend = nil
        case .battlefield: lists[i].battlefields.removeAll { $0.cardId == entry.cardId }
        case .mainDeck: lists[i].mainDeck.removeAll { $0.cardId == entry.cardId }
        case .sideDeck: lists[i].sideDeck.removeAll { $0.cardId == entry.cardId }
        case .rune: lists[i].runes.removeAll { $0.cardId == entry.cardId }
        }
        lists[i].updatedAt = Date()
        save()
    }

    // MARK: - Helpers

    private func incrementOrAppend(_ array: inout [DecklistEntry], entry: DecklistEntry) {
        if let idx = array.firstIndex(where: { $0.cardId == entry.cardId }) {
            array[idx].count += 1
        } else {
            array.append(entry)
        }
    }

    private func decrementInArray(_ array: inout [DecklistEntry], cardId: String) {
        guard let idx = array.firstIndex(where: { $0.cardId == cardId }) else { return }
        array[idx].count -= 1
        if array[idx].count <= 0 { array.remove(at: idx) }
    }

    private func index(of list: Decklist) -> Int? {
        lists.firstIndex(where: { $0.id == list.id })
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(lists)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("DecklistStore save failed: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            lists = try JSONDecoder().decode([Decklist].self, from: data)
        } catch {
            logger.error("DecklistStore load failed: \(error.localizedDescription)")
        }
    }
}
