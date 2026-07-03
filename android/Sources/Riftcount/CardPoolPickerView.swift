import SwiftUI

enum BuilderPoolSlot {
    case mainDeck
    case sideDeck
}

struct CardPoolPickerView: View {
    let state: DeckBuilderState
    @Environment(CardStore.self) var cardStore
    let slot: BuilderPoolSlot
    @State var query: String = ""
    @State var selectedTypes: Set<String> = []

    private let typeOptions = ["Unit", "Spell", "Gear"]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    // MARK: - Slot helpers

    private var entries: [DecklistEntry] {
        switch slot {
        case .mainDeck: return state.mainDeck
        case .sideDeck: return state.sideDeck
        }
    }

    private var currentCount: Int {
        switch slot {
        case .mainDeck: return state.mainCount
        case .sideDeck: return state.sideCount
        }
    }

    private var targetLabel: String {
        switch slot {
        case .mainDeck: return "\(DeckBuilderState.mainDeckTarget)"
        case .sideDeck: return "0 or 8"
        }
    }

    private var isComplete: Bool {
        switch slot {
        case .mainDeck: return state.canAdvanceFromMain
        case .sideDeck: return state.canAdvanceFromSide
        }
    }

    private func quantity(of card: Card) -> Int {
        entries.first(where: { $0.cardId == card.id })?.count ?? 0
    }

    private func increment(_ card: Card) {
        switch slot {
        case .mainDeck: state.incrementMain(card)
        case .sideDeck: state.incrementSide(card)
        }
    }

    private func decrement(_ card: Card) {
        switch slot {
        case .mainDeck: state.decrementMain(card)
        case .sideDeck: state.decrementSide(card)
        }
    }

    // MARK: - Pool

    private var pool: [Card] {
        let domains = state.legendDomainsSet
        var cards = cardStore.allCards.filter {
            $0.isMainDeckEligible(legendDomains: domains)
        }

        let q = query.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            cards = cards.filter { $0.name.localizedCaseInsensitiveContains(q) }
        }

        if !selectedTypes.isEmpty {
            let lower = Set(selectedTypes.map { $0.lowercased() })
            cards = cards.filter {
                lower.contains($0.classification?.type?.lowercased() ?? "")
            }
        }

        var seen: Set<String> = []
        var deduped: [Card] = []
        for card in cards {
            if seen.insert(card.id).inserted { deduped.append(card) }
        }
        return deduped.sorted(by: orderedBefore)
    }

    /// Sort: primary by legend-domain rank, secondary by energy ascending,
    /// tertiary by name. Colorless / non-legend domain cards sort last.
    private func orderedBefore(_ lhs: Card, _ rhs: Card) -> Bool {
        let lr = domainRank(lhs)
        let rr = domainRank(rhs)
        if lr != rr { return lr < rr }
        let le = lhs.attributes?.energy ?? Int.max
        let re = rhs.attributes?.energy ?? Int.max
        if le != re { return le < re }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func domainRank(_ card: Card) -> Int {
        let legendDomains = state.legendDomains.map { $0.lowercased() }
        for d in card.domains.map({ $0.lowercased() }) {
            if let i = legendDomains.firstIndex(of: d) { return i }
        }
        return Int.max
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            BuilderCounterBar(
                title: slot == .mainDeck ? "Main deck" : "Sideboard",
                trailing: "\(currentCount) / \(targetLabel)",
                complete: isComplete,
                extra: "Sig \(state.signatureCopyCount)/\(DeckBuilderState.signatureLimit)",
                extraWarning: state.signatureCopyCount >= DeckBuilderState.signatureLimit
            )
            BuilderSearchField(prompt: "Search cards", query: $query)
            typeFilterBar

            if pool.isEmpty {
                Spacer()
                EmptyStateView(title: "No cards match")
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(pool) { card in
                            poolCell(card)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    private func poolCell(_ card: Card) -> some View {
        let qty = quantity(of: card)
        let canAdd = state.canAdd(card)
        return ZStack(alignment: .topLeading) {
            Button {
                increment(card)
            } label: {
                CardThumbCell(
                    card: card,
                    isSelected: qty > 0,
                    badge: qty > 0 ? "×\(qty)" : nil,
                    dimmed: !canAdd && qty == 0
                )
            }
            .buttonStyle(.plain)
            .disabled(!canAdd && qty == 0)

            if qty > 0 {
                Button {
                    decrement(card)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 24, height: 24)
                        Capsule()
                            .fill(Color.white)
                            .frame(width: 11, height: 2.5)
                    }
                }
                .buttonStyle(.plain)
                .padding(10)
            }
        }
    }

    private var typeFilterBar: some View {
        HStack(spacing: 8) {
            ForEach(typeOptions, id: \.self) { type in
                typeChip(type)
            }
            if !selectedTypes.isEmpty {
                Button {
                    selectedTypes.removeAll()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func typeChip(_ type: String) -> some View {
        let isOn = selectedTypes.contains(type)
        return Button {
            if isOn { selectedTypes.remove(type) } else { selectedTypes.insert(type) }
        } label: {
            Text(type)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isOn
                                   ? Color.accentColor.opacity(0.25)
                                   : Color.secondary.opacity(0.15))
                )
                .foregroundStyle(isOn ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
