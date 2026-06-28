//
//  EventsTabView.swift
//  Riftbound Companiokay
//
//  Events tab. Gates on Locator sign-in, then shows the player's own events.
//

import SwiftUI

struct EventsTabView: View {
    @EnvironmentObject private var session: AuthSession

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
    }
}

#Preview {
    EventsTabView()
        .environmentObject(AuthSession())
}
