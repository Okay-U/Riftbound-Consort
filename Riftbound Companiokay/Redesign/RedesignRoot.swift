//
//  RedesignRoot.swift
//  Riftbound Companiokay
//
//  The redesign's shell (docs/IOS_REDESIGN.md): Score · Events · Cards · Decks · Settings, no Dice tab
//  (the dice move into the scoreboard). Each tab shows its classic screen until its phase lands.
//

import SwiftUI
import UIKit

struct RedesignRoot: View {
    /// Shared with the classic tabs, so switching the design keeps the tab (Settings stays Settings).
    @AppStorage("currentTab") private var currentTab: String = TabKey.score
    /// The deck being built: Cards' "New deck with this card" starts it, the Decks tab shows it.
    @StateObject private var builder = DeckBuilderModel()
    @AppStorage("trueBlack") private var trueBlack = true

    var body: some View {
        TabView(selection: $currentTab) {
            RedesignScoreView()
                .tabItem { Label("Score", systemImage: "rectangle.portrait.bottomhalf.filled") }
                .tag(TabKey.score)

            RiftEventsView()
                .tabItem { Label("Events", systemImage: "calendar") }
                .tag(TabKey.events)

            RiftCardsView()
                .tabItem { Label("Cards", systemImage: "rectangle.portrait.on.rectangle.portrait") }
                .tag(TabKey.cards)

            RiftDecksView()
                .tabItem { Label("Decks", systemImage: "square.3.layers.3d") }
                .tag(TabKey.user)

            RiftSettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(TabKey.settings)
        }
        .tint(RiftColor.you)
        .environmentObject(builder)
        .environment(\.riftPage, RiftColor.page(trueBlack: trueBlack))
        .onAppear {
            // The classic Dice tab has no place here.
            if currentTab == TabKey.dice { currentTab = TabKey.score }
            assert(UIFont(name: "BigShouldersDisplay-Thin", size: 12) != nil && UIFont(name: "Barlow-Medium", size: 12) != nil,
                   "Redesign fonts not registered: check UIAppFonts in Riftbound-Companiokay-Info.plist")
        }
    }
}
