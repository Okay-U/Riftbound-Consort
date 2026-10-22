//
//  CardTraits.swift
//  Riftbound Companiokay
//
//  What the redesign asks of a card (Android `Card.kt`): its kind, names and shown domains. Foundation only,
//  so tools/check-decks compiles it on the Mac.
//

import Foundation

extension Card {
    var typeName: String { classification?.type ?? "" }
    var rarityName: String { classification?.rarity ?? "" }
    var isLegend: Bool { typeName.lowercased() == "legend" }
    /// Champion units; the "(Starter)" legends carry the champion supertype too.
    var isChampionUnit: Bool { isChampion && !isLegend }
    var isToken: Bool { classification?.supertype?.lowercased() == "token" }
    /// Previewed by Riot but not legal yet; the policy asks for a visible label.
    var isPreview: Bool { unreleased == true }
    var isLandscape: Bool { orientation?.lowercased() == "landscape" }

    /// "Darius - Hand of Noxus" → "Darius", the legend part before the comma or dash.
    var title: String { Card.championName(name) }

    /// "Hand of Noxus"; "Eager Admirer" for "Allay, Eager Admirer"; no printing suffix.
    var subtitle: String? {
        let rest: String
        if let dash = name.range(of: " - ") {
            rest = String(name[dash.upperBound...])
        } else if let comma = name.range(of: ", ") {
            rest = String(name[comma.upperBound...])
        } else {
            return nil
        }
        let bare = (rest.components(separatedBy: " (").first ?? rest).trimmingCharacters(in: .whitespaces)
        return bare.isEmpty ? nil : bare
    }

    /// Domains worth showing: the feed writes "Colorless" as one.
    var shownDomains: [String] { domains.filter { $0.lowercased() != "colorless" } }
}
