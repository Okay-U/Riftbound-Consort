//
//  UserTabView.swift
//  Riftbound Companiokay
//

import SwiftUI

struct UserTabView: View {
    @EnvironmentObject var decklistStore: DecklistStore
    @EnvironmentObject var cardStore: CardStore

    var body: some View {
        NavigationStack {
            DecksOverviewView()
                .environmentObject(decklistStore)
                .environmentObject(cardStore)
        }
    }
}
