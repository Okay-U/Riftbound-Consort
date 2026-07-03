import SwiftUI

/// Events tab, ported from iOS. Gates on Locator sign-in, then shows the
/// player's own events. First visit triggers the Events tour (replayable
/// from Settings).
struct EventsTabView: View {
    @Environment(AuthSession.self) var session
    @AppStorage("didOnboardEvents") var didOnboardEvents = false
    @State var showOnboarding = false

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

struct ComingSoonView: View {
    let title: String

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Text("Coming in the next update step.")
                .font(.system(size: 13))
                .foregroundStyle(EventsTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EventsTheme.bg)
    }
}
