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
    @AppStorage("didOnboard")   private var didOnboard: Bool = false
    @AppStorage("classicDesign") private var classicDesign: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var idleMgr = IdleTimerManager()
    @StateObject private var scoreboard = ScoreboardViewModel()
    @StateObject private var gameTimer = GameTimer()
    @StateObject private var decklistStore = DecklistStore()
    @StateObject private var cardStore = CardStore()
    @StateObject private var errataStore = ErrataStore()
    @StateObject private var gameRecordStore = GameRecordStore()
    @StateObject private var authSession = AuthSession()
    @StateObject private var matchMode = MatchModeStore()
    @StateObject private var riftBrowser = PlayRiftboundBrowser()
    @StateObject private var riftMatch = PlayRiftboundMatchStore()
    @StateObject private var riftEvents = PlayRiftboundEventsStore()
    @StateObject private var riftFavorites = PlayRiftboundFavorites()
    @StateObject private var shortlist = ShortlistStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if classicDesign { RootTabView() } else { RedesignRoot() }
            }
                .environmentObject(scoreboard)
                .environmentObject(idleMgr)
                .environmentObject(gameTimer)
                .environmentObject(decklistStore)
                .environmentObject(cardStore)
                .environmentObject(errataStore)
                .environmentObject(gameRecordStore)
                .environmentObject(authSession)
                .environmentObject(matchMode)
                .environmentObject(riftBrowser)
                .environmentObject(riftMatch)
                .environmentObject(riftEvents)
                .environmentObject(riftFavorites)
                .environmentObject(shortlist)
                .preferredColorScheme(.dark)
                .background(trueBlack ? Color.black : Color(.systemBackground))
                .task { await authSession.restore() }
                .onAppear { errataStore.load() }
                // Back from the background: re-check the card feed when it is due.
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { cardStore.refreshIfDue() }
                }
                .onReceive(cardStore.$allCards) { cards in Task { await decklistStore.migrateLegacyIDs(to: cards) } }
                .fullScreenCover(isPresented: Binding(
                    get: { !didOnboard },
                    set: { newValue in if !newValue { didOnboard = true } }
                )) {
                    if classicDesign { OnboardingView() } else { RiftTour(kind: .main) }
                }
                .onAppear {
                    idleMgr.isDisabled = keepScreenOn
                }
                .onChange(of: keepScreenOn, initial: true) { _, newValue in
                    idleMgr.isDisabled = newValue
                }
        }
    }
}

enum TabKey {
    static let score    = "score"
    static let dice     = "dice"
    static let cards    = "cards"
    static let user     = "user"
    static let events   = "events"
    static let settings = "settings"
}

struct RootTabView: View {
    @AppStorage("currentTab") private var currentTab: String = TabKey.score

    var body: some View {
        TabView(selection: $currentTab) {
            ScoreboardView()
                .tabItem { Label("Score", systemImage: "list.number") }
                .tag(TabKey.score)

            EventsTabView()
                .tabItem { Label("Events", systemImage: "trophy") }
                .tag(TabKey.events)

            CardsTabView()
                .tabItem { Label("Cards", systemImage: "rectangle.stack") }
                .tag(TabKey.cards)

            UserTabView()
                .tabItem { Label("Decks", systemImage: "square.stack.3d.up.fill") }
                .tag(TabKey.user)

            DiceView()
                .tabItem { Label("Dice", systemImage: "die.face.5") }
                .tag(TabKey.dice)

            Settings()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(TabKey.settings)
        }
    }
}
