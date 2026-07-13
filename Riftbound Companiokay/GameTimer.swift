//
//  GameTimer.swift
//  Riftbound Companiokay
//

internal import Combine
import Foundation

@MainActor
final class GameTimer: ObservableObject {
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var isRunning: Bool = false

    private var accumulated: TimeInterval = 0
    private var startDate: Date?
    private var ticker: AnyCancellable?

    func start() {
        guard !isRunning else { return }
        startDate = Date()
        ticker = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
        isRunning = true
    }

    func pause() {
        guard isRunning else { return }
        accumulated += Date().timeIntervalSince(startDate ?? Date())
        ticker = nil
        startDate = nil
        isRunning = false
        elapsed = accumulated   // exact value on the badge while paused
    }

    func reset() {
        ticker = nil
        startDate = nil
        accumulated = 0
        elapsed = 0
        isRunning = false
        #if os(iOS)
        GameActivityController.shared.end()
        #endif
    }

    private func tick() {
        let now = accumulated + Date().timeIntervalSince(startDate ?? Date())
        // Publish only when the displayed second changes: @Published fires on
        // every assignment, and each publish re-renders every observer — the
        // ENTIRE scoreboard. The old 0.1s tick meant 10 full scoreboard
        // re-renders per second for the whole game; now it's 1 (the 0.25s
        // tick itself is just cheap Date math, keeping second-flips on time).
        if Int(now) != Int(elapsed) {
            elapsed = now
        }
    }
}
