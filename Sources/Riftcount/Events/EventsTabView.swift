import SwiftUI

/// Events tab, ported from iOS. Gates on Locator sign-in, then shows the
/// player's own events. Store/detail destinations arrive with stages 3b/3c;
/// they are placeholders for now. Events onboarding tour comes in 3f.
struct EventsTabView: View {
    @Environment(AuthSession.self) var session

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
                EventDetailPlaceholder(eventID: route.id)
            }
            .navigationDestination(for: StoreSearchRoute.self) { _ in
                ComingSoonView(title: "Store finder")
            }
            .navigationDestination(for: StoreRoute.self) { _ in
                ComingSoonView(title: "Store")
            }
            .navigationDestination(for: StoreCalendarRoute.self) { _ in
                ComingSoonView(title: "Store calendar")
            }
        }
    }
}

/// Stage-3b placeholder for the event detail screen.
struct EventDetailPlaceholder: View {
    let eventID: Int

    var body: some View {
        VStack(spacing: 10) {
            Text("Event #\(eventID)")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Text("Pairings, standings and match reporting arrive in the next update step.")
                .font(.system(size: 13))
                .foregroundStyle(EventsTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EventsTheme.bg.ignoresSafeArea())
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
        .background(EventsTheme.bg.ignoresSafeArea())
    }
}
