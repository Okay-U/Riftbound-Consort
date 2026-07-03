import Foundation

struct Player: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var score: Int
    var xp: Int = 0
}

enum ScoreEventType: String, Codable, Sendable {
    case conquer
    case hold
    case manual
}

struct ScoreEvent: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let elapsedSeconds: Int
    let slot: Int
    let type: ScoreEventType
    let delta: Int

    init(
        id: UUID = UUID(),
        elapsedSeconds: Int,
        slot: Int,
        type: ScoreEventType,
        delta: Int
    ) {
        self.id = id
        self.elapsedSeconds = elapsedSeconds
        self.slot = slot
        self.type = type
        self.delta = delta
    }

    enum CodingKeys: String, CodingKey {
        case id
        case elapsedSeconds = "elapsed_seconds"
        case slot
        case type
        case delta
    }
}
