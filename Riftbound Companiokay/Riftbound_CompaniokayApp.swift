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

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(scoreboard)
                .environmentObject(idleMgr)
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
