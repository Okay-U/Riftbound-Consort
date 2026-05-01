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
        ticker = Timer.publish(every: 0.1, on: .main, in: .common)
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
    }

    func reset() {
        ticker = nil
        startDate = nil
        accumulated = 0
        elapsed = 0
        isRunning = false
    }

    private func tick() {
        elapsed = accumulated + Date().timeIntervalSince(startDate ?? Date())
    }
}
