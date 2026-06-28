//
//  EventsTabView.swift
//  Riftbound Companiokay
//
//  Events tab. Gates on Locator sign-in, then shows the player's own events.
//

import SwiftUI

struct EventsTabView: View {
    @EnvironmentObject private var session: AuthSession
    @AppStorage("didOnboardEvents") private var didOnboardEvents = false
    @State private var showOnboarding = false

    var body: some View {
        NavigationStack {
            Group {
                switch session.state {
                case .signedOut:
                    LoginView()
                case .signedIn:
                    EventsHomeView()
                }
            }
            .navigationDestination(for: EventRoute.self) { route in
                EventDetailView(eventID: route.id, myAlias: route.alias)
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
}
