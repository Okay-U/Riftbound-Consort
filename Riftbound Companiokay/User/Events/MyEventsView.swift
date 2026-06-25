//
//  MyEventsView.swift
//  Riftbound Companiokay
//
//  Signed-in landing: the player's own events, grouped Live / Upcoming / Past.
//  Tapping an event pushes EventDetailView (destination declared by the host
//  NavigationStack in EventsTabView).
//

import SwiftUI

struct MyEventsView: View {
    @EnvironmentObject private var session: AuthSession
    var service: any LocatorService = RiftboundLocatorService()

    @State private var state: LoadState = .idle

    enum LoadState {
        case idle
        case loading
        case loaded([LocatorUserEventStatus])
        case failed(String)
    }

    var body: some View {
        Group {
            switch state {
            case .idle, .loading:
                ProgressView("Loading your events…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't load events", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry") { Task { await load() } }
                }
            case .loaded(let items):
                list(items)
            }
        }
        .navigationTitle("My events")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { accountMenu }
        }
        .task { if case .idle = state { await load() } }
    }

    // MARK: - List

    @ViewBuilder
    private func list(_ items: [LocatorUserEventStatus]) -> some View {
        if items.isEmpty {
            ContentUnavailableView("No events yet",
                                   systemImage: "trophy",
                                   description: Text("Events you register for on the Locator show up here."))
        } else {
            List {
                section("Live", systemImage: "dot.radiowaves.left.and.right", items: live(items))
                section("Upcoming", systemImage: "calendar", items: upcoming(items))
                section("Past", systemImage: "clock.arrow.circlepath", items: past(items))
            }
            .listStyle(.insetGrouped)
            .refreshable { await load() }
        }
    }

    @ViewBuilder
    private func section(_ title: String, systemImage: String, items: [LocatorUserEventStatus]) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { row($0) }
            } header: {
                Label(title, systemImage: systemImage)
            }
        }
    }

    @ViewBuilder
    private func row(_ status: LocatorUserEventStatus) -> some View {
        NavigationLink(value: EventRoute(id: status.event.id, alias: status.bestIdentifier)) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(status.event.name).font(.subheadline.weight(.medium)).lineLimit(2)
                    if let date = status.event.startDatetime {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if status.event.isLive {
                    Text("LIVE")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.green.opacity(0.25), in: Capsule())
                        .foregroundStyle(.green)
                }
            }
        }
    }

    // MARK: - Grouping

    private func live(_ items: [LocatorUserEventStatus]) -> [LocatorUserEventStatus] {
        items.filter { $0.event.isLive }
            .sorted { ($0.event.startDatetime ?? .distantPast) > ($1.event.startDatetime ?? .distantPast) }
    }

    private func upcoming(_ items: [LocatorUserEventStatus]) -> [LocatorUserEventStatus] {
        let now = Date()
        return items
            .filter { !$0.event.isLive && !$0.event.isFinished && ($0.event.startDatetime ?? .distantPast) >= now }
            .sorted { ($0.event.startDatetime ?? .distantFuture) < ($1.event.startDatetime ?? .distantFuture) }
    }

    private func past(_ items: [LocatorUserEventStatus]) -> [LocatorUserEventStatus] {
        let now = Date()
        return items
            .filter { status in
                if status.event.isLive { return false }
                if status.event.isFinished { return true }
                return (status.event.startDatetime ?? .distantFuture) < now
            }
            .sorted { ($0.event.startDatetime ?? .distantPast) > ($1.event.startDatetime ?? .distantPast) }
    }

    // MARK: - Account

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
        }
    }

    // MARK: - Load

    @MainActor
    private func load() async {
        guard let token = session.token else {
            state = .failed("Not signed in.")
            return
        }
        state = .loading
        do {
            let items = try await service.myEvents(token: token)
            state = .loaded(items)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            state = .failed(message)
        }
    }
}
