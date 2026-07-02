import SwiftUI

/// Deck import via pasted text. iOS reads UIPasteboard directly; that shim
/// is unavailable in native Skip mode, so the user pastes into a TextEditor.
struct ImportDeckSheet: View {
    @Environment(DecklistStore.self) var store
    @Environment(CardStore.self) var cardStore
    @Environment(\.dismiss) var dismiss
    @State var text = ""
    @State var resultMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: "Import Deck") { dismiss() }

            Text("Paste a decklist (Legend / Champion / MainDeck / Battlefields / Runes / Sideboard sections).")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            TextEditor(text: $text)
                .font(.system(size: 13, design: .monospaced))
                .frame(minHeight: 200)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(0.15))
                )
                .padding(.horizontal, 16)

            if let resultMessage {
                Text(resultMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }

            Button {
                importText()
            } label: {
                Text("Import")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.horizontal, 16)

            Spacer()
        }
        .onAppear { cardStore.loadIfNeeded() }
    }

    private func importText() {
        let parsed = DeckTextFormat.parse(text, cardPool: cardStore.allCards)
        let hasContent = parsed.legend != nil
            || parsed.champion != nil
            || !parsed.mainDeck.isEmpty
            || !parsed.battlefields.isEmpty
            || !parsed.sideDeck.isEmpty
            || !parsed.runeCounts.isEmpty
        guard hasContent else {
            resultMessage = "Could not parse a deck from this text."
            return
        }
        store.createFromImport(parsed, runePool: cardStore.allCards)
        if parsed.unresolvedLines.isEmpty {
            dismiss()
        } else {
            let preview = parsed.unresolvedLines.prefix(5).joined(separator: "\n")
            resultMessage = "Imported with \(parsed.unresolvedLines.count) unresolved line(s):\n\(preview)"
        }
    }
}
