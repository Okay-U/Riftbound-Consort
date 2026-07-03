import SwiftUI

/// Pre-game setup, ported from iOS: your deck, opponent's legend, turn order.
/// Deck/legend use inline expanding selectors — SkipUI's menu-style Picker
/// crashes with Index-out-of-range on Android (bisected 2026-07-03).
struct GameSetupSheet: View {
    @Environment(DecklistStore.self) var decklistStore
    @Environment(CardStore.self) var cardStore
    @AppStorage("activeDeckId") var activeDeckId: String = ""
    @AppStorage("activeOpponent") var activeOpponent: String = ""
    @AppStorage("activeStartedFirst") var activeStartedFirst: String = ""
    @Environment(\.dismiss) var dismiss
    @State var deckExpanded = false
    @State var legendExpanded = false

    private var legendNames: [String] { cardStore.legendNames }

    private var activeDeckName: String {
        guard let uuid = UUID(uuidString: activeDeckId),
              let deck = decklistStore.lists.first(where: { $0.id == uuid })
        else { return "None" }
        return deck.name
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SheetHeader(title: "Game Setup") { dismiss() }

                sectionTitle("Your Deck")
                SelectRow(value: activeDeckName, isExpanded: $deckExpanded) {
                    selectOption(label: "None",
                                 selected: activeDeckId.isEmpty) {
                        activeDeckId = ""
                        deckExpanded = false
                    }
                    ForEach(decklistStore.lists) { deck in
                        selectOption(label: deck.name,
                                     selected: activeDeckId == deck.id.uuidString) {
                            activeDeckId = deck.id.uuidString
                            deckExpanded = false
                        }
                    }
                }

                sectionTitle("Opponent's Legend")
                SelectRow(value: activeOpponent.isEmpty ? "None" : activeOpponent,
                          isExpanded: $legendExpanded) {
                    selectOption(label: "None",
                                 selected: activeOpponent.isEmpty) {
                        activeOpponent = ""
                        legendExpanded = false
                    }
                    ForEach(legendNames, id: \.self) { name in
                        selectOption(label: name,
                                     selected: activeOpponent == name) {
                            activeOpponent = name
                            legendExpanded = false
                        }
                    }
                }

                if legendNames.isEmpty {
                    Text("Legends loading… open Cards tab once to fetch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }

                sectionTitle("Turn Order")
                SegmentedControl(selection: $activeStartedFirst,
                                 options: [("Unknown", ""), ("First", "first"), ("Second", "second")])
                .padding(.horizontal, 16)

                Spacer(minLength: 24)
            }
        }
        .onAppear { cardStore.loadIfNeeded() }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
    }

    private func selectOption(label: String,
                              selected: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

/// Collapsed row showing the current value; tap to expand the option list
/// inline below it.
struct SelectRow<Options: View>: View {
    let value: String
    @Binding var isExpanded: Bool
    @ViewBuilder var options: () -> Options

    var body: some View {
        VStack(spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack {
                    Text(value)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    options()
                }
                .background(Color.white.opacity(0.04))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
        )
        .padding(.horizontal, 16)
    }
}
