//
//  ScoreboardViewModel.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 02.11.25.
//

import SwiftUI
internal import Combine


final class ScoreboardViewModel: ObservableObject {
    @AppStorage("playerCount") var playerCount: Int = 2 {
        didSet { applyPlayerCount(playerCount) }
    }

    @AppStorage("colorIdx_0") private var colorIdx0: Int = -1
    @AppStorage("colorIdx_1") private var colorIdx1: Int = -1
    @AppStorage("colorIdx_2") private var colorIdx2: Int = -1
    @AppStorage("colorIdx_3") private var colorIdx3: Int = -1

    @Published var players: [Player] = [
        Player(name: "Player 1", score: 0),
        Player(name: "Player 2", score: 0)
    ]

    private var history: [[Int]] = []

    init() { applyPlayerCount(playerCount) }

    func applyPlayerCount(_ count: Int) {
        let clamped = count == 4 ? 4 : 2
        var newPlayers = players
        if clamped == 2 {
            while newPlayers.count < 2 { newPlayers.append(Player(name: "Player \(newPlayers.count+1)", score: 0)) }
            newPlayers = Array(newPlayers.prefix(2))
        } else {
            while newPlayers.count < 4 { newPlayers.append(Player(name: "Player \(newPlayers.count+1)", score: 0)) }
            newPlayers = Array(newPlayers.prefix(4))
        }
        players = newPlayers
        history.removeAll()
    }

    private func snapshot() {
        history.append(players.map { $0.score })
        if history.count > 50 { history.removeFirst() }
    }

    func increment(_ player: Player, by value: Int = 1) {
        guard let idx = players.firstIndex(of: player) else { return }
        snapshot()
        players[idx].score += value
        Haptics.light()
    }

    func decrement(_ player: Player, by value: Int = 1) {
        guard let idx = players.firstIndex(of: player) else { return }
        snapshot()
        players[idx].score = max(0, players[idx].score - value)
        Haptics.light()
    }

    func resetScores() {
        snapshot()
        for i in players.indices { players[i].score = 0 }
        Haptics.warning()
    }

    func undo() {
        guard let last = history.popLast(), last.count == players.count else { return }
        for i in players.indices { players[i].score = last[i] }
        Haptics.medium()
    }

    // MARK: - Farben
    func colorIndex(for slot: Int) -> Int {
        switch slot {
        case 0: return colorIdx0
        case 1: return colorIdx1
        case 2: return colorIdx2
        case 3: return colorIdx3
        default: return -1
        }
    }

    func setColorIndex(_ idx: Int, for slot: Int) {
        let safe = idx == -1 ? -1 : max(0, min(idx, Palette.colors.count - 1))
        switch slot {
        case 0: colorIdx0 = safe
        case 1: colorIdx1 = safe
        case 2: colorIdx2 = safe
        case 3: colorIdx3 = safe
        default: break
        }
        objectWillChange.send()
    }
}
