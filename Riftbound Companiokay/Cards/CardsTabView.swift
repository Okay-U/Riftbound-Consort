//
//  CardsTabView.swift
//  Riftbound Companiokay
//

import SwiftUI

struct CardsTabView: View {
    @EnvironmentObject var cardStore: CardStore
    @EnvironmentObject var decklistStore: DecklistStore

    var body: some View {
        NavigationStack {
            CardSearchView()
                .environmentObject(cardStore)
                .environmentObject(decklistStore)
        }
    }
}
