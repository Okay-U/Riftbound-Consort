import SwiftUI

/// Pre-game setup, ported from iOS: your deck, opponent's legend, turn order.
/// Custom layout + SheetHeader instead of Form/toolbar (sheet lessons).
struct GameSetupSheet: View {
    @Environment(DecklistStore.self) var decklistStore
    @Environment(CardStore.self) var cardStore
    @AppStorage("activeDeckId") var activeDeckId: String = ""
    @AppStorage("activeOpponent") var activeOpponent: String = ""
    @AppStorage("activeStartedFirst") var activeStartedFirst: String = ""
    @Environment(\.dismiss) var dismiss

    private var legendNames: [String] { cardStore.legendNames }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SheetHeader(title: "Game Setup") { dismiss() }

                sectionTitle("Your Deck")
                Picker("Deck", selection: $activeDeckId) {
                    Text("None").tag("")
                    ForEach(decklistStore.lists) { deck in
                        Text(deck.name).tag(deck.id.uuidString)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 16)

                sectionTitle("Opponent's Legend")
                Picker("Legend", selection: $activeOpponent) {
                    Text("None").tag("")
                    ForEach(legendNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 16)

                if legendNames.isEmpty {
                    Text("Legends loading… open Cards tab once to fetch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }

                sectionTitle("Turn Order")
                Picker("Going", selection: $activeStartedFirst) {
                    Text("Unknown").tag("")
                    Text("First").tag("first")
                    Text("Second").tag("second")
                }
                .pickerStyle(.segmented)
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
}
