//
//  EventsHomeView.swift
//  Riftbound Companiokay
//
//  Signed-in root of the Events tab: a custom segmented control switching
//  between "Events" (your events) and "Stores" (store finder), with the
//  account menu. Styled per EventsTheme (green-only accent).
//

import SwiftUI

struct EventsHomeView: View {
    @EnvironmentObject private var session: AuthSession
    @State private var segment: Segment = .events

    enum Segment: String, CaseIterable { case events = "Events", stores = "Stores", profile = "Profile" }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Group {
                switch segment {
                case .events: MyEventsView(embedded: true)
                case .stores: StoresHomeView()
                case .profile: ProfileView()
                }
            }
        }
        .background(EventsTheme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
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
                        .background(selected ? EventsTheme.green : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
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
            Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
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
    }
}
