//
//  LegendArt.swift
//  Riftbound Companiokay
//
//  Legend art (docs/IOS_REDESIGN.md "Score tile look", Android `LegendArt`): a half shows its legend's
//  champion as Data Dragon's base splash, loaded when needed, so the app carries no pictures and a new
//  legend works by itself. tools/check-scoreboard checks the names.
//

import Foundation

nonisolated enum LegendArt {
    /// Data Dragon ids that are not the champion's letters: every one of the 173 champions on 16.13.
    private static let ids = [
        "Bel'Veth": "Belveth", "Cho'Gath": "Chogath", "Kai'Sa": "Kaisa", "Kha'Zix": "Khazix", "LeBlanc": "Leblanc",
        "Wukong": "MonkeyKing", "Nunu & Willump": "Nunu", "Renata Glasc": "Renata", "Vel'Koz": "Velkoz",
    ]

    /// The champion a legend is: "Kai'Sa - Daughter of the Void (Signature)" or "Kai'Sa, …" is "Kai'Sa".
    static func champion(_ legend: String) -> String {
        let name = legend.replacingOccurrences(of: #"\s*\(.*?\)\s*$"#, with: "", options: .regularExpression)
        let head = name.components(separatedBy: " - ").first ?? name
        return (head.components(separatedBy: ", ").first ?? head).trimmingCharacters(in: .whitespaces)
    }

    /// The champion's base splash; nil without a name.
    static func url(legend: String) -> URL? {
        let champion = champion(legend)
        let id = ids[champion] ?? champion.filter { $0.isASCII && $0.isLetter }
        guard !id.isEmpty else { return nil }
        return URL(string: "https://ddragon.leagueoflegends.com/cdn/img/champion/centered/\(id)_0.jpg")
    }
}
