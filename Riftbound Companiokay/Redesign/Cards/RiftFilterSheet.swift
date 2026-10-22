//
//  RiftFilterSheet.swift
//  Riftbound Companiokay
//
//  Filter cards (Android `FilterSheet.kt`): shortlist, type, series and rarity chips, energy / power / might
//  ranges with two thumbs; the grid behind follows live and the button says how many cards match.
//

import SwiftUI

struct RiftFilterSheet: View {
    @Binding var filters: CardFilters
    let count: Int
    @EnvironmentObject private var cards: CardStore
    @EnvironmentObject private var shortlist: ShortlistStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    let mine = "My shortlist · \(shortlist.ids.count)"
                    section("Shortlist", [mine], on: filters.shortlistOnly ? [mine] : []) { _ in filters.shortlistOnly.toggle() }
                    section("Type", cards.availableTypes, on: filters.types) { filters.types.toggleMember($0) }
                    section("Series", CardFilters.knownSeries.map(\.name), on: filters.series) { filters.series.toggleMember($0) }
                    section("Rarity", cards.availableRarities, on: filters.rarities, gems: true) { filters.rarities.toggleMember($0) }
                    RangeSlider(label: "Energy", lower: $filters.minEnergy, upper: $filters.maxEnergy, cap: CardFilters.energyCap)
                    RangeSlider(label: "Power", lower: $filters.minPower, upper: $filters.maxPower, cap: CardFilters.powerCap)
                    RangeSlider(label: "Might", lower: $filters.minMight, upper: $filters.maxMight, cap: CardFilters.mightCap)
                    Button { dismiss() } label: {
                        Text(count == 0 ? "No cards match" : count == 1 ? "Show 1 card" : "Show \(count) cards")
                            .font(RiftFont.text(15, .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(RiftColor.you, in: Capsule())
                            .shadow(color: RiftColor.you.opacity(0.35), radius: 11)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressScale(scale: 0.97))
                    .padding(.top, 6)
                }
                .padding(16)
            }
            .navigationTitle("Filter cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // The domain discs live outside the sheet and stay as they are.
                    Button("Reset") { filters = CardFilters(domains: filters.domains) }
                        .tint(RiftColor.you)
                }
            }
        }
        .presentationDetents([.large, .medium])
        .presentationDragIndicator(.visible)
    }

    private func section(_ label: String, _ options: [String], on: Set<String>, gems: Bool = false, toggle: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased()).caps(11).foregroundStyle(.white.opacity(0.66))
            FlowLayout(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    ToggleChip(label: option, on: on.contains(option), gem: gems ? CardStyle.rarityColor(option) : nil) { toggle(option) }
                }
            }
        }
    }
}

extension Set {
    mutating func toggleMember(_ member: Element) {
        if contains(member) { remove(member) } else { insert(member) }
    }
}
