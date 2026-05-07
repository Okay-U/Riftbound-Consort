import Foundation

enum AppGroup {
    static let identifier = "group.pitopia.Riftcount"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    enum Keys {
        static let scores       = "shared.scores"        // [Int]
        static let playerCount  = "shared.playerCount"   // Int
        static let targetScore  = "shared.targetScore"   // Int
        static let myDeckName   = "shared.myDeckName"    // String?
        static let oppDeckName  = "shared.oppDeckName"   // String?
    }
}

struct SharedScoreboard {
    static func writeScores(_ scores: [Int]) {
        AppGroup.defaults.set(scores, forKey: AppGroup.Keys.scores)
    }

    static func readScores() -> [Int] {
        AppGroup.defaults.array(forKey: AppGroup.Keys.scores) as? [Int] ?? []
    }

    static func writePlayerCount(_ n: Int) {
        AppGroup.defaults.set(n, forKey: AppGroup.Keys.playerCount)
    }

    static func writeTargetScore(_ n: Int) {
        AppGroup.defaults.set(n, forKey: AppGroup.Keys.targetScore)
    }

    static func writeDeckNames(my: String?, opp: String?) {
        AppGroup.defaults.set(my, forKey: AppGroup.Keys.myDeckName)
        AppGroup.defaults.set(opp, forKey: AppGroup.Keys.oppDeckName)
    }

    static func mutateScore(slot: Int, delta: Int) -> [Int] {
        var s = readScores()
        guard s.indices.contains(slot) else { return s }
        s[slot] = max(0, s[slot] + delta)
        writeScores(s)
        return s
    }
}
