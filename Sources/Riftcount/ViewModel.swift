import Foundation
import Observation
import SkipFuse

/// Full port of the iOS ScoreboardViewModel.
/// Differences from the iOS original:
/// - @Observable instead of ObservableObject/Combine (Skip Fuse convention).
/// - UserDefaults directly instead of @AppStorage (class context, cross-platform).
/// - No SharedScoreboard push (App Group widget/Live Activity is iOS-only;
///   reintroduce behind #if !os(Android) when the iOS target moves here).
@Observable public class ScoreboardViewModel {
    var playerCount: Int {
        didSet {
            UserDefaults.standard.set(playerCount, forKey: "playerCount")
            applyPlayerCount(playerCount)
        }
    }

    var players: [Player] = [
        Player(name: "Player 1", score: 0),
        Player(name: "Player 2", score: 0),
    ]

    private(set) var events: [ScoreEvent] = []

    private struct Snapshot {
        let scores: [Int]
        let xps: [Int]
        let events: [ScoreEvent]
    }
    private var history: [Snapshot] = []

    // Color indexes are held in observable state so views update on change;
    // UserDefaults is the persistence backing.
    private var colorIndexes: [Int]

    init() {
        let storedCount = UserDefaults.standard.object(forKey: "playerCount") as? Int ?? 2
        self.playerCount = storedCount
        self.colorIndexes = (0..<4).map { slot in
            UserDefaults.standard.object(forKey: "colorIdx_\(slot)") as? Int ?? -1
        }
        applyPlayerCount(storedCount)
    }

    func applyPlayerCount(_ count: Int) {
        let clamped = count == 4 ? 4 : 2
        var newPlayers = players
        while newPlayers.count < clamped {
            newPlayers.append(Player(name: "Player \(newPlayers.count + 1)", score: 0))
        }
        newPlayers = Array(newPlayers.prefix(clamped))
        players = newPlayers
        history.removeAll()
        events.removeAll()
    }

    private func snapshot() {
        history.append(Snapshot(
            scores: players.map(\.score),
            xps: players.map(\.xp),
            events: events
        ))
        if history.count > 50 { history.removeFirst() }
    }

    func recordEvent(
        _ player: Player,
        type: ScoreEventType,
        delta: Int,
        elapsedSeconds: Int
    ) {
        guard let idx = players.firstIndex(of: player) else { return }
        let oldScore = players[idx].score
        let newScore = max(0, oldScore + delta)
        let effective = newScore - oldScore
        guard effective != 0 else { return }
        snapshot()
        players[idx].score = newScore
        events.append(ScoreEvent(
            elapsedSeconds: elapsedSeconds,
            slot: idx,
            type: type,
            delta: effective
        ))
        Haptics.light()
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

    func incrementXP(_ player: Player, by value: Int = 1) {
        guard let idx = players.firstIndex(of: player) else { return }
        snapshot()
        players[idx].xp += value
        Haptics.light()
    }

    func decrementXP(_ player: Player, by value: Int = 1) {
        guard let idx = players.firstIndex(of: player) else { return }
        snapshot()
        players[idx].xp = max(0, players[idx].xp - value)
        Haptics.light()
    }

    func resetScores() {
        snapshot()
        for i in players.indices {
            players[i].score = 0
            players[i].xp = 0
        }
        events.removeAll()
        Haptics.warning()
    }

    var canUndo: Bool { !history.isEmpty }

    func undo() {
        guard let last = history.popLast(),
              last.scores.count == players.count,
              last.xps.count == players.count else { return }
        for i in players.indices {
            players[i].score = last.scores[i]
            players[i].xp = last.xps[i]
        }
        events = last.events
        Haptics.medium()
    }

    // MARK: - Colors

    func colorIndex(for slot: Int) -> Int {
        guard colorIndexes.indices.contains(slot) else { return -1 }
        return colorIndexes[slot]
    }

    func setColorIndex(_ idx: Int, for slot: Int) {
        guard colorIndexes.indices.contains(slot) else { return }
        let safe = idx == -1 ? -1 : max(0, min(idx, Palette.colors.count - 1))
        colorIndexes[slot] = safe
        UserDefaults.standard.set(safe, forKey: "colorIdx_\(slot)")
    }

    func paletteColor(for slot: Int) -> PaletteColor? {
        Palette.entry(for: colorIndex(for: slot))
    }
}
