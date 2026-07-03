import SwiftUI

struct LegendPickerView: View {
    let state: DeckBuilderState
    @Environment(CardStore.self) var cardStore
    @State var query: String = ""

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var legends: [Card] {
        var pool = cardStore.allCards.filter { $0.isRareLegend }
        let q = query.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            pool = pool.filter {
                $0.name.localizedCaseInsensitiveContains(q)
            }
        }
        return pool.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            BuilderSearchField(prompt: "Search legends", query: $query)

            if cardStore.isLoading && legends.isEmpty {
                Spacer()
                ProgressView("Loading cards…")
                Spacer()
            } else if legends.isEmpty {
                Spacer()
                EmptyStateView(title: "No legends",
                               message: "Open the Cards tab once to fetch the database.")
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(legends) { card in
                            Button {
                                state.setLegend(card)
                            } label: {
                                CardThumbCell(
                                    card: card,
                                    isSelected: state.legend?.id == card.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
                }
            }
        }
    }
}

/// Shared builder search field (plain TextField with icon).
struct BuilderSearchField: View {
    let prompt: String
    @Binding var query: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(prompt, text: $query)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

/// Shared counter bar for wizard steps.
struct BuilderCounterBar: View {
    let title: String
    let trailing: String
    let complete: Bool
    var extra: String? = nil
    var extraWarning: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            if let extra {
                Text(extra)
                    .font(.caption)
                    .foregroundStyle(extraWarning ? Color.orange : Color.secondary)
            }
            Text(trailing)
                .font(.subheadline)
                .foregroundStyle(complete ? Color.green : Color.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}
