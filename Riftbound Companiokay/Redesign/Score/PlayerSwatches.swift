//
//  PlayerSwatches.swift
//  Riftbound Companiokay
//
//  Player colours (Android `PlayerColors`): the classic palette (stored index 0-14 in `colorIdx_N`)
//  plus Rift Green (15) and Rift Violet (16). By default you are green and the opponent violet.
//

import SwiftUI

enum PlayerSwatches {
    static let riftGreen = 15
    static let riftViolet = 16
    /// Deep Night stays readable for old picks but is not offered.
    private static let deepNight = 11
    static let offered: [Int] = [riftGreen, riftViolet] + Palette.colors.indices.filter { $0 != deepNight }

    static func color(_ index: Int) -> Color? {
        switch index {
        case riftGreen: return RiftColor.you
        case riftViolet: return RiftColor.opponent
        default: return Palette.colors.indices.contains(index) ? Palette.colors[index] : nil
        }
    }

    /// One colour per seat from the saved picks.
    static func colors(players: Int, defaults: UserDefaults = .standard) -> [Color] {
        let picked = (0..<players).map { defaults.object(forKey: "colorIdx_\($0)") as? Int ?? -1 }
        return resolve(picked: picked, players: players).map { color($0) ?? RiftColor.you }
    }

    /// Defaults: you green and the opponent violet; with four players blue and yellow join.
    private static func defaultIndex(_ slot: Int, players: Int) -> Int {
        players == 2 ? (slot == Seat.you ? riftGreen : riftViolet) : [riftViolet, 1, riftGreen, 2][slot]
    }

    /// Saved picks stay; a seat without one takes its default, or, when a pick has that, a default left
    /// free and then the first free colour (2 and 4 players share the keys).
    static func resolve(picked: [Int], players: Int) -> [Int] {
        var taken = Set(picked.filter { color($0) != nil })
        let spare = (0..<players).map { defaultIndex($0, players: players) } + offered
        return picked.enumerated().map { slot, pick in
            if color(pick) != nil { return pick }
            let fallback = defaultIndex(slot, players: players)
            let chosen = taken.contains(fallback) ? (spare.first { !taken.contains($0) } ?? fallback) : fallback
            taken.insert(chosen)
            return chosen
        }
    }
}
