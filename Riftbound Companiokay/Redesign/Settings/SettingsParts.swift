//
//  SettingsParts.swift
//  Riftbound Companiokay
//
//  Pieces of the redesign's Settings (Android `SettingsParts.kt`, mock `SettingsHybrid`): section captions,
//  grouped rows, link and switch rows, and the tiles on top that turn over to tell what they do.
//

import SwiftUI

/// "SCOREBOARD", a section caption.
struct SectionHead: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .caps(11)
            .foregroundStyle(.white.opacity(0.58))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
    }
}

/// The mock's `.group`: rows on a faint rounded panel.
struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24)
        VStack(spacing: 0) { content() }
            .background(.white.opacity(0.045), in: shape)
            .clipShape(shape)
            .overlay(shape.stroke(.white.opacity(0.08), lineWidth: 1))
    }
}

/// Icon, title and sub line of a row.
private struct RowLabel: View {
    let title: String
    let symbol: String?
    let sub: String?
    var iconOn = false

    var body: some View {
        HStack(spacing: 14) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(iconOn ? RiftColor.you : .white)
                    .frame(width: 36, height: 36)
                    .background(iconOn ? RiftColor.you.opacity(0.16) : .white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                    .animation(.easeInOut(duration: 0.4), value: iconOn)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(RiftFont.text(15.5, .semibold)).foregroundStyle(.white)
                if let sub {
                    Text(sub).font(RiftFont.text(12.5, .regular)).lineSpacing(2).foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Lights the row a little under the finger.
private struct RowPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.white.opacity(configuration.isPressed ? 0.04 : 0))
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

/// A row that opens something: a sub page (chevron) or an outside app (`external`, arrow).
struct LinkRow<Trailing: View>: View {
    let title: String
    let symbol: String?
    var sub: String? = nil
    var divider = true
    var external = false
    @ViewBuilder var trailing: () -> Trailing
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RowLabel(title: title, symbol: symbol, sub: sub)
                trailing()
                Image(systemName: external ? "arrow.up.right" : "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .overlay(alignment: .top) { if divider { Hairline() } }
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPress())
        .accessibilityHint(external ? "Opens outside the app" : "")
    }
}

extension LinkRow where Trailing == EmptyView {
    init(title: String, symbol: String?, sub: String? = nil, divider: Bool = true, external: Bool = false, action: @escaping () -> Void) {
        self.init(title: title, symbol: symbol, sub: sub, divider: divider, external: external, trailing: { EmptyView() }, action: action)
    }
}

/// A link row that opens a web page or another app.
struct ExternalRow: View {
    let title: String
    let symbol: String
    let url: URL
    var divider = true
    @Environment(\.openURL) private var openURL

    var body: some View {
        LinkRow(title: title, symbol: symbol, divider: divider, external: true) { openURL(url) }
    }
}

/// A row with a switch (Legend art in the game setup sheets).
struct ToggleRow: View {
    let title: String
    let symbol: String
    var sub: String? = nil
    var divider = true
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) { RowLabel(title: title, symbol: symbol, sub: sub, iconOn: isOn) }
            .tint(RiftColor.you)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 64)
            .overlay(alignment: .top) { if divider { Hairline() } }
    }
}

// MARK: - Tiles

private let tileShape = RoundedRectangle(cornerRadius: 24)

/// A tile on top of Settings that turns over on its long axis to tell what it does. The "i" stays on top of both
/// faces like the mock; `darkInfo`: it sits on a green face.
struct FlipTile<Front: View>: View {
    let label: String
    let info: String
    let darkInfo: Bool
    @ViewBuilder let front: () -> Front
    @State private var flipped = false

    var body: some View {
        let angle = flipped ? 180.0 : 0
        let dark = darkInfo && !flipped
        ZStack(alignment: .topTrailing) {
            ZStack {
                front().modifier(TileFace(angle: angle, back: false))
                Button { flipped = false } label: {
                    Text(info)
                        .font(RiftFont.text(12.5, .regular))
                        .lineSpacing(3)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        // The end keeps clear of the "i", which stays on this face too.
                        .padding(.leading, 14)
                        .padding(.top, 12)
                        .padding(.trailing, 34)
                        .background(Color(hex: "161616"), in: tileShape)
                        .overlay(tileShape.stroke(.white.opacity(0.14), lineWidth: 1))
                        .contentShape(tileShape)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(info)
                .accessibilityHint("Back to \(label)")
                .modifier(TileFace(angle: angle, back: true))
            }
            .animation(.rift(0.76), value: flipped)
            // A 44pt touch area in the corner around the 26pt "i".
            Button { flipped.toggle() } label: {
                Text("i")
                    .font(RiftFont.text(13, .bold).italic())
                    .foregroundStyle(dark ? Color.black : .white)
                    .frame(width: 26, height: 26)
                    .background(dark ? Color.black.opacity(0.16) : .white.opacity(0.12), in: Circle())
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                    .frame(width: 44, height: 44, alignment: .topTrailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressScale(scale: 0.9))
            .animation(.easeInOut(duration: 0.3), value: dark)
            .accessibilityLabel(flipped ? "Back to \(label)" : "What \(label) does")
        }
        .frame(height: 88)
    }
}

/// One face of a flip tile: turned with the tile and shown only while it faces the viewer.
private struct TileFace: ViewModifier, Animatable {
    var angle: Double
    let back: Bool

    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        let facing = back ? angle >= 90 : angle < 90
        content
            .rotation3DEffect(.degrees(back ? angle - 180 : angle), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
            .opacity(facing ? 1 : 0)
            .allowsHitTesting(facing)
            .accessibilityHidden(!facing)
    }
}

/// Front of a switch tile: green and glowing when on, the state underneath the name.
struct SwitchFace: View {
    let label: String
    let symbol: String
    let on: Bool
    let onToggle: () -> Void

    var body: some View {
        let ink: Color = on ? .black : .white
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ink)
                    .frame(width: 42, height: 42)
                    .background(on ? Color.black.opacity(0.14) : .white.opacity(0.08), in: Circle())
                TileText(label: label, state: on ? "On" : "Off", ink: ink)
                Spacer(minLength: 30)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(on ? RiftColor.you : .white.opacity(0.07), in: tileShape)
            .shadow(color: RiftColor.you.opacity(on ? 0.35 : 0), radius: 12)
            .contentShape(tileShape)
        }
        .buttonStyle(TilePress())
        .animation(.easeInOut(duration: 0.38), value: on)
        .accessibilityLabel(label)
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}

/// Front of the Players tile: "2P" or "4P", the old number blurs away upwards as the new one rises.
struct PlayersFace: View {
    let players: Int
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ZStack {
                    Text("\(players)P")
                        .font(RiftFont.display(32))
                        .foregroundStyle(.white)
                        .fixedSize()
                        .id(players)
                        .transition(.scoreMorph(height: 42, inDuration: 0.62, outDuration: 0.42))
                }
                .frame(width: 42, height: 42)
                .animation(.rift(0.62), value: players)
                TileText(label: "Players", state: players == 2 ? "Duel" : "Free-for-all", ink: .white)
                Spacer(minLength: 30)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white.opacity(0.08), in: tileShape)
            .contentShape(tileShape)
        }
        .buttonStyle(TilePress())
        .accessibilityLabel("Players")
        .accessibilityValue("\(players) players, \(players == 2 ? "duel" : "free-for-all")")
        .accessibilityHint("Switches to \(players == 2 ? 4 : 2) players")
    }
}

private struct TilePress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(tileShape.fill(.black.opacity(configuration.isPressed ? 0.08 : 0)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.rift(0.25), value: configuration.isPressed)
    }
}

private struct TileText: View {
    let label: String
    let state: String
    let ink: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(RiftFont.text(14.5, .bold)).foregroundStyle(ink).lineLimit(2)
            Text(state).font(RiftFont.text(12, .semibold)).foregroundStyle(ink.opacity(0.7))
        }
    }
}
