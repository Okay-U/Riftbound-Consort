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
    @State private var showOnboarding = false

    var body: some View {
        NavigationStack {
            EventsHomeView()
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
