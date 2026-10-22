//
//  EventsParts.swift
//  Riftbound Companiokay
//
//  Pieces of the redesign's Events tab (Android `EventsParts.kt`, mock `EventsMix`): cards, pills, chips,
//  buttons, the date badge, the event row, status pills, empty states, the spinner, the round clock and its
//  rail, and the display strings.
//

import SwiftUI

enum Ev {
    static let card = Color(hex: "0D0D0D")
    static let ring = Color.white.opacity(0.08)
}

/// Display strings (classic `PlayRiftboundFormat` and the event cards, Android `Fmt`).
nonisolated enum EvFmt {
    private static let dots = CharacterSet(charactersIn: ".")

    static func day(_ d: Date) -> String { d.formatted(.dateTime.day()) }
    static func month(_ d: Date) -> String { d.formatted(.dateTime.month(.abbreviated)).uppercased().trimmingCharacters(in: dots) }
    static func time(_ d: Date) -> String { d.formatted(date: .omitted, time: .shortened) }
    static func weekday(_ d: Date) -> String { d.formatted(.dateTime.weekday(.abbreviated)).trimmingCharacters(in: dots) }
    /// "Tue 21 Oct 2026 · 18:30".
    static func whenLine(_ d: Date) -> String { "\(weekday(d)) \(d.formatted(.dateTime.day().month(.abbreviated).year())) · \(time(d))" }
    /// "21 Oct".
    static func shortDate(_ d: Date) -> String { d.formatted(.dateTime.day().month(.abbreviated)) }
    /// "October 2026".
    static func monthYear(_ d: Date) -> String { d.formatted(.dateTime.month(.wide).year()) }

    /// `ONE_V_ONE` → "1v1", `BEST_OF_THREE` → "Best Of Three"; the site's own labels for its limited formats.
    static func humanize(_ raw: String) -> String {
        switch raw.uppercased() {
        case "LIMITED_SEALED": return "Sealed"
        case "LIMITED_DRAFT": return "Draft"
        default: return PlayRiftboundFormat.humanize(raw)
        }
    }

    static func price(fee: CompeteTournamentSummary.EntryFee?, pricing: String?) -> String {
        if let fee, fee.minorUnits > 0 {
            return (Decimal(fee.minorUnits) / 100).formatted(.currency(code: fee.currency).precision(.fractionLength(0...2)))
        }
        return pricing.map(humanize) ?? "Free"
    }

    static func players(_ count: Int, cap: Int?) -> String {
        guard let cap, cap > 0 else { return "\(count)" }
        return "\(count)/\(cap)"
    }

    static func formatLine(_ parts: String?...) -> String? {
        let shown = parts.compactMap { $0 }.map { humanize($0) }
        return shown.isEmpty ? nil : shown.joined(separator: " • ")
    }

    static func storeLine(_ organizer: CompeteOrganizer?, distance: Double? = nil) -> String? {
        guard let organizer else { return nil }
        return [organizer.name, organizer.physicalAddress?.city, distance.map { String(format: "%.0f km", $0 / 1000) }]
            .compactMap { $0 }.joined(separator: " • ")
    }

    static func ordinal(_ n: Int) -> String { PlayRiftboundMatchesTab.ordinal(n) }

    static func clock(_ seconds: Int) -> String {
        let a = abs(seconds)
        return String(format: "%02d:%02d", a / 60, a % 60)
    }

    static func pct(_ v: Double?) -> String { v.map { String(format: "%.1f%%", $0 <= 1 ? $0 * 100 : $0) } ?? "–" }

    static func summaryLine(_ s: CompeteTournamentSummary) -> String? {
        formatLine(s.config?.format, s.config?.playerFormat, s.config?.tournamentType)
    }
}

/// The running round's clock as the site shows it: `startedAt` plus `roundDuration` (60 minutes when missing).
struct RoundClock {
    let text: String
    let over: Bool
    let fraction: Double
    let endsAt: Date

    init?(_ round: CompeteTournament.Round?, now: Date) {
        guard let round, let started = round.startedAt else { return nil }
        let end = started.addingTimeInterval(TimeInterval(round.roundDuration ?? 60) * 60)
        let left = Int(end.timeIntervalSince(now).rounded(.down))
        over = left < 0
        text = over ? "+" + EvFmt.clock(-left) : EvFmt.clock(left)
        let total = end.timeIntervalSince(started)
        fraction = total > 0 ? min(max(now.timeIntervalSince(started) / total, 0), 1) : 1
        endsAt = end
    }
}

/// The mock's `.sech`: spaced capitals with an aside on the right.
struct EvCaption<Aside: View>: View {
    let left: String
    var right: String? = nil
    var top: CGFloat = 22
    @ViewBuilder var aside: () -> Aside

    var body: some View {
        HStack {
            Text(left.uppercased()).frame(maxWidth: .infinity, alignment: .leading)
            if let right { Text(right.uppercased()) }
            aside()
        }
        .caps(11)
        .foregroundStyle(.white.opacity(0.55))
        .padding(.horizontal, 4)
        .padding(.top, top)
        .padding(.bottom, 10)
    }
}

extension EvCaption where Aside == EmptyView {
    init(left: String, right: String? = nil, top: CGFloat = 22) {
        self.init(left: left, right: right, top: top) { EmptyView() }
    }
}

/// `.card`: a dark rounded panel with a hairline ring; `glow` for the open pairing.
struct EvCard<Content: View>: View {
    var glow = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22)
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Ev.card, in: shape)
            .overlay(shape.stroke(glow ? RiftColor.you.opacity(0.5) : Ev.ring, lineWidth: 1))
            .shadow(color: glow ? RiftColor.you.opacity(0.12) : .clear, radius: 15)
    }
}

struct CardLabel: View {
    let text: String
    var color: Color = .white.opacity(0.58)

    var body: some View { Text(text.uppercased()).caps(11).foregroundStyle(color) }
}

/// `.epill` and `.spill`: a small capsule.
struct EvPill: View {
    let text: String
    var bg: Color = .white.opacity(0.08)
    var ink: Color = .white
    var height: CGFloat = 22

    var body: some View {
        Text(text)
            .caps(10.5, tracking: 0.04, weight: .bold)
            .foregroundStyle(ink)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: height)
            .background(bg, in: Capsule())
    }
}

/// `.mini`: YOU / DROPPED / PLAYING tags inside rows.
struct MiniPill: View {
    let text: String
    let bg: Color
    let ink: Color

    var body: some View {
        Text(text)
            .caps(9, tracking: 0.08, weight: .bold)
            .foregroundStyle(ink)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(bg, in: Capsule())
    }
}

enum EvButtonKind { case green, ghost, danger, dangerSoft }

/// `.btn`: 50pt capsule; green glows.
struct EvButton: View {
    let text: String
    let kind: EvButtonKind
    var enabled = true
    let action: () -> Void

    var body: some View {
        let (bg, ink): (Color, Color) = switch kind {
        case .green: (RiftColor.you, .black)
        case .ghost: (.white.opacity(0.1), .white)
        case .danger: (RiftColor.danger, .black)
        case .dangerSoft: (RiftColor.danger.opacity(0.14), RiftColor.danger)
        }
        Button(action: action) {
            Text(text)
                .font(RiftFont.text(14, .bold))
                .foregroundStyle(ink.opacity(enabled ? 1 : 0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(bg.opacity(enabled ? 1 : 0.4), in: Capsule())
                .shadow(color: kind == .green && enabled ? RiftColor.you.opacity(0.35) : .clear, radius: 10)
                .contentShape(Capsule())
        }
        .buttonStyle(PressScale(scale: 0.96))
        .disabled(!enabled)
    }
}

/// `.chip` / `.rchip`: filter and round chips; on = green with a glow.
struct EvChip: View {
    let text: String
    let on: Bool
    var enabled = true
    /// Round chips set their label in the display face.
    var display = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(display ? RiftFont.display(13, weight: 800) : RiftFont.text(12.5, .semibold))
                .tracking(display ? 0.8 : 0)
                .foregroundStyle((on ? Color.black : .white).opacity(enabled ? 1 : 0.3))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(on ? RiftColor.you : .white.opacity(0.04), in: Capsule())
                .overlay(Capsule().stroke(on ? RiftColor.you : .white.opacity(0.16), lineWidth: 1))
                .shadow(color: on ? RiftColor.you.opacity(0.4) : .clear, radius: 7)
                .contentShape(Capsule())
        }
        .buttonStyle(PressScale(scale: 0.95))
        .disabled(!enabled)
        .animation(.easeInOut(duration: 0.26), value: on)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// `.dbadge`: day, month and time of an event.
struct DateBadge: View {
    let date: Date?

    var body: some View {
        VStack(spacing: 0) {
            if let date {
                Text(EvFmt.day(date)).font(RiftFont.display(30)).foregroundStyle(.white)
                Text(EvFmt.month(date)).caps(10, tracking: 0.14, weight: .bold).foregroundStyle(.white)
                Text(EvFmt.time(date)).font(RiftFont.text(11, .semibold)).foregroundStyle(.white.opacity(0.6)).padding(.top, 3)
            } else {
                Text("TBD").font(RiftFont.text(12, .semibold)).foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(width: 60)
        .padding(.vertical, 8)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// `.ecard`: a pressable list card with a left badge.
struct EvRowCard<Content: View>: View {
    let label: String
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22)
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) { content() }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Ev.card, in: shape)
                .overlay(shape.stroke(Ev.ring, lineWidth: 1))
                .contentShape(shape)
        }
        .buttonStyle(PressScale(scale: 0.98))
        .accessibilityLabel(label)
    }
}

/// Name, format line, pills and store line of an event card.
struct EventInfo<Pills: View>: View {
    let name: String
    let format: String?
    let storeLine: String?
    let favoriteStore: Bool
    @ViewBuilder var pills: () -> Pills

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name).font(RiftFont.text(15.5, .bold)).foregroundStyle(.white).lineLimit(2).multilineTextAlignment(.leading)
            if let format { Text(format).font(RiftFont.text(12.5)).foregroundStyle(.white.opacity(0.6)).lineLimit(1) }
            HStack(spacing: 6) { pills() }.padding(.top, 2)
            if let storeLine {
                HStack(spacing: 6) {
                    Image(systemName: favoriteStore ? "heart.fill" : "mappin")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(favoriteStore ? RiftColor.you : .white.opacity(0.7))
                    Text(storeLine).font(RiftFont.text(12, .semibold)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The status pill of an event for the signed-in player.
struct StatusPill: View {
    let state: CompeteTournament.PlayerState
    let live: Bool

    var body: some View {
        switch state {
        case .registered, .active: EvPill(text: live ? "Playing" : "Registered", bg: RiftColor.you.opacity(0.16), ink: RiftColor.you)
        case .waitlisted: EvPill(text: "Waitlisted", bg: RiftColor.gold.opacity(0.16), ink: RiftColor.gold)
        case .dropped: EvPill(text: "Dropped", bg: .white.opacity(0.1), ink: .white.opacity(0.7))
        case .eliminated: EvPill(text: "Eliminated", bg: .white.opacity(0.1), ink: .white.opacity(0.7))
        case .none: EmptyView()
        }
    }
}

/// `.empty`: a message with an action, for signed-out, failed and empty lists.
struct EmptyState: View {
    let title: String
    let text: String
    var button: String? = nil
    var action: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            Text(title).font(RiftFont.display(26)).foregroundStyle(.white).multilineTextAlignment(.center)
            EvMessage(text: text).padding(.top, 8).padding(.bottom, 18)
            if let button { EvButton(text: button, kind: .green, action: action) }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 40)
    }
}

struct EvMessage: View {
    let text: String

    var body: some View {
        Text(text)
            .font(RiftFont.text(14, .regular))
            .lineSpacing(5)
            .foregroundStyle(.white.opacity(0.66))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

/// `.spin`: the mock's ring spinner (the one animation allowed to loop while something loads).
struct EvSpinner: View {
    var size: CGFloat = 36
    @State private var turning = false

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.12), lineWidth: 3)
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(RiftColor.you, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(turning ? 360 : 0))
                .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: turning)
        }
        .frame(width: size, height: size)
        .onAppear { turning = true }
        .accessibilityLabel("Loading")
    }
}

struct EvLoading: View {
    let text: String

    var body: some View {
        VStack(spacing: 14) {
            EvSpinner()
            EvMessage(text: text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

/// `.rail`: the round clock's 4pt track, filled as time passes.
struct ClockRail: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.1))
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

/// `.prow`: a player row with a YOU tag and something on the right.
struct PersonRow<Trailing: View>: View {
    let name: String
    let you: Bool
    let divider: Bool
    var faded = false
    var tag = "YOU"
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            Text(name).font(RiftFont.text(14, .semibold)).foregroundStyle(.white.opacity(faded ? 0.5 : 1)).lineLimit(1)
            if you { MiniPill(text: tag, bg: RiftColor.you.opacity(0.16), ink: RiftColor.you) }
            Spacer(minLength: 8)
            trailing()
        }
        .frame(height: 46)
        .overlay(alignment: .bottom) { if divider { Hairline() } }
        .accessibilityElement(children: .combine)
    }
}

extension PersonRow where Trailing == EmptyView {
    init(name: String, you: Bool, divider: Bool, faded: Bool = false, tag: String = "YOU") {
        self.init(name: name, you: you, divider: divider, faded: faded, tag: tag) { EmptyView() }
    }
}

/// `.ucard`: a compact event card (name, time and store, pills).
struct UCard<Pills: View>: View {
    let name: String
    let sub: String
    let action: () -> Void
    @ViewBuilder var pills: () -> Pills

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(RiftFont.text(15.5, .bold)).foregroundStyle(.white).lineLimit(2).multilineTextAlignment(.leading)
                Text(sub).font(RiftFont.text(12.5)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                HStack(spacing: 6) { pills() }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Ev.card, in: shape)
            .overlay(shape.stroke(Ev.ring, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(PressScale(scale: 0.98))
        .accessibilityLabel("Open \(name)")
    }
}

/// `.findpill`.
struct FindPill: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.system(size: 15, weight: .semibold))
                Text("Find events near you").font(RiftFont.text(14.5, .semibold))
                Spacer()
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 18)
            .frame(height: 50)
            .background(.white.opacity(0.06), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(PressScale(scale: 0.98))
    }
}

/// `.inp`: the place field of the finders; submits on the keyboard's search key.
struct PlaceField: View {
    @Binding var text: String
    let onSubmit: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text, prompt: Text("City or address").foregroundStyle(.white.opacity(0.4)))
            .font(RiftFont.text(15))
            .foregroundStyle(.white)
            .tint(RiftColor.you)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .focused($focused)
            .onSubmit(onSubmit)
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Color(hex: "0B0B0B"), in: Capsule())
            .overlay(Capsule().stroke(focused ? RiftColor.you.opacity(0.6) : .white.opacity(0.16), lineWidth: 1))
            .animation(.easeInOut(duration: 0.25), value: focused)
    }
}
