import SwiftUI

/// Filter sheet, ported from iOS. ScrollView + SheetHeader instead of
/// Form/toolbar (Compose bottom-sheet lessons), chip grids as fixed rows
/// (no nested lazy containers).
struct CardFilterSheet: View {
    @Binding var filters: CardFilters
    let availableDomains: [String]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Filter Cards")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Spacer()
                    Button("Reset") { filters = CardFilters() }
                        .foregroundStyle(.red)
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.red.opacity(0.85)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 16)

                if !availableDomains.isEmpty {
                    section("Domain") {
                        DomainFilterRows(selected: $filters.domains,
                                         domains: availableDomains)
                    }
                }

                section("Type") {
                    FilterChipRows(options: CardFilters.knownTypes,
                                   selected: $filters.types)
                }

                section("Series") {
                    FilterChipRows(options: CardFilters.knownSeries.map(\.name),
                                   selected: $filters.series)
                }

                section("Rarity") {
                    FilterChipRows(options: CardFilters.knownRarities,
                                   selected: $filters.rarities)
                }

                section("Cost") {
                    VStack(spacing: 16) {
                        StatRangeRow(label: "Energy",
                                     min: $filters.minEnergy,
                                     max: $filters.maxEnergy,
                                     bounds: 0...12)
                        StatRangeRow(label: "Power",
                                     min: $filters.minPower,
                                     max: $filters.maxPower,
                                     bounds: 0...12)
                        StatRangeRow(label: "Might",
                                     min: $filters.minMight,
                                     max: $filters.maxMight,
                                     bounds: 0...14)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }
}

// MARK: - Domain rows with rune icons

struct DomainFilterRows: View {
    @Binding var selected: Set<String>
    let domains: [String]

    private var rows: [[String]] {
        stride(from: 0, to: domains.count, by: 4).map { start in
            Array(domains[start..<min(start + 4, domains.count)])
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { domain in
                        let isOn = selected.contains(domain)

                        Button {
                            if isOn { selected.remove(domain) } else { selected.insert(domain) }
                        } label: {
                            VStack(spacing: 6) {
                                DomainRune(domain: domain, isSelected: isOn)
                                Text(domain)
                                    .font(.caption2)
                                    .foregroundStyle(isOn ? .primary : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct DomainRune: View {
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

// MARK: - Generic chip rows (types, series, rarities)

struct FilterChipRows: View {
    let options: [String]
    @Binding var selected: Set<String>

    private var rows: [[String]] {
        stride(from: 0, to: options.count, by: 3).map { start in
            Array(options[start..<min(start + 3, options.count)])
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { option in
                        let isOn = selected.contains(option)
                        Button {
                            if isOn { selected.remove(option) } else { selected.insert(option) }
                        } label: {
                            Text(option)
                                .font(.subheadline.weight(isOn ? .semibold : .regular))
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
                    // Pad short rows so chips keep equal width.
                    ForEach(0..<(3 - row.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    }
                }
            }
        }
    }
}

// MARK: - Stat range with two sliders

struct StatRangeRow: View {
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
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text("Min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .leading)
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
                    .frame(width: 30, alignment: .leading)
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
    }
}
