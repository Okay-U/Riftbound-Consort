import Foundation
import Observation
import SkipFuse

/// Game timer, ported from iOS. Structured-concurrency ticker instead of
/// Combine's Timer.publish (Combine is not available in native Skip mode).
@Observable @MainActor
public final class GameTimer {
    private(set) var elapsed: TimeInterval = 0
    private(set) var isRunning: Bool = false

    private var accumulated: TimeInterval = 0
    private var startDate: Date?
    private var ticker: Task<Void, Never>?

    func start() {
        guard !isRunning else { return }
        startDate = Date()
        isRunning = true
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                self?.tick()
            }
        }
    }

    func pause() {
        guard isRunning else { return }
        accumulated += Date().timeIntervalSince(startDate ?? Date())
        ticker?.cancel()
        ticker = nil
        startDate = nil
        isRunning = false
        elapsed = accumulated   // exact value on the badge while paused
    }

    func reset() {
        ticker?.cancel()
        ticker = nil
        startDate = nil
        accumulated = 0
        elapsed = 0
        isRunning = false
    }

    private func tick() {
        guard isRunning, let startDate else { return }
        let now = accumulated + Date().timeIntervalSince(startDate)
        // Mutate only when the displayed second changes: every @Observable
        // mutation recomposes every observer — the ENTIRE scoreboard. The old
        // 0.1s tick meant 10 full recompositions per second for the whole
        // game; now it's 1 (the 0.25s tick itself is cheap Date math, keeping
        // second-flips on time).
        if Int(now) != Int(elapsed) {
            elapsed = now
        }
    }
}
