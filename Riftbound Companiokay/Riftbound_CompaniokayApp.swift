//
//  Riftbound_CompaniokayApp.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 02.11.25.
//

import SwiftUI

@main
struct Riftbound_CompaniokayApp: App {
    @AppStorage("keepScreenOn") private var keepScreenOn: Bool = true
    @AppStorage("trueBlack")    private var trueBlack: Bool = true
    @StateObject private var idleMgr = IdleTimerManager()
    @StateObject private var scoreboard = ScoreboardViewModel()
    @StateObject private var gameTimer = GameTimer()
    @StateObject private var decklistStore = DecklistStore()
    @StateObject private var cardStore = CardStore()
    @StateObject private var gameRecordStore = GameRecordStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(scoreboard)
                .environmentObject(idleMgr)
                .environmentObject(gameTimer)
                .environmentObject(decklistStore)
                .environmentObject(cardStore)
                .environmentObject(gameRecordStore)
                .preferredColorScheme(.dark)
                .background(trueBlack ? Color.black : Color(.systemBackground))
                .onAppear {
                    idleMgr.isDisabled = keepScreenOn
                }
                .onChange(of: keepScreenOn, initial: true) { _, newValue in
                    idleMgr.isDisabled = newValue
                }
        }
    }
}

private enum TabKey {
    static let score    = "score"
    static let dice     = "dice"
    static let cards    = "cards"
    static let user     = "user"
    static let settings = "settings"
}

struct RootTabView: View {
    @AppStorage("currentTab") private var currentTab: String = TabKey.score

    var body: some View {
        TabView(selection: $currentTab) {
            ScoreboardView()
                .tabItem { Label("Score", systemImage: "list.number") }
                .tag(TabKey.score)

            DiceView()
                .tabItem { Label("Dice", systemImage: "die.face.5") }
                .tag(TabKey.dice)

            CardsTabView()
                .tabItem { Label("Cards", systemImage: "rectangle.stack") }
                .tag(TabKey.cards)

            UserTabView()
                .tabItem { Label("User", systemImage: "person.crop.rectangle.stack") }
                .tag(TabKey.user)

            Settings()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(TabKey.settings)
        }
        .background(
            ShakeDetector()
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
        )
    }
}
