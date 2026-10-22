//
//  DecklistStore.swift
//  Riftbound Companiokay
//

import Foundation
internal import Combine
import os

@MainActor
final class DecklistStore: ObservableObject {
    @Published private(set) var lists: [Decklist] = []

    private let fileURL: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("decklists_v2.json")
    }()
    private let legacyFileURL: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("decklists.json")
    }()

    private let logger = Logger(subsystem: "com.okay.riftbound", category: "DecklistStore")

    init() { load() }

    // MARK: - CRUD

    @discardableResult
    func create(name: String) -> Decklist {
        let new = Decklist(name: name)
        lists.append(new)
        save()
        return new
    }

    /// Adds a deck built elsewhere (the redesign's builder) with a single save.
    func insert(_ list: Decklist) {
        guard index(of: list) == nil else { return replace(list) }
        lists.append(list)
        save()
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

    /// Writes an edited deck back with a single save, so an interrupted edit never leaves
    /// half a deck on disk.
    func replace(_ list: Decklist) {
        guard let i = index(of: list) else { return }
        lists[i] = list
        lists[i].updatedAt = Date()
        save()
    }

    /// Creates a new deck from a parsed text decklist. Auto-fills runes from
    /// the parsed counts using rune cards looked up from `runePool`.
    @discardableResult
    func createFromImport(_ parsed: DeckTextFormat.ParsedDeck,
                          runePool: [Card]) -> Decklist {
        let new = create(name: parsed.name)
        if let legend = parsed.legend {
            add(legend, to: new, slot: .legend)
        }
        if let champion = parsed.champion {
            add(champion, to: new, slot: .champion)
        }
        for bf in parsed.battlefields {
            add(bf, to: new, slot: .battlefield)
        }
        for (card, count) in parsed.mainDeck {
            for _ in 0..<count { add(card, to: new, slot: .mainDeck) }
        }
        for (card, count) in parsed.sideDeck {
            for _ in 0..<count { add(card, to: new, slot: .sideDeck) }
        }
        for (domain, count) in parsed.runeCounts {
            guard count > 0,
                  let rune = Card.runeCard(forDomain: domain, in: runePool)
            else { continue }
            for _ in 0..<count { add(rune, to: new, slot: .rune) }
        }
        return lists.first(where: { $0.id == new.id }) ?? new
    }

    // MARK: - Slot-aware mutations

    /// Adds the card to its preferred slot (or an explicit slot if provided).
    /// For singular slots (champion / legend) the existing entry is replaced.
    func add(_ card: Card, to list: Decklist, slot: DeckSlot? = nil) {
        guard let i = index(of: list) else { return }
        let target = slot ?? card.preferredSlot
        let entry = DecklistEntry(cardId: card.id, cardName: card.name, count: 1)

        switch target {
        case .champion:    lists[i].champion = entry
        case .legend:      lists[i].legend = entry
        case .battlefield: incrementOrAppend(&lists[i].battlefields, entry: entry)
        case .mainDeck:    incrementOrAppend(&lists[i].mainDeck, entry: entry)
        case .sideDeck:    incrementOrAppend(&lists[i].sideDeck, entry: entry)
        case .rune:        incrementOrAppend(&lists[i].runes, entry: entry)
        }
        lists[i].updatedAt = Date()
        save()
    }

    /// Removes one copy of the entry from its slot. Singular slots are cleared.
    func decrement(_ entry: DecklistEntry, in list: Decklist, slot: DeckSlot) {
        guard let i = index(of: list) else { return }
        switch slot {
        case .champion:    lists[i].champion = nil
        case .legend:      lists[i].legend = nil
        case .battlefield: decrementInArray(&lists[i].battlefields, cardId: entry.cardId)
        case .mainDeck:    decrementInArray(&lists[i].mainDeck, cardId: entry.cardId)
        case .sideDeck:    decrementInArray(&lists[i].sideDeck, cardId: entry.cardId)
        case .rune:        decrementInArray(&lists[i].runes, cardId: entry.cardId)
        }
        lists[i].updatedAt = Date()
        save()
    }

    /// Removes all copies of the entry from its slot.
    func remove(_ entry: DecklistEntry, from list: Decklist, slot: DeckSlot) {
        guard let i = index(of: list) else { return }
        switch slot {
        case .champion:    lists[i].champion = nil
        case .legend:      lists[i].legend = nil
        case .battlefield: lists[i].battlefields.removeAll { $0.cardId == entry.cardId }
        case .mainDeck:    lists[i].mainDeck.removeAll { $0.cardId == entry.cardId }
        case .sideDeck:    lists[i].sideDeck.removeAll { $0.cardId == entry.cardId }
        case .rune:        lists[i].runes.removeAll { $0.cardId == entry.cardId }
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

    // MARK: - Legacy ids

    /// Set when the saved decks could not be read (the file was copied aside first); the
    /// migration stays off then.
    private var loadFailed = false
    /// The running migration; callers that arrive meanwhile wait for it.
    private var migration: Task<Void, Never>?

    /// Decks saved before 3.5 hold riftcodex database ids. Remaps only entries whose id
    /// is not in the hosted feed: through the shared `riftbound_id`, else by exact name
    /// when that name is unique in the feed (or unique within the old card's set). Entries
    /// that cannot be resolved are left as they are. The riftcodex snapshot is deleted only
    /// once every entry resolves, so a later feed can still fix the rest.
    /// Waits for a run already in progress: the deck editor must not load old ids.
    func migrateLegacyIDs(to cards: [Card]) async {
        if let migration {
            await migration.value
            return
        }
        let run = Task { await remapLegacyIDs(to: cards) }
        migration = run
        await run.value
        migration = nil
    }

    private func remapLegacyIDs(to cards: [Card]) async {
        let legacyURL = CardStore.legacyCacheURL
        guard !cards.isEmpty, !loadFailed,
              FileManager.default.fileExists(atPath: legacyURL.path) else { return }
        // An unreadable snapshot only loses the id route; names still resolve, and the file
        // stays for the next launch.
        let legacy: [Card] = await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: legacyURL) else { return [] }
            return (try? JSONDecoder().decode([Card].self, from: data)) ?? []
        }.value

        let known = Set(cards.map(\.id))
        let byRiftboundID = Dictionary(cards.compactMap { c in c.riftboundId.map { ($0, c.id) } },
                                       uniquingKeysWith: { first, _ in first })
        let byName = Dictionary(grouping: cards, by: { $0.name.lowercased() })
        let legacyByID = Dictionary(legacy.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        func unique(_ name: String, set: String?) -> String? {
            let candidates = byName[name.lowercased()] ?? []
            if candidates.count == 1 { return candidates[0].id }
            let sameSet = candidates.filter { $0.set?.setId != nil && $0.set?.setId == set }
            return sameSet.count == 1 ? sameSet[0].id : nil
        }
        func resolve(_ entry: DecklistEntry) -> String? {
            if known.contains(entry.cardId) { return entry.cardId }
            if let old = legacyByID[entry.cardId] {
                if let id = old.riftboundId.flatMap({ byRiftboundID[$0] }) { return id }
                let base = old.name.replacingOccurrences(of: #"\s*\([^)]*\)$"#, with: "", options: .regularExpression)
                if let id = unique(old.name, set: old.set?.setId) ?? unique(base, set: old.set?.setId) { return id }
            }
            return unique(entry.cardName, set: nil)
        }

        var changed = false
        var unresolved = 0
        func remap(_ entry: DecklistEntry) -> DecklistEntry {
            guard let id = resolve(entry) else { unresolved += 1; return entry }
            guard id != entry.cardId else { return entry }
            changed = true
            return DecklistEntry(cardId: id, cardName: entry.cardName, count: entry.count)
        }
        /// Two old printings can land on one new id; one row per card keeps ForEach ids unique.
        func merged(_ entries: [DecklistEntry]) -> [DecklistEntry] {
            var out: [DecklistEntry] = []
            for entry in entries.map(remap) {
                if let i = out.firstIndex(where: { $0.cardId == entry.cardId }) { out[i].count += entry.count }
                else { out.append(entry) }
            }
            return out
        }
        let migrated = lists.map { list in
            var l = list
            l.champion     = list.champion.map(remap)
            l.legend       = list.legend.map(remap)
            l.battlefields = merged(list.battlefields)
            l.mainDeck     = merged(list.mainDeck)
            l.sideDeck     = merged(list.sideDeck)
            l.runes        = merged(list.runes)
            return l
        }
        if changed {
            lists = migrated
            save()
        }
        if unresolved == 0 { try? FileManager.default.removeItem(at: legacyURL) }
        logger.info("Legacy card ids: changed \(changed), unresolved entries \(unresolved)")
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
        // Wipe legacy v1 store — schema changed and prior content is unrecoverable.
        try? FileManager.default.removeItem(at: legacyFileURL)

        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            lists = try JSONDecoder().decode([Decklist].self, from: data)
        } catch {
            loadFailed = true
            logger.error("DecklistStore load failed: \(error.localizedDescription)")
            // The next save would replace the file with what is in memory (nothing, or one new
            // deck), so the unreadable original is kept next to it for recovery.
            // Named by the file's own date: the same unreadable file is copied once, not every launch.
            let modified = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date) ?? Date()
            let copy = fileURL.deletingLastPathComponent()
                .appendingPathComponent("decklists_v2.unreadable-\(Int(modified.timeIntervalSince1970)).json")
            if !FileManager.default.fileExists(atPath: copy.path) {
                do { try FileManager.default.copyItem(at: fileURL, to: copy) }
                catch { logger.error("DecklistStore could not keep the unreadable file: \(error.localizedDescription)") }
            }
        }
    }
}
