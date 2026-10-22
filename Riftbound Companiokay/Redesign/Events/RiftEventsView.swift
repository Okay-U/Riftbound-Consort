//
//  RiftEventsView.swift
//  Riftbound Companiokay
//
//  The redesign's Events tab (Android `EventsScreen.kt`, mock `EventsMix`): section tabs Events · Stores ·
//  PlayRiftbound with a glowing underline, the sections sliding sideways, the event and the finder pushed
//  over them, store and month sheets. The PlayRiftbound section keeps the existing browser.
//

import SwiftUI

enum EventsRoute: Hashable {
    case event(PlayerTournamentEntry)
    case search
}

enum EventsSheet: Identifiable {
    case store(CompeteOrganizer)
    case month

    var id: String {
        switch self {
        case .store(let organizer): return "store-\(organizer.id)"
        case .month: return "month"
        }
    }
}

struct RiftEventsView: View {
    /// Bumped each time the tab is left: the sections' lists start fresh and rise in again, the section and the
    /// pushed pages stay (Android keeps them in `EventsUi`).
    var visit = 0
    @EnvironmentObject private var events: PlayRiftboundEventsStore
    @EnvironmentObject private var browser: PlayRiftboundBrowser
    @AppStorage("didOnboardEvents") private var didOnboardEvents = false
    @Environment(\.riftPage) private var page
    @StateObject private var tournaments = RiftTournaments()
    @StateObject private var calendar = RiftCalendar()
    @State private var section = 0
    @State private var path: [EventsRoute] = []
    @State private var sheet: EventsSheet?
    @State private var toast: BoardToast?
    @State private var touring = false
    /// The site loads the first time its section shows, not before (the browser may exist earlier for session renewal).
    @State private var siteShown = false

    private static let sections = ["Events", "Stores", "PlayRiftbound"]

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Events").font(RiftFont.display(46)).tracking(0.9).foregroundStyle(.white).padding(.horizontal, 20).padding(.top, 6)
                SectionTabs(labels: Self.sections, section: section) { pick in select(pick) }
                panes
            }
            .background(page.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: EventsRoute.self) { route in
                switch route {
                case .event(let entry):
                    PushedPage(title: "Event") {
                        EventPage(entry: entry, onStore: { sheet = .store($0) }, onSite: toSite, onToast: show)
                    }
                case .search:
                    PushedPage(title: "Find events") { SearchPage(onOpen: open, onToast: show) }
                }
            }
        }
        .environmentObject(tournaments)
        .environmentObject(calendar)
        .overlay(alignment: .bottom) {
            if let toast {
                HalfToast(text: toast.text)
                    .padding(.bottom, 24)
                    .id(toast.id)
                    .task(id: toast.id) {
                        try? await Task.sleep(for: .seconds(2.2))
                        if self.toast?.id == toast.id { self.toast = nil }
                    }
            }
        }
        .sheet(item: $sheet) { sheet in
            Group {
                switch sheet {
                case .store(let organizer):
                    StoreSheet(store: organizer, onOpen: { route in self.sheet = nil; open(route) }, onToast: show)
                case .month:
                    MonthSheet(onOpen: { route in self.sheet = nil; open(route) })
                }
            }
            .environmentObject(tournaments)
            .environmentObject(calendar)
        }
        .fullScreenCover(isPresented: $touring) { RiftTour(kind: .events) }
        // The tour on the first visit to Events, not at launch.
        .onAppear {
            if !didOnboardEvents { touring = true }
            consumeLinks()
        }
        .onChange(of: browser.pendingURL) { consumeLinks() }
        .onChange(of: browser.pendingEventID) { consumeLinks() }
    }

    private var panes: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                MyEventsPane(active: section == 0, onOpen: open, onSite: toSite, onToast: show)
                    .id(visit)
                    .frame(width: geo.size.width)
                    .accessibilityHidden(section != 0)
                StoresPane(active: section == 1, onSheet: { sheet = $0 }, onOpen: open, onToast: show)
                    .id(visit)
                    .frame(width: geo.size.width)
                    .accessibilityHidden(section != 1)
                Group {
                    if siteShown, let model = browser.model { PlayRiftboundView(model: model) } else { Color.clear }
                }
                .frame(width: geo.size.width)
                .accessibilityHidden(section != 2)
            }
            .offset(x: -CGFloat(section) * geo.size.width)
            .animation(.rift(0.62), value: section)
        }
        .clipped()
    }

    private func select(_ pick: Int) {
        if pick == 2 {
            _ = browser.ensureModel()
            siteShown = true
        }
        section = pick
    }

    private func show(_ text: String) { toast = BoardToast(text: text) }

    /// Events need the player's session; the finder does not.
    private func open(_ route: EventsRoute) {
        if case .event = route, events.state == .signedOut {
            show("Sign in on PlayRiftbound first.")
            return
        }
        path.append(route)
    }

    /// The PlayRiftbound section, on a page or its home.
    private func toSite(_ url: URL?) {
        path = []
        select(2)
        if let url { browser.ensureModel().load(url) }
    }

    /// Deep links: a PlayRiftbound page (the browser's `open`), or the native event from the scoreboard.
    private func consumeLinks() {
        if let url = browser.pendingURL {
            browser.pendingURL = nil
            toSite(url)
        }
        guard let id = browser.pendingEventID else { return }
        browser.pendingEventID = nil
        Task {
            if find(id) == nil { await events.refresh(browser: browser, force: true) }
            if let entry = find(id) {
                section = 0
                path = [.event(entry)]
            } else {
                toSite(URL(string: "https://playriftbound.com/en-US/events/\(id)"))
            }
        }
    }

    private func find(_ id: String) -> PlayerTournamentEntry? {
        (events.upcoming + events.past).first { $0.tournament.id == id }
    }
}

/// `.stabs`: three text tabs on a hairline, the glowing bar slides under the chosen one.
private struct SectionTabs: View {
    let labels: [String]
    let section: Int
    let onPick: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 4
            let tab = (geo.size.width - gap * CGFloat(labels.count - 1)) / CGFloat(labels.count)
            ZStack(alignment: .bottomLeading) {
                HStack(spacing: gap) {
                    ForEach(labels.indices, id: \.self) { i in
                        Button { onPick(i) } label: {
                            Text(labels[i])
                                .font(RiftFont.text(14, .semibold))
                                .foregroundStyle(.white.opacity(i == section ? 1 : 0.5))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(width: tab, height: 42)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressScale(scale: 0.97))
                        .animation(.easeInOut(duration: 0.3), value: section)
                        .accessibilityAddTraits(i == section ? [.isSelected, .isButton] : .isButton)
                    }
                }
                RoundedRectangle(cornerRadius: 2)
                    .fill(RiftColor.you)
                    .frame(width: tab, height: 3)
                    .shadow(color: RiftColor.you.opacity(0.8), radius: 6)
                    .offset(x: CGFloat(section) * (tab + gap), y: 1)
                    .animation(.rift(0.52), value: section)
            }
            .frame(height: 42)
            .overlay(alignment: .bottom) { Hairline(opacity: 0.08) }
        }
        .frame(height: 42)
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }
}

/// A pushed page: its big title, then the page; the system back button and swipe stay.
struct PushedPage<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.riftPage) private var page

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(RiftFont.display(28)).foregroundStyle(.white).padding(.bottom, 14)
                content()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
            .readableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(page.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) } }
    }
}
