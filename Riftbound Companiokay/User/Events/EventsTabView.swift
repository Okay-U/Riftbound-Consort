//
//  EventsTabView.swift
//  Riftbound Companiokay
//
//  Events tab. EventsHomeView owns the segment strip; the Locator segments gate
//  on sign-in themselves, the PlayRiftbound segment never does.
//

import SwiftUI

struct EventsTabView: View {
    @AppStorage("didOnboardEvents") private var didOnboardEvents = false
    @EnvironmentObject private var browser: PlayRiftboundBrowser
    @State private var showOnboarding = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            EventsHomeView()
            .navigationDestination(for: PlayerTournamentEntry.self) { entry in
                PlayRiftboundEventView(entry: entry)
            }
            .navigationDestination(for: PlayRiftboundSearchRoute.self) { _ in
                PlayRiftboundSearchView()
            }
            .navigationDestination(for: CompeteOrganizer.self) { organizer in
                PlayRiftboundStoreView(organizer: organizer)
            }
            .navigationDestination(for: PlayRiftboundCalendarRoute.self) { _ in
                PlayRiftboundCalendarView()
            }
            .navigationDestination(for: EventRoute.self) { route in
                EventDetailView(eventID: route.id, myAlias: route.alias)
            }
            .navigationDestination(for: EventMetaRoute.self) { route in
                EventMetaView(eventID: route.eventID,
                              roundID: route.roundID,
                              roundIDs: route.roundIDs,
                              cutSize: route.cutSize)
            }
            .navigationDestination(for: StoreSearchRoute.self) { _ in
                StoreSearchView()
            }
            .navigationDestination(for: StoreRoute.self) { route in
                StoreDetailView(storeID: route.id)
            }
            .navigationDestination(for: StoreCalendarRoute.self) { _ in
                StoreCalendarView()
            }
        }
        // A deep link into PlayRiftbound from a pushed screen: back to the root first, the
        // root then switches to the PlayRiftbound segment and loads the page.
        .onChange(of: browser.pendingURL, initial: true) { _, url in
            if url != nil, !path.isEmpty { path = NavigationPath() }
        }
        // Fires when the Events tab is first shown (not at app launch), so the
        // tour appears on the user's first visit to Events, not before.
        .onAppear { if !didOnboardEvents { showOnboarding = true } }
        .fullScreenCover(isPresented: $showOnboarding) {
            EventsOnboardingView()
        }
    }
}

#Preview {
    EventsTabView()
        .environmentObject(AuthSession())
        .environmentObject(PlayRiftboundBrowser())
}
