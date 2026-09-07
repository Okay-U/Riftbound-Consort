import SwiftUI

/// Root of the Events tab, ported from iOS: custom segmented control switching
/// between the Locator-backed segments (Events | Stores | Profile) and "Play",
/// the domain-locked PlayRiftbound browser. The Locator segments show the login
/// form while signed out; "Play" never depends on the Locator session.
struct EventsHomeView: View {
    @Environment(AuthSession.self) var session
    @State var segment: Segment = .events
    // Created on first Play tap, then owned here so the page survives segment
    // switches and Locator sign-in / sign-out. Users who never open Play pay nothing.
    @State var riftWeb: PlayRiftboundWebModel? = nil
    @State var showAccountDialog = false

    enum Segment: String, CaseIterable {
        case events = "Events"
        case play = "New Events"
        case stores = "Stores"
        case profile = "Profile"
    }

    private var isSignedIn: Bool {
        if case .signedIn = session.state { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if showAccountDialog && isSignedIn {
                accountPanel
            }
            Group {
                if segment == .play {
                    if let riftWeb { PlayRiftboundView(model: riftWeb) }
                } else if !isSignedIn {
                    // One slot for all three Locator segments so typed credentials
                    // survive switching between Events / Stores / Profile.
                    LoginView()
                } else {
                    switch segment {
                    case .events: MyEventsView(embedded: true)
                    case .stores: StoresHomeView()
                    case .profile: ProfileView()
                    case .play: EmptyView()
                    }
                }
            }
        }
        .background(EventsTheme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            segmentControl
            if isSignedIn { accountButton }
        }
        .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 10)
    }

    private var segmentControl: some View {
        // Explicit buttons: ForEach over the CaseIterable enum rendered
        // nothing on Compose.
        HStack(spacing: 4) {
            segButton(.events)
            segButton(.play)
            segButton(.stores)
            segButton(.profile)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(EventsTheme.card)
        )
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(EventsTheme.hairline, lineWidth: 1))
    }

    private func segButton(_ seg: Segment) -> some View {
        let selected = segment == seg
        return Button {
            if seg == .play, riftWeb == nil { riftWeb = PlayRiftboundWebModel() }
            withAnimation(.easeInOut(duration: 0.15)) { segment = seg }
        } label: {
            Text(seg.rawValue)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1).minimumScaleFactor(0.8)   // "New Events" is tight in a 4-up strip on 360dp phones
                .foregroundStyle(selected ? EventsTheme.matchFillBottom : EventsTheme.textSecondary)
                .frame(maxWidth: .infinity).frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(selected ? EventsTheme.green : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    /// Inline account panel — Menu and confirmationDialog both collapse
    /// sibling layout on Compose here, so this is a plain toggled row.
    private var accountPanel: some View {
        HStack(spacing: 10) {
            Text(session.currentUser.map { "Signed in as \($0.displayName)" } ?? "Account")
                .font(.system(size: 13))
                .foregroundStyle(EventsTheme.textSecondary)
                .lineLimit(1)
            Spacer()
            Button {
                showAccountDialog = false
                session.logout()
            } label: {
                Text("Sign out of Locator")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.red)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(Color.red.opacity(0.15)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .eventsCard(radius: 13)
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }

    private var accountButton: some View {
        Button { showAccountDialog.toggle() } label: {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 18))
                .foregroundStyle(EventsTheme.textSecondary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(EventsTheme.card))
                .overlay(Circle().stroke(EventsTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
