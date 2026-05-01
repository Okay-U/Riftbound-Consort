//
//  RunePoolPickerView.swift
//  Riftbound Companiokay
//

import SwiftUI

struct RunePoolPickerView: View {
    @ObservedObject var state: DeckBuilderState

    private var domains: [String] { state.legendDomains }

    var body: some View {
        VStack(spacing: 0) {
            counterBar
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(domains, id: \.self) { domain in
                        runeRow(for: domain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
    }

    private var counterBar: some View {
        let target = DeckBuilderState.runeTotal
        let current = state.runeTotalCount
        return HStack {
            Image(systemName: "circle.hexagongrid.fill")
                .foregroundStyle(.secondary)
            Text("Runes")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(current) / \(target)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(current == target ? .green : .secondary)
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

    @ViewBuilder
    private func runeRow(for domain: String) -> some View {
        let key = domain.lowercased()
        let count = state.runeCounts[key] ?? 0
        let atMax = state.runeTotalCount >= DeckBuilderState.runeTotal
        let atMin = count <= 0

        HStack(spacing: 14) {
            runeIcon(for: domain)
            Text(domain.capitalized)
                .font(.headline)
            Spacer()
            Button {
                state.decRune(domain: domain)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 28))
            }
            .buttonStyle(.plain)
            .foregroundStyle(atMin ? Color.secondary.opacity(0.4) : .red)
            .disabled(atMin)

            Text("\(count)")
                .font(.title3.monospacedDigit().weight(.semibold))
                .frame(minWidth: 32)

            Button {
                state.incRune(domain: domain)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
            }
            .buttonStyle(.plain)
            .foregroundStyle(atMax ? Color.secondary.opacity(0.4) : .green)
            .disabled(atMax)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    @ViewBuilder
    private func runeIcon(for domain: String) -> some View {
        if let asset = CardFilters.runeAssetName(for: domain) {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
        } else {
            Circle()
                .fill(Color.white)
                .frame(width: 36, height: 36)
        }
    }
}
