//
//  Models.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 02.11.25.
//

import Foundation

struct Player: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var score: Int
    var xp: Int = 0
}
