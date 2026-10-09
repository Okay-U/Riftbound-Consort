//
//  PlayRiftboundFeatures.swift
//  Riftbound Companiokay
//
//  Riot approved three operations for the session client (PlayerTournaments,
//  GetCompeteTournamentForRiftboundPlayer, SubmitGameResults). Event search,
//  favourite stores and register / drop use further operations of the site's
//  API that are not covered yet. They are on for development and testing;
//  set `unapproved` to false for a store release that goes out before Riot
//  extends the approval.
//

import Foundation

enum PlayRiftboundFeatures {
    /// Event search, favourite stores, register / drop.
    static let unapproved = true
}
