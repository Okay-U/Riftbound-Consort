//
//  EventsHomeView.swift
//  Riftbound Companiokay
//
//  Root of the Events tab: a custom segmented control switching between the
//  Locator-backed segments ("Events", "Stores", "Profile") and "Play", the
//  domain-locked PlayRiftbound browser. The Locator segments show the login
//  form while signed out; "Play" never depends on the Locator session.
//  Styled per EventsTheme (green-only accent).
//

import SwiftUI

struct EventsHomeView: View {
    @EnvironmentObject private var session: AuthSession
    @State private var segment: Segment = .events
    // Created on first Play selection, then owned here so the page survives segment
    // switches and Locator sign-in / sign-out. Users who never open Play pay nothing.
    @State private var riftWeb: PlayRiftboundWebModel?

    enum Segment: String, CaseIterable {
        case events = "Events", play = "New Events", stores = "Stores", profile = "Profile"
    }

    private var isSignedIn: Bool {
        if case .signedIn = session.state { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if segment != .play {
                LocatorSunsetBanner { select(.play) }
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func select(_ seg: Segment) {
        if seg == .play, riftWeb == nil { riftWeb = PlayRiftboundWebModel() }
        withAnimation(.easeInOut(duration: 0.15)) { segment = seg }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            segmentControl
            if isSignedIn { accountMenu }
        }
        .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 10)
    }

    private var segmentControl: some View {
        HStack(spacing: 4) {
            ForEach(Segment.allCases, id: \.self) { seg in
                let selected = segment == seg
                Button {
                    select(seg)
                } label: {
                    Text(seg.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.8)   // "New Events" is ~69pt, a 375pt slot is ~67pt
                        .foregroundStyle(selected ? EventsTheme.matchFillBottom : EventsTheme.textSecondary)
                        .frame(maxWidth: .infinity).frame(height: 34)
                        .background(selected ? EventsTheme.green : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(EventsTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(EventsTheme.hairline, lineWidth: 1))
    }

    private var accountMenu: some View {
        Menu {
            if let name = session.currentUser?.displayName {
                Text("Signed in as \(name)")
            }
            Button("Sign out of Locator", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                session.logout()
            }
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 18))
                .foregroundStyle(EventsTheme.textSecondary)
                .frame(width: 38, height: 38)
                .background(EventsTheme.card, in: Circle())
                .overlay(Circle().stroke(EventsTheme.hairline, lineWidth: 1))
        }
        .accessibilityLabel("Locator account")
    }
}
