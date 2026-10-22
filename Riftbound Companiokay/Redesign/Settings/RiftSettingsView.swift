//
//  RiftSettingsView.swift
//  Riftbound Companiokay
//
//  The redesign's Settings tab (Android `SettingsScreen.kt`, mock `SettingsHybrid`): flip tiles for the switches
//  used most, then grouped rows; sub pages push in. The Classic design switch brings the old look back.
//

import SwiftUI

enum SettingsPage: Hashable {
    case colors, rules, acknowledgments, bug, wish

    var title: String {
        switch self {
        case .colors: return "Player colors"
        case .rules: return "Rules, FAQs and errata"
        case .acknowledgments: return "Acknowledgments"
        case .bug: return "Report a bug"
        case .wish: return "Wish a feature"
        }
    }
}

struct RiftSettingsView: View {
    @AppStorage("hapticsEnabled") private var haptics = true
    @AppStorage("keepScreenOn") private var keepScreenOn = true
    @AppStorage("trueBlack") private var trueBlack = true
    @AppStorage("matchModeEnabled") private var matchMode = true
    @AppStorage("playerCount") private var playerCount = 2
    @AppStorage("classicDesign") private var classicDesign = false
    /// The scoreboard's colours, so the Player colors row redraws after a pick.
    @AppStorage("colorIdx_0") private var color0 = -1
    @AppStorage("colorIdx_1") private var color1 = -1
    @AppStorage("colorIdx_2") private var color2 = -1
    @AppStorage("colorIdx_3") private var color3 = -1
    @Environment(\.riftPage) private var page
    @State private var path: [SettingsPage] = []
    @State private var tour: TourKind?
    @State private var toast: BoardToast?
    @State private var appeared = false

    private static let appStore = URL(string: "https://apps.apple.com/de/app/riftcount-score-tracker/id6755601459")!

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Settings").font(RiftFont.display(46)).tracking(0.9).foregroundStyle(.white).padding(.horizontal, 4).padding(.top, 6)
                    SectionHead(title: "Most used", aside: "Tap i for what it does").padding(.top, 14).riseIn(appeared, delay: 0)
                    tiles
                    section("Scoreboard", delay: 0.32) {
                        LinkRow(title: "Player colors", symbol: "paintpalette", sub: PlayerSwatches.summary(players: playerCount), divider: false) {
                            ColorDots(players: playerCount)
                        } action: { path.append(.colors) }
                    }
                    section("Design", delay: 0.36) {
                        ToggleRow(title: "Classic design", symbol: "rectangle.on.rectangle", sub: "Brings back the look from before this update. It stays for a few updates.",
                                  divider: false, isOn: $classicDesign)
                    }
                    section("Help", delay: 0.39) {
                        LinkRow(title: "Show the general tour", symbol: "sparkles", divider: false) { tour = .main }
                        LinkRow(title: "Events and tournaments tour", symbol: "trophy") { tour = .events }
                        LinkRow(title: "Rules, FAQs and errata", symbol: "book", sub: "Riot's rulebook, tournament rules, set FAQs") { path.append(.rules) }
                    }
                    section("About", delay: 0.46) {
                        LinkRow(title: "Acknowledgments", symbol: "heart", divider: false) { path.append(.acknowledgments) }
                        LinkRow(title: "Report a bug", symbol: "ladybug") { path.append(.bug) }
                        LinkRow(title: "Wish a feature", symbol: "lightbulb") { path.append(.wish) }
                        ShareLink(item: Self.appStore, subject: Text("Riftcount: Score Tracker"), message: Text("Score tracker for Riftbound TCG. Check it out!")) {
                            ShareRowLabel()
                        }
                        .buttonStyle(.plain)
                        ExternalRow(title: "Rate it on the App Store", symbol: "star", url: URL(string: "https://apps.apple.com/de/app/riftcount-score-tracker/id6755601459?action=write-review")!)
                        ExternalRow(title: "Buy me a coffee", symbol: "cup.and.saucer", url: SupportConfig.donationURL)
                        ExternalRow(title: "Support and privacy", symbol: "lock.shield", url: URL(string: "https://okay-u.github.io/privacy.html")!)
                    }
                    VStack(spacing: 4) {
                        Text("RIFTCOUNT").font(RiftFont.display(22)).tracking(0.9).foregroundStyle(.white)
                        Text("Score Tracker · Version \(Bundle.main.appVersion) (\(Bundle.main.appBuild)) · iOS")
                            .font(RiftFont.text(12.5, .regular))
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
                    .padding(.bottom, 10)
                    .riseIn(appeared, delay: 0.53)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .background(page.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: SettingsPage.self) { sub in SubPage(page: sub, players: playerCount, onToast: show) }
        }
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
        .fullScreenCover(item: Binding(get: { tour.map(TourItem.init) }, set: { tour = $0?.kind })) { item in RiftTour(kind: item.kind) }
        .onAppear { appeared = true }
    }

    private func show(_ text: String) { toast = BoardToast(text: text) }

    private func section<Rows: View>(_ title: String, delay: Double, @ViewBuilder rows: () -> Rows) -> some View {
        let content = rows()
        return VStack(alignment: .leading, spacing: 0) {
            SectionHead(title: title)
            SettingsGroup { content }
        }
        .padding(.top, 22)
        .riseIn(appeared, delay: delay)
    }

    private static let info = [
        "A tick on every point and a stronger pulse when a game is won.",
        "The phone does not sleep while Riftcount is open.",
        "Pure #000 background. Saves battery on OLED screens and looks deepest.",
        "In a live tournament the scoreboard shows your table, opponent and a Report button.",
        "2 is the face-to-face duel. 4 splits the table for free-for-all games.",
    ]

    /// The switches, then Players; the odd one out takes the whole row.
    private var tiles: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                switchTile(0, "Haptics", "iphone.radiowaves.left.and.right", $haptics) { on in if on { Haptics.selection() } }
                switchTile(1, "Keep screen on", "sun.max", $keepScreenOn)
            }
            HStack(spacing: 10) {
                switchTile(2, "True black", "moon", $trueBlack) { on in show(on ? "True black · pure #000 for OLED" : "Dark grey background") }
                switchTile(3, "Match mode", "trophy", $matchMode)
            }
            FlipTile(label: "Players", info: Self.info[4], darkInfo: false) {
                PlayersFace(players: playerCount) {
                    playerCount = playerCount == 2 ? 4 : 2
                    Haptics.selection()
                }
            }
            .riseIn(appeared, delay: 0.06 + 4 * 0.045)
        }
        .padding(.top, 8)
    }

    private func switchTile(_ i: Int, _ label: String, _ symbol: String, _ flag: Binding<Bool>, onChange: ((Bool) -> Void)? = nil) -> some View {
        FlipTile(label: label, info: Self.info[i], darkInfo: flag.wrappedValue) {
            SwitchFace(label: label, symbol: symbol, on: flag.wrappedValue) {
                flag.wrappedValue.toggle()
                onChange?(flag.wrappedValue)
            }
        }
        .riseIn(appeared, delay: 0.06 + Double(i) * 0.045)
    }
}

private struct TourItem: Identifiable {
    let kind: TourKind
    var id: String { kind == .main ? "main" : "events" }
}

/// The share row: a link row's look around the system share sheet.
private struct ShareRowLabel: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            Text("Share Riftcount with friends").font(RiftFont.text(15.5, .semibold)).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 64)
        .overlay(alignment: .top) { Hairline() }
        .contentShape(Rectangle())
    }
}

/// A pushed page: its big title, then the page; the system back button and swipe stay.
private struct SubPage: View {
    let page: SettingsPage
    let players: Int
    let onToast: (String) -> Void
    @Environment(\.riftPage) private var background

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(page.title)
                    .font(RiftFont.display(34))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 10)
                switch page {
                case .colors: ColorsPage(players: players, onToast: onToast)
                case .rules: RulesPage()
                case .acknowledgments: AckPage()
                case .bug: FormPage(bug: true, onToast: onToast)
                case .wish: FormPage(bug: false, onToast: onToast)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(background.ignoresSafeArea())
        .navigationTitle(page.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) } }
    }
}
