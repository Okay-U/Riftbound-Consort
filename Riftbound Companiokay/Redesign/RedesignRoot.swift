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
    /// Counts how often each tab was left. Like Android, which builds a tab's screen anew each time it shows, a
    /// screen left behind starts fresh and its entrance plays again; what lasts lives in the stores and models.
    @State private var visits: [String: Int] = [:]

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
                .id(visits[TabKey.user, default: 0])
                .tabItem { Label("Decks", systemImage: "square.3.layers.3d") }
                .tag(TabKey.user)

            RiftSettingsView()
                .id(visits[TabKey.settings, default: 0])
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(TabKey.settings)
        }
        .tint(RiftColor.you)
        // Rebuilt while hidden, so the screen comes back fresh without a frame of the old one first.
        .onChange(of: currentTab) { left, _ in visits[left, default: 0] += 1 }
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
