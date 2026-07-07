//
//  CardFilterSheet.swift
//  Riftbound Companiokay
//

import SwiftUI

struct CardFilterSheet: View {
    @Binding var filters: CardFilters
    let availableDomains: [String]
    // Data-driven (baseline ∪ loaded DB) so new-set types/rarities appear
    // without an app update; defaults keep old call sites compiling.
    var availableTypes: [String] = CardFilters.knownTypes
    var availableRarities: [String] = CardFilters.knownRarities
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Domain
                if !availableDomains.isEmpty {
                    Section("Domain") {
                        DomainFilterGrid(
                            selected: $filters.domains,
                            domains: availableDomains
                        )
                    }
                }

                // Type
                Section("Type") {
                    FilterChipsGrid(
                        options: availableTypes,
                        selected: $filters.types
                    )
                }

                // Series
                Section("Series") {
                    FilterChipsGrid(
                        options: CardFilters.knownSeries.map(\.name),
                        selected: $filters.series
                    )
                }

                // Rarity
                Section("Rarity") {
                    FilterChipsGrid(
                        options: availableRarities,
                        selected: $filters.rarities
                    )
                }

                // Cost
                Section("Cost") {
                    StatRangeRow(
                        label: "Energy",
                        min: $filters.minEnergy,
                        max: $filters.maxEnergy,
                        bounds: 0...CardFilters.energyCap
                    )
                    StatRangeRow(
                        label: "Power",
                        min: $filters.minPower,
                        max: $filters.maxPower,
                        bounds: 0...CardFilters.powerCap
                    )
                    StatRangeRow(
                        label: "Might",
                        min: $filters.minMight,
                        max: $filters.maxMight,
                        bounds: 0...CardFilters.mightCap
                    )
                }
            }
            .navigationTitle("Filter Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { filters = CardFilters() }
                        .foregroundStyle(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .bold()
                }
            }
        }
    }
}

// MARK: - Domain grid with rune icons

private struct DomainFilterGrid: View {
    @Binding var selected: Set<String>
    let domains: [String]

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(domains, id: \.self) { domain in
                let isOn = selected.contains(domain)

                Button {
                    if isOn { selected.remove(domain) } else { selected.insert(domain) }
                } label: {
                    VStack(spacing: 6) {
                        DomainRune(domain: domain, isSelected: isOn)
                        Text(domain)
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(isOn ? .primary : .secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DomainRune: View {
    let domain: String
    let isSelected: Bool

    var body: some View {
        ZStack {
            if let asset = CardFilters.runeAssetName(for: domain) {
                Image(asset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .opacity(isSelected ? 1.0 : 0.35)
            } else {
                // Colorless / unknown — plain white circle
                Circle()
                    .fill(Color.white)
                    .frame(width: 36, height: 36)
                    .opacity(isSelected ? 1.0 : 0.35)
            }
        }
        .overlay {
            if isSelected {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2)
                    .frame(width: 40, height: 40)
            }
        }
        .frame(width: 40, height: 40)
    }
}

// MARK: - Generic chip grid (types, series, rarities)

private struct FilterChipsGrid: View {
    let options: [String]
    @Binding var selected: Set<String>

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isOn = selected.contains(option)
                Button {
                    if isOn { selected.remove(option) } else { selected.insert(option) }
                } label: {
                    Text(option)
                        .font(.subheadline.weight(isOn ? .semibold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)   // "Proving Grounds" would wrap → taller chip
                        .frame(minHeight: 20)      // scaled-down text must not shrink the chip
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(
                            isOn
                                ? Color.accentColor
                                : Color.secondary.opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .foregroundStyle(isOn ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Stat range with two sliders

private struct StatRangeRow: View {
    let label: String
    @Binding var min: Int
    @Binding var max: Int
    let bounds: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(min) – \(max)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text("Min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 26, alignment: .leading)
                Slider(
                    value: Binding(
                        get: { Double(min) },
                        set: { min = Swift.min(Int($0.rounded()), max) }
                    ),
                    in: Double(bounds.lowerBound)...Double(bounds.upperBound),
                    step: 1
                )
            }

            HStack(spacing: 8) {
                Text("Max")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 26, alignment: .leading)
                Slider(
                    value: Binding(
                        get: { Double(max) },
                        set: { max = Swift.max(Int($0.rounded()), min) }
                    ),
                    in: Double(bounds.lowerBound)...Double(bounds.upperBound),
                    step: 1
                )
            }
        }
        .padding(.vertical, 4)
    }
}
