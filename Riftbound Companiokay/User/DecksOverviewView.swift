//
//  DecksOverviewView.swift
//  Riftbound Companiokay
//

import SwiftUI
import UIKit

struct DecksOverviewView: View {
    @EnvironmentObject var store: DecklistStore
    @EnvironmentObject var cardStore: CardStore
    @State private var showBuilder: Bool = false
    @State private var showImportAlert: Bool = false
    @State private var importMessage: String = ""

    var body: some View {
        Group {
            if store.lists.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(store.lists) { deck in
                        NavigationLink {
                            DeckDetailView(deck: deck)
                        } label: {
                            DeckRowView(deck: deck)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .onDelete { offsets in
                        offsets.forEach { store.delete(store.lists[$0]) }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Decks")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    importFromClipboard()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                Button {
                    showBuilder = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showBuilder) {
            DeckBuilderSheet()
        }
        .alert("Import", isPresented: $showImportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importMessage)
        }
        .onAppear { cardStore.loadIfNeeded() }
    }

    private func importFromClipboard() {
        guard let text = UIPasteboard.general.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            importMessage = "Clipboard is empty."
            showImportAlert = true
            return
        }
        let parsed = DeckTextFormat.parse(text, cardPool: cardStore.allCards)
        let hasContent = parsed.legend != nil
            || parsed.champion != nil
            || !parsed.mainDeck.isEmpty
            || !parsed.battlefields.isEmpty
            || !parsed.sideDeck.isEmpty
            || !parsed.runeCounts.isEmpty
        guard hasContent else {
            importMessage = "Could not parse a deck from the clipboard."
            showImportAlert = true
            return
        }
        store.createFromImport(parsed, runePool: cardStore.allCards)
        if parsed.unresolvedLines.isEmpty {
            importMessage = "Deck imported."
        } else {
            let preview = parsed.unresolvedLines.prefix(5).joined(separator: "\n")
            importMessage = "Imported with \(parsed.unresolvedLines.count) unresolved line(s):\n\(preview)"
        }
        showImportAlert = true
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No decks yet")
                .font(.title3.weight(.semibold))
            Text("Tap + to create your first deck.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct DeckRowView: View {
    let deck: Decklist
    @EnvironmentObject var gameRecordStore: GameRecordStore

    private var legality: DeckLegality { DeckLegality.evaluate(deck) }

    private var wins: Int { gameRecordStore.winLoss(for: deck.id).wins }
    private var losses: Int { gameRecordStore.winLoss(for: deck.id).losses }
    private var totalGames: Int { wins + losses }
    private var winRate: Double {
        totalGames == 0 ? 0 : Double(wins) / Double(totalGames)
    }

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.22),
                Color.white.opacity(0.06)
            ],
            startPoint: .topLeading,
            endPoint:   .bottomTrailing
        )
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(deck.name)
                    .font(.headline)
                Text(deck.legend?.cardName ?? "No legend selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                winRateBar
            }
            Spacer()
            legalityBadge
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }

    private var winRateBar: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text("\(wins)–\(losses)")
                    .font(.caption.monospacedDigit())
                Text("·")
                    .foregroundStyle(.secondary)
                Text(totalGames == 0 ? "no games" : "\(Int(winRate * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                    Capsule()
                        .fill(Color.green)
                        .frame(width: geo.size.width * CGFloat(winRate))
                }
            }
            .frame(height: 4)
        }
    }

    private var legalityBadge: some View {
        Image(systemName: legality.isLegal
              ? "checkmark.seal.fill"
              : "exclamationmark.triangle.fill")
            .font(.title3)
            .foregroundStyle(legality.isLegal ? .green : .orange)
    }
}
