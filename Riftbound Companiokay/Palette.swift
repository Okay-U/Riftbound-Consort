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
        Color(red: 0.98, green: 0.80, blue: 0.40), // Pastell-Gelb
        Color(red: 0.98, green: 0.60, blue: 0.60), // Pastell-Rot
        Color(red: 0.75, green: 0.84, blue: 0.98), // Pastell-Blau
        Color(red: 0.74, green: 0.86, blue: 0.74), // Pastell-Grün
        Color(red: 0.88, green: 0.75, blue: 0.95), // Pastell-Lila
        Color(red: 0.96, green: 0.82, blue: 0.90), // Pastell-Rosa
        Color(red: 0.83, green: 0.90, blue: 0.96), // Pastell-Himmel
        Color(red: 0.95, green: 0.86, blue: 0.70), // Pastell-Sand
        
        // Dunklere Farben
        Color(hex: "948979"),
        Color(hex: "37353E"),
        Color(hex: "393E46"),
        Color(hex: "44444E"),
        Color(hex: "715A5A"),
        Color(hex: "901E3E"),
        Color(hex: "210F37"),
        Color(hex: "511D43"),
        Color(hex: "4F1C51"),
        Color(hex: "4B4376"),
        Color(hex: "481E14"),
        Color(hex: "9B3922"),
    ]
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


