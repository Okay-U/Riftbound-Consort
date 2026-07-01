//
//  RankVisuals.swift
//  Riftbound Companiokay
//
//  Shared tier color + crest rendering for eloshowdown ranks. Uses the official
//  League tier crests bundled as rank_<tier> assets, with a colored-shield
//  fallback for any tier without one (e.g. Emerald). Used by the opponent
//  scouting badge; ProfileView has its own inline copy (candidate to unify).
//

import SwiftUI

/// Accent color per tier (iron…challenger). The real crests are Riot art and
/// aren't in the API, so unmatched tiers render a colored shield in this hue.
func rankTierColor(_ tier: String?) -> Color {
    switch (tier ?? "").lowercased() {
    case "iron":        return Color(red: 0.46, green: 0.43, blue: 0.41)
    case "bronze":      return Color(red: 0.72, green: 0.45, blue: 0.28)
    case "silver":      return Color(red: 0.68, green: 0.72, blue: 0.76)
    case "gold":        return Color(red: 0.93, green: 0.74, blue: 0.30)
    case "platinum":    return Color(red: 0.26, green: 0.73, blue: 0.71)
    case "emerald":     return Color(red: 0.18, green: 0.78, blue: 0.46)
    case "diamond":     return Color(red: 0.42, green: 0.62, blue: 0.96)
    case "master":      return Color(red: 0.72, green: 0.42, blue: 0.92)
    case "grandmaster": return Color(red: 0.86, green: 0.32, blue: 0.32)
    case "challenger":  return Color(red: 0.58, green: 0.82, blue: 0.96)
    default:            return EventsTheme.textSecondary
    }
}

/// A tier crest: the official `rank_<tier>` asset when present, else a shield.
struct RankCrest: View {
    let tier: String?
    var size: CGFloat = 24

    private static let crestTiers: Set<String> = [
        "iron", "bronze", "silver", "gold", "platinum",
        "diamond", "master", "grandmaster", "challenger"
    ]

    var body: some View {
        let key = (tier ?? "").lowercased()
        Group {
            if Self.crestTiers.contains(key) {
                Image("rank_\(key)").resizable().scaledToFit()
            } else {
                Image(systemName: "shield.fill")
                    .font(.system(size: size * 0.62, weight: .bold))
                    .foregroundStyle(rankTierColor(tier))
            }
        }
        .frame(width: size, height: size)
    }
}
