//
//  DeckBuilderState.swift
//  Riftbound Companiokay
//

import Foundation
internal import Combine

/// Holds an in-progress deck during the wizard flow. Mutations on this object
/// do not touch `DecklistStore` until `finalize(name:into:)` is called.
@MainActor
final class DeckBuilderState: ObservableObject {

    // MARK: - Wizard steps

    enum Step: Int, CaseIterable {
        case legend
        case champion
        case battlefield
        case mainDeck
        case sideDeck
        case finalize

        var title: String {
            switch self {
            case .legend:      return "Pick Legend"
            case .champion:    return "Pick Champion"
            case .battlefield: return "Battlefields (3)"
            case .mainDeck:    return "Main Deck (39)"
            case .sideDeck:    return "Sideboard (0 or 8)"
            case .finalize:    return "Save Deck"
            }
        }
    }

    // MARK: - Targets

    static let mainDeckTarget   = 39
    static let sideDeckOptions: [Int] = [0, 8]
    static let battlefieldTarget = 3
    static let runeTotal         = 12
    static let runePerDomain     = 6
    static let copyLimit         = 3   // max copies of any single card in main + side combined
    static let signatureLimit    = 3   // max signature copies in main + side combined

    // MARK: - Draft picks

    @Published var legend:    Card?  = nil
    @Published var champion:  Card?  = nil
    @Published var battlefields: [Card] = []
    @Published var mainDeck:  [DecklistEntry] = []
    @Published var sideDeck:  [DecklistEntry] = []
    @Published var deckName:  String = ""
    /// Card ids known to be signature cards (tracked when added so the state
    /// can enforce the signature-copy cap without holding full Card refs).
    @Published private(set) var signatureIds: Set<String> = []
    /// Maps each entry's specific printing id to its logical identity key,
    /// so copy limits are enforced across reprints / rarity variants / promos.
    @Published private(set) var idToIdentity: [String: String] = [:]

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
    /// variants of the same card. Tries cleanName first, then aggressively
    /// normalises by stripping parenthesised content and known variant
    /// suffixes ("showcase", "promo", "overnumbered", etc.).
    func identityKey(for card: Card) -> String {
        let raw = (card.metadata?.cleanName?.isEmpty == false
                   ? card.metadata!.cleanName!
                   : card.name)
        return "name:" + Self.normaliseIdentity(raw)
    }

    private static func normaliseIdentity(_ s: String) -> String {
        var t = s.lowercased()

        // Drop any parenthesised qualifier, e.g. "Seal of Insight (Showcase)".
        while let range = t.range(of: #"\s*\([^)]*\)"#,
                                  options: .regularExpression) {
            t.removeSubrange(range)
        }

        // Drop trailing variant words.
        let stripSuffixes = [
            " showcase",
            " promo",
            " foil",
            " alt art",
            " alternate art",
            " overnumbered",
            " signature"
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

    var canAdvanceFromLegend: Bool      { legend != nil }
    var canAdvanceFromChampion: Bool    { champion != nil }
    var canAdvanceFromBattlefield: Bool { battlefields.count == Self.battlefieldTarget }
    var canAdvanceFromMain: Bool        { mainCount == Self.mainDeckTarget }
    var canAdvanceFromSide: Bool        { Self.sideDeckOptions.contains(sideCount) }
    var canSave: Bool {
        !deckName.trimmingCharacters(in: .whitespaces).isEmpty
            && canAdvanceFromLegend
            && canAdvanceFromChampion
            && canAdvanceFromBattlefield
            && canAdvanceFromMain
            && canAdvanceFromSide
    }

    // MARK: - Finalize

    /// Persists the draft as a new deck. Auto-fills 12 runes (6 per legend
    /// domain) using rune cards looked up from `pool`. Returns the new deck.
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
        applyEntries(mainDeck,  to: new, slot: .mainDeck,  via: store)
        applyEntries(sideDeck,  to: new, slot: .sideDeck,  via: store)

        // Auto-fill 12 runes (6 per domain) from the resolved pool.
        for domain in legendDomains {
            guard let rune = Card.runeCard(forDomain: domain, in: runePool)
            else { continue }
            for _ in 0..<Self.runePerDomain {
                store.add(rune, to: new, slot: .rune)
            }
        }

        return store.lists.first(where: { $0.id == new.id })
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
        // We need full Card records to pass to store.add. Since the wizard only
        // tracked cardId/name, we synthesize a minimal Card just for adding.
        // (DecklistStore.add reads only `id` and `name` from the Card.)
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
