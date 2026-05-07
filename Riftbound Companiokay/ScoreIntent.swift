import Foundation
#if os(iOS)
import AppIntents
import ActivityKit

struct ScoreIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Change Score"
    static var description = IntentDescription("Increment or decrement a player's score from the Live Activity.")
    static var isDiscoverable: Bool = false

    @Parameter(title: "Slot") var slot: Int
    @Parameter(title: "Delta") var delta: Int

    init() {}

    init(slot: Int, delta: Int) {
        self.slot = slot
        self.delta = delta
    }

    func perform() async throws -> some IntentResult {
        let newScores = SharedScoreboard.mutateScore(slot: slot, delta: delta)
        for activity in Activity<GameActivityAttributes>.activities {
            let cur = activity.content.state
            let next = GameActivityAttributes.State(
                scores: newScores,
                effectiveStart: cur.effectiveStart,
                pausedElapsed: cur.pausedElapsed,
                myDeckName: cur.myDeckName,
                oppDeckName: cur.oppDeckName
            )
            await activity.update(.init(state: next,
                                        staleDate: Date().addingTimeInterval(4 * 3600)))
        }
        return .result()
    }
}
#endif
