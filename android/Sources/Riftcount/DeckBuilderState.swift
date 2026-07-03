import Foundation
import Observation
import SkipFuse

/// Holds an in-progress deck during the wizard flow. Mutations on this object
/// do not touch `DecklistStore` until `finalize` is called.
/// Port notes: @Observable instead of ObservableObject; identity
/// normalisation uses manual paren-stripping instead of regex.
@Observable @MainActor
final class DeckBuilderState {

    // MARK: - Wizard steps

    enum Step: Int, CaseIterable {
        case legend
        case champion
        case battlefield
        case mainDeck
        case sideDeck
        case runePool
        case finalize

        var title: String {
            switch self {
            case .legend: return "Pick Legend"
            case .champion: return "Pick Champion"
            case .battlefield: return "Battlefields (3)"
            case .mainDeck: return "Main Deck (39)"
            case .sideDeck: return "Sideboard (0 or 8)"
            case .runePool: return "Rune Pool (12)"
            case .finalize: return "Save Deck"
            }
        }
    }

    // MARK: - Targets

    static let mainDeckTarget = 39
    static let sideDeckOptions: [Int] = [0, 8]
    static let battlefieldTarget = 3
    static let runeTotal = 12
    static let runePerDomain = 6
    static let copyLimit = 3   // max copies of any single card in main + side combined
    static let signatureLimit = 3   // max signature copies in main + side combined

    // MARK: - Draft picks

    var legend: Card? = nil
    var champion: Card? = nil
    var battlefields: [Card] = []
    var mainDeck: [DecklistEntry] = []
    var sideDeck: [DecklistEntry] = []
    var deckName: String = ""
    /// Card ids known to be signature cards.
    private(set) var signatureIds: Set<String> = []
    /// Maps each entry's printing id to its logical identity key, so copy
    /// limits are enforced across reprints / rarity variants / promos.
    private(set) var idToIdentity: [String: String] = [:]
    /// Rune counts per legend domain (lowercased).
    var runeCounts: [String: Int] = [:]

    // MARK: - Derived

    var legendDomains: [String] {
        legend?.domains ?? []
    }

    var legendDomainsSet: Set<String> {
        Set(legendDomains.map { $0.lowercased() })
    }

    var mainCount: Int {
        mainDeck.reduce(0) { $0 + $1.count }
    }

    var sideCount: Int {
        sideDeck.reduce(0) { $0 + $1.count }
    }

    func totalCount(of cardId: String) -> Int {
        let m = mainDeck.first(where: { $0.cardId == cardId })?.count ?? 0
        let s = sideDeck.first(where: { $0.cardId == cardId })?.count ?? 0
        return m + s
    }

    /// Logical identity key — same across reprints, rarities, and promo
    /// variants of the same card.
    func identityKey(for card: Card) -> String {
        Self.identityKey(for: card)
    }

    static func identityKey(for card: Card) -> String {
        let raw = (card.metadata?.cleanName?.isEmpty == false
                   ? card.metadata!.cleanName!
                   : card.name)
        return "name:" + normaliseIdentity(raw)
    }

    private static func normaliseIdentity(_ s: String) -> String {
        var t = s.lowercased()

        // Drop any parenthesised qualifier, e.g. "Seal of Insight (Showcase)".
        // Manual scan instead of regex (portable across the Android SDK).
        while let open = t.firstIndex(of: "("),
              let close = t[open...].firstIndex(of: ")") {
            t.removeSubrange(open...close)
        }

        // Drop trailing variant words.
        let stripSuffixes = [
            " showcase",
            " promo",
            " foil",
            " alt art",
            " alternate art",
            " overnumbered",
            " signature",
        ]
        var changed = true
        while changed {
            changed = false
            for suffix in stripSuffixes where t.hasSuffix(suffix) {
                t.removeLast(suffix.count)
                changed = true
                break
            }
        }

        // Collapse internal whitespace.
        let parts = t.split(whereSeparator: { $0.isWhitespace })
        return parts.joined(separator: " ")
    }

    /// Total copies that share the given identity key, counting main + side
    /// entries plus the chosen champion (which always equals 1 copy).
    func totalCount(matchingIdentity key: String) -> Int {
        let entries = mainDeck + sideDeck
        var count = entries
            .filter { idToIdentity[$0.cardId] == key }
            .reduce(0) { $0 + $1.count }
        if let champion, identityKey(for: champion) == key {
            count += 1
        }
        return count
    }

    var signatureCopyCount: Int {
        let entries = mainDeck + sideDeck
        return entries
            .filter { signatureIds.contains($0.cardId) }
            .reduce(0) { $0 + $1.count }
    }

    /// True if a copy of this card can still be added to either deck.
    func canAdd(_ card: Card) -> Bool {
        let key = identityKey(for: card)
        if totalCount(matchingIdentity: key) >= Self.copyLimit { return false }
        if card.metadata?.signature == true,
           signatureCopyCount >= Self.signatureLimit { return false }
        return true
    }

    // MARK: - Mutations

    func setLegend(_ card: Card) {
        legend = card
        // Clear champion when legend changes — old champion may no longer match.
        champion = nil
        // Battlefields and decks are domain-restricted; clear to avoid leaks.
        battlefields = []
        mainDeck = []
        sideDeck = []
        seedRuneCounts()
    }

    /// Even-split runes across legend domains. Total always == runeTotal.
    private func seedRuneCounts() {
        let domains = legendDomains
        guard !domains.isEmpty else {
            runeCounts = [:]
            return
        }
        let base = Self.runeTotal / domains.count
        var remainder = Self.runeTotal % domains.count
        var counts: [String: Int] = [:]
        for d in domains {
            let key = d.lowercased()
            var c = base
            if remainder > 0 { c += 1; remainder -= 1 }
            counts[key] = c
        }
        runeCounts = counts
    }

    var runeTotalCount: Int {
        runeCounts.values.reduce(0, +)
    }

    func incRune(domain: String) {
        guard runeTotalCount < Self.runeTotal else { return }
        let key = domain.lowercased()
        runeCounts[key, default: 0] += 1
    }

    func decRune(domain: String) {
        let key = domain.lowercased()
        guard let c = runeCounts[key], c > 0 else { return }
        runeCounts[key] = c - 1
    }

    func setChampion(_ card: Card) {
        champion = card
    }

    func toggleBattlefield(_ card: Card) {
        if let i = battlefields.firstIndex(where: { $0.id == card.id }) {
            battlefields.remove(at: i)
        } else if battlefields.count < Self.battlefieldTarget {
            battlefields.append(card)
        }
    }

    func incrementMain(_ card: Card) {
        guard mainCount < Self.mainDeckTarget, canAdd(card) else { return }
        trackIdentity(card)
        trackSignature(card)
        increment(&mainDeck, card: card)
    }

    func decrementMain(_ card: Card) {
        decrement(&mainDeck, cardId: card.id)
        pruneIfGone(card.id)
    }

    func incrementSide(_ card: Card) {
        guard sideCount < (Self.sideDeckOptions.last ?? 8), canAdd(card) else { return }
        trackIdentity(card)
        trackSignature(card)
        increment(&sideDeck, card: card)
    }

    func decrementSide(_ card: Card) {
        decrement(&sideDeck, cardId: card.id)
        pruneIfGone(card.id)
    }

    private func trackIdentity(_ card: Card) {
        idToIdentity[card.id] = identityKey(for: card)
    }

    private func trackSignature(_ card: Card) {
        if card.metadata?.signature == true {
            signatureIds.insert(card.id)
        }
    }

    private func pruneIfGone(_ cardId: String) {
        if totalCount(of: cardId) == 0 {
            signatureIds.remove(cardId)
            idToIdentity[cardId] = nil
        }
    }

    // MARK: - Validation

    var canAdvanceFromLegend: Bool { legend != nil }
    var canAdvanceFromChampion: Bool { champion != nil }
    var canAdvanceFromBattlefield: Bool { battlefields.count == Self.battlefieldTarget }
    var canAdvanceFromMain: Bool { mainCount == Self.mainDeckTarget }
    var canAdvanceFromSide: Bool { Self.sideDeckOptions.contains(sideCount) }
    var canAdvanceFromRunes: Bool { runeTotalCount == Self.runeTotal }
    var canSave: Bool {
        !deckName.trimmingCharacters(in: .whitespaces).isEmpty
            && canAdvanceFromLegend
            && canAdvanceFromChampion
            && canAdvanceFromBattlefield
            && canAdvanceFromMain
            && canAdvanceFromSide
            && canAdvanceFromRunes
    }

    // MARK: - Finalize

    /// Persists the draft as a new deck using the user-chosen rune split.
    @discardableResult
    func finalize(into store: DecklistStore, runePool: [Card]) -> Decklist? {
        guard canSave,
              let legend,
              let champion
        else { return nil }

        let trimmedName = deckName.trimmingCharacters(in: .whitespaces)
        let new = store.create(name: trimmedName)

        store.add(legend, to: new, slot: .legend)
        store.add(champion, to: new, slot: .champion)
        for bf in battlefields {
            store.add(bf, to: new, slot: .battlefield)
        }
        applyEntries(mainDeck, to: new, slot: .mainDeck, via: store)
        applyEntries(sideDeck, to: new, slot: .sideDeck, via: store)

        for domain in legendDomains {
            let key = domain.lowercased()
            let count = runeCounts[key] ?? 0
            guard count > 0,
                  let rune = Card.runeCard(forDomain: domain, in: runePool)
            else { continue }
            for _ in 0..<count {
                store.add(rune, to: new, slot: .rune)
            }
        }

        return store.lists.first(where: { $0.id == new.id })
    }

    // MARK: - Edit existing deck

    /// Seeds this state from an existing deck so the wizard pickers can be
    /// reused as an editor. Looks up Card refs from the supplied pool.
    func loadFromExisting(_ deck: Decklist, cardPool: [Card]) {
        deckName = deck.name
        battlefields = []
        mainDeck = []
        sideDeck = []
        signatureIds = []
        idToIdentity = [:]

        let lookup: (String) -> Card? = { id in
            cardPool.first(where: { $0.id == id })
        }

        if let entry = deck.legend, let card = lookup(entry.cardId) {
            legend = card
        }
        if let entry = deck.champion, let card = lookup(entry.cardId) {
            champion = card
        }
        for entry in deck.battlefields {
            if let card = lookup(entry.cardId) {
                battlefields.append(card)
            }
        }
        for entry in deck.mainDeck {
            mainDeck.append(entry)
            if let card = lookup(entry.cardId) {
                trackIdentity(card)
                trackSignature(card)
            }
        }
        for entry in deck.sideDeck {
            sideDeck.append(entry)
            if let card = lookup(entry.cardId) {
                trackIdentity(card)
                trackSignature(card)
            }
        }

        // Seed rune counts by mapping rune entries to their domains.
        var counts: [String: Int] = [:]
        for entry in deck.runes {
            guard let card = lookup(entry.cardId),
                  let domain = card.classification?.domain?.first?.lowercased()
            else { continue }
            counts[domain, default: 0] += entry.count
        }
        // Ensure every legend domain has an entry.
        for d in legendDomains {
            let key = d.lowercased()
            if counts[key] == nil { counts[key] = 0 }
        }
        runeCounts = counts
    }

    /// Replaces the slots of an existing deck with this state's current picks.
    func commitEdits(toDeckId deckId: UUID,
                     in store: DecklistStore,
                     runePool: [Card]) {
        guard let deck = store.lists.first(where: { $0.id == deckId }) else { return }

        // Wipe and reapply all editable slots.
        for entry in deck.battlefields {
            store.remove(entry, from: deck, slot: .battlefield)
        }
        for entry in deck.mainDeck {
            store.remove(entry, from: deck, slot: .mainDeck)
        }
        for entry in deck.sideDeck {
            store.remove(entry, from: deck, slot: .sideDeck)
        }
        for entry in deck.runes {
            store.remove(entry, from: deck, slot: .rune)
        }

        guard let refreshed = store.lists.first(where: { $0.id == deckId }) else { return }

        for bf in battlefields {
            store.add(bf, to: refreshed, slot: .battlefield)
        }
        applyEntries(mainDeck, to: refreshed, slot: .mainDeck, via: store)
        applyEntries(sideDeck, to: refreshed, slot: .sideDeck, via: store)

        for domain in legendDomains {
            let key = domain.lowercased()
            let count = runeCounts[key] ?? 0
            guard count > 0,
                  let rune = Card.runeCard(forDomain: domain, in: runePool)
            else { continue }
            for _ in 0..<count {
                store.add(rune, to: refreshed, slot: .rune)
            }
        }
    }

    // MARK: - Helpers

    private func increment(_ array: inout [DecklistEntry], card: Card) {
        if let i = array.firstIndex(where: { $0.cardId == card.id }) {
            array[i].count += 1
        } else {
            array.append(DecklistEntry(cardId: card.id, cardName: card.name, count: 1))
        }
    }

    private func decrement(_ array: inout [DecklistEntry], cardId: String) {
        guard let i = array.firstIndex(where: { $0.cardId == cardId }) else { return }
        array[i].count -= 1
        if array[i].count <= 0 { array.remove(at: i) }
    }

    private func applyEntries(_ entries: [DecklistEntry],
                              to deck: Decklist,
                              slot: DeckSlot,
                              via store: DecklistStore) {
        // DecklistStore.add reads only `id` and `name`, so a minimal Card
        // stub is enough here.
        for entry in entries {
            let stub = Card(
                id: entry.cardId,
                name: entry.cardName,
                riftboundId: nil,
                collectorNumber: nil,
                attributes: nil,
                classification: nil,
                text: nil,
                set: nil,
                media: nil,
                tags: nil,
                orientation: nil,
                metadata: nil
            )
            for _ in 0..<entry.count {
                store.add(stub, to: deck, slot: slot)
            }
        }
    }
}
