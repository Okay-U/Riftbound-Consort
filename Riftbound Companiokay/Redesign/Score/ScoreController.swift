//
//  ScoreController.swift
//  Riftbound Companiokay
//
//  The redesign's scoreboard (Android `ScoreController`): the rules state, the who-goes-first roll, the
//  board's toasts, the game setup in the classic keys (`activeDeckId`, `activeOpponent`,
//  `activeStartedFirst`), finished games into `games.json`. The board is saved on every change.
//

import Foundation
internal import Combine

struct BoardToast: Equatable {
    let text: String
    let id = UUID()
}

@MainActor
final class ScoreController: ObservableObject {
    @Published private(set) var state: ScoreState
    @Published private(set) var firstRoll: FirstRoll?
    @Published private(set) var toast: BoardToast?
    /// The half that declined the conquering 8th point: it shows "draw a card" for a moment.
    @Published private(set) var drew = -1
    @Published var confirmRestart = false

    @Published private(set) var deckId: String
    @Published private(set) var opponent: String
    /// "first", "second" or "" (unknown); the roll sets it too.
    @Published private(set) var turnOrder: String

    private weak var games: GameRecordStore?
    private weak var decks: DecklistStore?
    private var tumbles: [Task<Void, Never>] = []
    private var drewTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard

    private static let stateKey = "redesign.scoreboard"

    init() {
        deckId = defaults.string(forKey: "activeDeckId") ?? ""
        opponent = defaults.string(forKey: "activeOpponent") ?? ""
        turnOrder = defaults.string(forKey: "activeStartedFirst") ?? ""
        state = Self.restore(defaults)
    }

    /// The stores live at the app root; the board needs them for names and the match log.
    func attach(games: GameRecordStore, decks: DecklistStore) {
        self.games = games
        self.decks = decks
        // The halves were drawn before: now they can name your deck's legend.
        objectWillChange.send()
    }

    // MARK: Names

    func legend(_ slot: Int) -> String {
        guard state.isDuel else { return "Player \(slot + 1)" }
        if slot == Seat.you {
            return activeDeck?.legend.map { Self.displayName($0.cardName) } ?? "You"
        }
        let name = opponent.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Opponent" : Self.displayName(name)
    }

    /// First name for sentences: "Darius starts", "You start".
    func shortName(_ slot: Int) -> String {
        legend(slot).components(separatedBy: " · ").first ?? legend(slot)
    }

    private var activeDeck: Decklist? {
        decks?.lists.first { $0.id.uuidString.caseInsensitiveCompare(deckId) == .orderedSame }
    }

    /// "Darius - Hand of Noxus" or "Darius, Hand of Noxus" reads "Darius · Hand of Noxus".
    static func displayName(_ card: String) -> String {
        var name = card.replacingOccurrences(of: #"\s*\(.*?\)\s*$"#, with: "", options: .regularExpression)
        name = name.replacingOccurrences(of: " - ", with: " · ")
        if let comma = name.range(of: ", ") { name.replaceSubrange(comma, with: " · ") }
        return name.trimmingCharacters(in: .whitespaces)
    }

    // MARK: Scoring

    func score(_ slot: Int, _ kind: PointKind) { apply(state.score(slot, kind, at: Date()), .tick) }
    func fix(_ slot: Int) { apply(state.fix(slot, at: Date()), .tick) }
    func xp(_ slot: Int, _ delta: Int) { apply(state.xp(slot, delta), .tick) }
    func undo() { apply(state.undo(), .undo) }
    func toggleClock() { apply(state.toggleClock(at: Date()), .tick) }
    func nextGame() { apply(state.nextGame(at: Date()), .tick) }

    /// Whose half asks who starts, or -1 (the question goes stale after a while).
    var startChooser: Int { state.startChooser(at: Date()) }

    /// The last game's loser goes first or second.
    func pickStart(first: Bool) {
        let chooser = state.chooser
        guard chooser >= 0 else { return }
        let starter = first ? chooser : 1 - chooser
        pickTurnOrder(starter == Seat.you ? "first" : "second")
        apply(state.withStarter(starter, at: Date()), .success)
        show(startsText(starter))
    }

    func finalPoint(_ scoreIt: Bool) {
        let slot = state.asking
        apply(state.confirmFinalPoint(scoreIt, at: Date()), .tick)
        guard !scoreIt, slot >= 0 else { return }
        drew = slot
        drewTask?.cancel()
        drewTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(2400))
            guard !Task.isCancelled else { return }
            self?.drew = -1
        }
    }

    func askRestart() {
        if !state.gameOver && !state.matchOver && !state.ended { confirmRestart = true }
    }

    func restart() {
        confirmRestart = false
        apply(state.restart(), .warning)
    }

    func newMatch() { apply(state.newMatch(), .warning) }

    /// From Settings: an open roll has one die per seat, so it closes.
    func setPlayers(_ count: Int) {
        closeRoll()
        apply(state.withPlayerCount(count), nil)
    }

    // MARK: Game setup

    func pickDeck(_ id: String) {
        deckId = id
        defaults.set(id, forKey: "activeDeckId")
    }

    func pickOpponent(_ name: String) {
        opponent = name
        defaults.set(name, forKey: "activeOpponent")
    }

    func pickTurnOrder(_ value: String) {
        turnOrder = value
        defaults.set(value, forKey: "activeStartedFirst")
    }

    // MARK: Who goes first

    func openRoll() {
        stopTumbles()
        firstRoll = FirstRoll.start(players: state.players.count)
    }

    func closeRoll() {
        stopTumbles()
        firstRoll = nil
    }

    func rollKind(_ kind: FirstRoll.DieKind) {
        guard let current = firstRoll, !current.busy else { return }
        stopTumbles()
        firstRoll = FirstRoll.start(players: current.dice.count, kind: kind)
    }

    func rollAll() {
        guard let current = firstRoll else { return }
        for slot in current.dice.indices { roll(slot) }
    }

    func roll(_ slot: Int) {
        guard let current = firstRoll, current.canRoll(slot) else { return }
        firstRoll = current.rolling(slot)
        let sides = current.kind.rawValue
        let final = Int.random(in: 1...sides)
        tumbles.append(Task { [weak self] in
            let waits = FirstRoll.tumbleWaitsMs
            for (i, wait) in waits.enumerated() {
                try? await Task.sleep(for: .milliseconds(wait))
                guard !Task.isCancelled, let self, let current = self.firstRoll else { return }
                let last = i == waits.count - 1
                var rng = SystemRandomNumberGenerator()
                let face = last ? final : FirstRoll.face(sides: sides, notThis: current.dice[slot].value, using: &rng)
                self.firstRoll = current.shown(slot, value: face, done: last)
                if last { Haptics.success() } else { Haptics.light(0.5) }
            }
            guard let self, self.firstRoll?.tie == true else { return }
            try? await Task.sleep(for: .milliseconds(1600))
            guard !Task.isCancelled else { return }
            self.firstRoll = self.firstRoll?.rerolled()
        })
    }

    /// The winner of the roll picks first or second, and the game starts (no second question).
    func choose(_ choice: FirstRoll.Choice) {
        guard var current = firstRoll else { return }
        current.choice = choice
        firstRoll = current
        startGame()
    }

    func rollAgain() {
        guard let current = firstRoll else { return }
        stopTumbles()
        firstRoll = FirstRoll.start(players: current.dice.count, kind: current.kind)
    }

    func startGame() {
        guard let current = firstRoll else { return }
        let starter = current.starter()
        guard starter >= 0 else { return }
        stopTumbles()
        firstRoll = nil
        if state.isDuel { pickTurnOrder(starter == Seat.you ? "first" : "second") }
        apply(state.withStarter(starter, at: Date()), .success)
        show(startsText(starter))
    }

    private func startsText(_ starter: Int) -> String {
        state.isDuel && starter == Seat.you && legend(Seat.you) == "You" ? "You start · good game" : "\(shortName(starter)) starts · good game"
    }

    private func stopTumbles() {
        tumbles.forEach { $0.cancel() }
        tumbles.removeAll()
    }

    // MARK: Plumbing

    func show(_ text: String) { toast = BoardToast(text: text) }

    func clearToast(_ id: UUID) {
        if toast?.id == id { toast = nil }
    }

    private enum Buzz { case tick, undo, success, warning }

    private func apply(_ next: ScoreState, _ buzz: Buzz?) {
        guard next != state else { return }
        let wonNow = !state.gameOver && next.gameOver
        state = next
        if let data = try? JSONEncoder().encode(next) { defaults.set(data, forKey: Self.stateKey) }
        if wonNow {
            record(winner: next.winner, next)
            Haptics.success()
            return
        }
        switch buzz {
        case .tick: Haptics.light()
        case .undo: Haptics.medium()
        case .success: Haptics.success()
        case .warning: Haptics.warning()
        case nil: break
        }
    }

    /// The finished game into `games.json`, from your side (slot 1), like the classic Won/Lost.
    private func record(winner: Int, _ s: ScoreState) {
        guard s.isDuel, let games else { return }
        let deck = activeDeck
        let startedFirst: Bool? = s.starter >= 0 ? s.starter == Seat.you
            : turnOrder == "first" ? true : turnOrder == "second" ? false : nil
        games.record(GameRecord(
            deckId: deck?.id,
            deckName: deck?.name,
            opponent: opponent.trimmingCharacters(in: .whitespaces),
            result: winner == Seat.you ? .won : .lost,
            durationSeconds: s.gameSeconds(at: Date()),
            events: s.events,
            startedFirst: startedFirst
        ))
    }

    private static func restore(_ defaults: UserDefaults) -> ScoreState {
        let saved = defaults.data(forKey: stateKey).flatMap { try? JSONDecoder().decode(ScoreState.self, from: $0) }
        var board = saved ?? ScoreState()
        // A series belongs to a live match only; one saved without its pairing reads as casual.
        if board.bestOf > 0 && board.liveTag == nil {
            board.bestOf = 0
            board.log = []
        }
        return board.withPlayerCount(defaults.integer(forKey: "playerCount"))
    }
}
