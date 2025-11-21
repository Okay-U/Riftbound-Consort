//
//  Palette.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 02.11.25.
//


import SwiftUI

enum Palette {
    static let colors: [Color] = [
        // Light pastels
        Color(hex: "FF004A"),
        Color(hex: "4250FF"),
        Color(hex: "FFC300"),
        Color(hex: "F897FF"),
        Color(hex: "7415FE"),
        Color(hex: "00D06B"),
        Color(hex: "FF5100"),
        
        // Dunklere Farben
        Color(hex: "948979"),
        Color(hex: "37353E"),
        Color(hex: "715A5A"),
        Color(hex: "901E3E"),
        Color(hex: "210F37"),
        Color(hex: "511D43"),
        Color(hex: "4B4376"),
        Color(hex: "9B3922"),
    ]
    
    static let names: [String] = [
        // Light pastels
        "Pastel Red",
        "Pastel Blue",
        "Pastel Yellow",
        "Pastel Pink",
        "Pastel Purple",
        "Pastel Green",
        "Pastel Orange",
        
        // Dunklere Farben
        "Warm Stone",
        "Dark Ash",
        "Warm Wood",
        "Crimson",
        "Deep Night",
        "Berry Wine",
        "Indigo Glow",
        "Ember Orange"
    ]

    static func name(for index: Int) -> String {
        guard names.indices.contains(index) else {
            return "Color \(index + 1)"
        }
        return names[index]
    }
}

extension Color {
    init(hex: String, alpha: Double = 1.0) {
        let hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()

        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)

        let r, g, b: Double
        switch hexString.count {
        case 6:
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8)  / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
        default:
            r = 0.5; g = 0.5; b = 0.5
        }
        self = Color(red: r, green: g, blue: b).opacity(alpha)
    }
}


