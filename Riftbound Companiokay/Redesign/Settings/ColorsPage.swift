//
//  ColorsPage.swift
//  Riftbound Companiokay
//
//  Player colors (Android `ColorsPage.kt`): a live preview of the table, then a palette per seat. Taking a
//  colour another seat has swaps the two (classic `ColorSettingsSheet`); picks are saved as `colorIdx_<slot>`.
//

import SwiftUI

extension PlayerSwatches {
    static func name(_ index: Int) -> String {
        switch index {
        case riftGreen: return "Rift Green"
        case riftViolet: return "Rift Violet"
        default: return Palette.name(for: index)
        }
    }

    /// Each seat's colour index as the scoreboard shows it.
    static func picks(players: Int, defaults: UserDefaults = .standard) -> [Int] {
        resolve(picked: (0..<players).map { defaults.object(forKey: "colorIdx_\($0)") as? Int ?? -1 }, players: players)
    }

    /// "Rift Green vs Rift Violet" under the Player colors row.
    static func summary(players: Int) -> String {
        guard players == 2 else { return "One color per seat" }
        let picks = picks(players: 2)
        return "\(name(picks[Seat.you])) vs \(name(picks[Seat.opponent]))"
    }
}

/// The colour dots on the Player colors row.
struct ColorDots: View {
    let players: Int

    var body: some View {
        let picks = PlayerSwatches.picks(players: players)
        let seats = players == 2 ? [Seat.you, Seat.opponent] : Array(0..<players)
        HStack(spacing: 6) {
            ForEach(seats, id: \.self) { seat in
                Circle()
                    .fill(PlayerSwatches.color(picks[seat]) ?? RiftColor.you)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(.black.opacity(0.4), lineWidth: 2))
            }
        }
        .accessibilityHidden(true)
    }
}

struct ColorsPage: View {
    let players: Int
    let onToast: (String) -> Void
    @Environment(\.riftPage) private var page
    @State private var picks: [Int] = []
    @State private var appeared = false

    var body: some View {
        let seats: [(slot: Int, name: String)] = players == 2
            ? [(Seat.you, "You"), (Seat.opponent, "Opponent")]
            : (0..<players).map { ($0, "Player \($0 + 1)") }
        let colors = picks.map { PlayerSwatches.color($0) ?? RiftColor.you }
        VStack(alignment: .leading, spacing: 0) {
            if colors.count == players {
                Group {
                    if players == 2 { DuelPreview(you: colors[Seat.you], opponent: colors[Seat.opponent], page: page) } else { TablePreview(colors: colors, page: page) }
                }
                .animation(.easeInOut(duration: 0.5), value: picks)
                .riseIn(appeared, delay: 0)
                ForEach(Array(seats.enumerated()), id: \.offset) { i, seat in
                    VStack(spacing: 0) {
                        SectionHead(title: players == 2 && seat.slot == Seat.you ? "Your color" : "\(seat.name) color")
                        SwatchGrid(chosen: picks[seat.slot], page: page) { pick(seat.slot, $0) }
                        Text("\(seat.name) · \(PlayerSwatches.name(picks[seat.slot]))")
                            .font(RiftFont.text(12.5, .regular))
                            .foregroundStyle(.white.opacity(0.66))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    }
                    .padding(.top, 22)
                    .riseIn(appeared, delay: 0.06 + Double(i) * 0.06)
                }
            }
        }
        .onAppear {
            picks = PlayerSwatches.picks(players: players)
            appeared = true
        }
    }

    /// The colour for the seat; a seat that had it takes this seat's old colour, so no two seats share one.
    private func pick(_ slot: Int, _ index: Int) {
        guard picks[slot] != index else { return }
        let other = picks.firstIndex(of: index)
        var next = picks
        if let other { next[other] = picks[slot] }
        next[slot] = index
        picks = next
        let defaults = UserDefaults.standard
        defaults.set(index, forKey: "colorIdx_\(slot)")
        Haptics.selection()
        if let other {
            defaults.set(next[other], forKey: "colorIdx_\(other)")
            onToast("Swapped colors")
        }
    }
}

private let fieldAlpha = 0x22 / 255.0

/// The mock's preview: both halves in their colours, the glowing line in yours.
private struct DuelPreview: View {
    let you: Color
    let opponent: Color
    let page: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 26)
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                opponent.opacity(fieldAlpha)
                SeatLabel(text: "Opponent").padding(.leading, 16).padding(.top, 12)
                PreviewNumber(text: "5", color: opponent, size: 64)
                    .rotationEffect(.degrees(180))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
            }
            ZStack(alignment: .bottomLeading) {
                you.opacity(fieldAlpha)
                SeatLabel(text: "You").padding(.leading, 16).padding(.bottom, 12)
                PreviewNumber(text: "6", color: you, size: 64)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 18)
            }
        }
        .overlay {
            Rectangle().fill(you).frame(height: 2).shadow(color: you, radius: 8)
        }
        .frame(height: 200)
        .background(page)
        .clipShape(shape)
        .overlay(shape.stroke(.white.opacity(0.1), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of the scoreboard colors")
    }
}

/// Four seats like the 4-player scoreboard: the far row turned around.
private struct TablePreview: View {
    let colors: [Color]
    let page: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 26)
        VStack(spacing: 0) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(row == 0 ? [1, 0] : [2, 3], id: \.self) { slot in
                        ZStack(alignment: .topLeading) {
                            colors[slot].opacity(fieldAlpha)
                            SeatLabel(text: "P\(slot + 1)").padding(.leading, 12).padding(.top, 10)
                            PreviewNumber(text: "\(slot + 3)", color: colors[slot], size: 48)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .rotationEffect(.degrees(row == 0 ? 180 : 0))
            }
        }
        .frame(height: 200)
        .background(page)
        .clipShape(shape)
        .overlay(shape.stroke(.white.opacity(0.1), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of the scoreboard colors")
    }
}

private struct SeatLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased()).caps(10.5).foregroundStyle(.white.opacity(0.75))
    }
}

private struct PreviewNumber: View {
    let text: String
    let color: Color
    let size: CGFloat

    var body: some View {
        Text(text).font(RiftFont.display(size)).foregroundStyle(color)
    }
}

/// Four columns of 54pt swatches; the chosen one gets a ring in its colour and a check.
private struct SwatchGrid: View {
    let chosen: Int
    let page: Color
    let onPick: (Int) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            ForEach(PlayerSwatches.offered, id: \.self) { index in
                let color = PlayerSwatches.color(index) ?? .white
                let on = index == chosen
                let shape = RoundedRectangle(cornerRadius: 18)
                Button { onPick(index) } label: {
                    ZStack {
                        shape.fill(color)
                        if on { Image(systemName: "checkmark").font(.system(size: 16, weight: .heavy)).foregroundStyle(color.ink) }
                    }
                    .frame(height: 54)
                    // box-shadow: 0 0 0 3px page, 0 0 0 5px colour
                    .background {
                        if on {
                            RoundedRectangle(cornerRadius: 23).fill(color).padding(-5)
                            RoundedRectangle(cornerRadius: 21).fill(page).padding(-3)
                        }
                    }
                    .shadow(color: on ? color : .clear, radius: 9)
                    .animation(.easeInOut(duration: 0.4), value: on)
                    .contentShape(shape)
                }
                .buttonStyle(PressScale(scale: 0.94))
                .accessibilityLabel(PlayerSwatches.name(index))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.top, 4)
    }
}
