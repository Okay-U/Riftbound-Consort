//
//  EventsTabView.swift
//  Riftbound Companiokay
//
//  Events tab. Gates on Locator sign-in, then shows the player's own events.
//

import SwiftUI

struct EventsTabView: View {
    @StateObject private var session = AuthSession()

    var body: some View {
        NavigationStack {
            Group {
                switch session.state {
                case .signedOut:
                    LoginView()
                case .signedIn:
                    MyEventsView()
                }
            }
            .navigationDestination(for: EventRoute.self) { route in
                EventDetailView(eventID: route.id, myAlias: route.alias)
            }
        }
        .environmentObject(session)
        .task { await session.restore() }
    }
}

#Preview {
    EventsTabView()
}
