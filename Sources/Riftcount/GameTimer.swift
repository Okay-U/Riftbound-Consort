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
                try? await Task.sleep(nanoseconds: 100_000_000)
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
        elapsed = accumulated + Date().timeIntervalSince(startDate)
    }
}
