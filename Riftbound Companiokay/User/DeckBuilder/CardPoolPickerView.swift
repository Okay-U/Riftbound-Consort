//
//  CardPoolPickerView.swift
//  Riftbound Companiokay
//

import SwiftUI

enum BuilderPoolSlot {
    case mainDeck
    case sideDeck
}

struct CardPoolPickerView: View {
    @ObservedObject var state: DeckBuilderState
    @EnvironmentObject var cardStore: CardStore
    let slot: BuilderPoolSlot
    @State private var query: String = ""
    @State private var selectedTypes: Set<String> = []

    private let typeOptions = ["Unit", "Spell", "Gear"]

    private let columns = [
        GridItem(.adaptive(minimum: 130), spacing: 12)
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

    private var slotIcon: String {
        slot == .mainDeck ? "rectangle.stack.fill" : "rectangle.stack.badge.plus.fill"
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

    /// Position of card's first legend-matching domain inside the legend's
    /// domain list. Colorless or unmatched cards sort to the end.
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
            counterBar
            searchField
            typeFilterBar

            if pool.isEmpty {
                Spacer()
                ContentUnavailableView("No cards match",
                                       systemImage: "rectangle.stack.badge.minus")
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
            .disabled(!canAdd)
            .contextMenu {
                if canAdd {
                    Button {
                        increment(card)
                    } label: {
                        Label("Add one", systemImage: "plus")
                    }
                }
                if qty > 0 {
                    Button(role: .destructive) {
                        decrement(card)
                    } label: {
                        Label("Remove one", systemImage: "minus")
                    }
                }
            }

            if qty > 0 {
                Button {
                    decrement(card)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                        .background(
                            Circle().fill(Color.black.opacity(0.4))
                        )
                }
                .buttonStyle(.plain)
                .padding(10)
            }
        }
    }

    private var counterBar: some View {
        HStack(spacing: 10) {
            Image(systemName: slotIcon)
                .foregroundStyle(.secondary)
            Text(slot == .mainDeck ? "Main deck" : "Sideboard")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("Sig \(state.signatureCopyCount)/\(DeckBuilderState.signatureLimit)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(state.signatureCopyCount >= DeckBuilderState.signatureLimit
                                 ? .orange : .secondary)
            Text("\(currentCount) / \(targetLabel)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(isComplete ? .green : .secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.thinMaterial)
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(typeOptions, id: \.self) { type in
                    typeChip(type)
                }
                if !selectedTypes.isEmpty {
                    Button {
                        selectedTypes.removeAll()
                    } label: {
                        Label("Clear", systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 4)
    }

    private func typeChip(_ type: String) -> some View {
        let isOn = selectedTypes.contains(type)
        return Button {
            if isOn { selectedTypes.remove(type) }
            else    { selectedTypes.insert(type) }
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
                .overlay(
                    Capsule().stroke(isOn
                                     ? Color.accentColor
                                     : Color.clear,
                                     lineWidth: 1.5)
                )
                .foregroundStyle(isOn ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search cards", text: $query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled(true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.thinMaterial)
        )
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }
}
