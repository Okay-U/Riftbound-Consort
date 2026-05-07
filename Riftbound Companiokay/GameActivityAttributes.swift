import Foundation
#if os(iOS)
import ActivityKit

struct GameActivityAttributes: ActivityAttributes {
    public typealias ContentState = State

    public struct State: Codable, Hashable {
        var scores: [Int]
        var effectiveStart: Date?
        var pausedElapsed: TimeInterval
        var myDeckName: String?
        var oppDeckName: String?

        var isRunning: Bool { effectiveStart != nil }
    }

    var playerCount: Int
    var targetScore: Int
}
#endif
