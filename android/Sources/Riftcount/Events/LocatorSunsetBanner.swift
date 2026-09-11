import SwiftUI

// Riftbound organized play leaves the carde.io Locator on 2026-09-14. The Locator
// segments (Events, Stores, Profile) show this banner pointing at the New Events
// segment, dismissible. Ported from iOS. Delete together with the Locator code.

enum LocatorSunset {
    static let date: Date = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 14))!

    /// The New Events intro card only makes sense before the switch.
    static var isUpcoming: Bool { Date() < date }
}

struct LocatorSunsetBanner: View {
    @AppStorage("didDismissLocatorSunset") var dismissed = false
    let openNewEvents: @MainActor () -> Void

    var body: some View {
        if !dismissed {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    // arrow.right.circle.fill (iOS) is unmapped on SkipUI; chevron.right is proven.
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(EventsTheme.green)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Events are moving")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(EventsTheme.textPrimary)
                        Text("From September 14, Riftbound tournaments run on PlayRiftbound.com with your Riot ID. New events no longer appear here.")
                            .font(.system(size: 13))
                            .foregroundStyle(EventsTheme.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Button {
                        dismissed = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(EventsTheme.textSecondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
                Button(action: openNewEvents) {
                    Text("Open New Events")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(EventsTheme.matchFillBottom)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Capsule().fill(EventsTheme.green))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .eventsCard(radius: 14)
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
        }
    }
}
