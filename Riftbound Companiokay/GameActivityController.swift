import Foundation
#if os(iOS)
import ActivityKit

@MainActor
final class GameActivityController {
    static let shared = GameActivityController()

    private var activity: Activity<GameActivityAttributes>?

    private init() {}

    var areLiveActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(playerCount: Int,
               targetScore: Int,
               scores: [Int],
               effectiveStart: Date?,
               pausedElapsed: TimeInterval,
               myDeck: String?,
               oppDeck: String?) {
        guard areLiveActivitiesEnabled else { return }
        end()
        let attrs = GameActivityAttributes(playerCount: playerCount,
                                           targetScore: targetScore)
        let state = GameActivityAttributes.State(scores: scores,
                                                 effectiveStart: effectiveStart,
                                                 pausedElapsed: pausedElapsed,
                                                 myDeckName: myDeck,
                                                 oppDeckName: oppDeck)
        do {
            activity = try Activity.request(
                attributes: attrs,
                content: .init(state: state, staleDate: Date().addingTimeInterval(4 * 3600))
            )
        } catch {
            activity = nil
        }
    }

    func update(scores: [Int]? = nil,
                effectiveStart: Date?? = nil,
                pausedElapsed: TimeInterval? = nil,
                myDeck: String?? = nil,
                oppDeck: String?? = nil) {
        guard let activity else { return }
        let cur = activity.content.state
        let newState = GameActivityAttributes.State(
            scores: scores ?? cur.scores,
            effectiveStart: effectiveStart ?? cur.effectiveStart,
            pausedElapsed: pausedElapsed ?? cur.pausedElapsed,
            myDeckName: myDeck ?? cur.myDeckName,
            oppDeckName: oppDeck ?? cur.oppDeckName
        )
        Task { await activity.update(.init(state: newState, staleDate: Date().addingTimeInterval(4 * 3600))) }
    }

    func end() {
        guard let activity else { return }
        let final = activity.content.state
        Task {
            await activity.end(.init(state: final, staleDate: Date().addingTimeInterval(4 * 3600)),
                               dismissalPolicy: .immediate)
        }
        self.activity = nil
    }

    var isActive: Bool { activity != nil }
}
#endif
