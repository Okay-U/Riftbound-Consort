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
            Group {
                switch segment {
                case .events: MyEventsView(embedded: true)
                case .stores: StoresHomeView()
                case .profile: ComingSoonView(title: "Player profile")
                }
            }
        }
        .background(EventsTheme.bg.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            segmentControl
            accountMenu
        }
        .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 10)
    }

    private var segmentControl: some View {
        HStack(spacing: 4) {
            ForEach(Segment.allCases, id: \.self) { seg in
                let selected = segment == seg
                Button {
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
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(EventsTheme.card)
        )
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(EventsTheme.hairline, lineWidth: 1))
    }

    private var accountMenu: some View {
        Menu {
            if let name = session.currentUser?.displayName {
                Text("Signed in as \(name)")
            }
            Button(role: .destructive) {
                session.logout()
            } label: {
                Text("Sign out")
            }
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 18))
                .foregroundStyle(EventsTheme.textSecondary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(EventsTheme.card))
                .overlay(Circle().stroke(EventsTheme.hairline, lineWidth: 1))
        }
    }
}
