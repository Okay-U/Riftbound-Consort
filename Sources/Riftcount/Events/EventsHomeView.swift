import SwiftUI

/// Signed-in root of the Events tab, ported from iOS: custom segmented
/// control (Events | Stores | Profile) + account menu. Green-only accent.
struct EventsHomeView: View {
    @Environment(AuthSession.self) var session
    @State var segment: Segment = .events

    enum Segment: String, CaseIterable {
        case events = "Events"
        case stores = "Stores"
        case profile = "Profile"
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if showAccountDialog {
                accountPanel
            }
            Group {
                switch segment {
                case .events: MyEventsView(embedded: true)
                case .stores: StoresHomeView()
                case .profile: ComingSoonView(title: "Player profile")
                }
            }
        }
        .background(EventsTheme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    @State var showAccountDialog = false

    private var topBar: some View {
        HStack(spacing: 12) {
            segmentControl
            accountButton
        }
        .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 10)
    }

    private var segmentControl: some View {
        // Explicit buttons: ForEach over the CaseIterable enum rendered
        // nothing on Compose.
        HStack(spacing: 4) {
            segButton(.events)
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
            withAnimation(.easeInOut(duration: 0.15)) { segment = seg }
        } label: {
            Text(seg.rawValue)
                .font(.system(size: 14, weight: .semibold))
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
                Text("Sign out")
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
