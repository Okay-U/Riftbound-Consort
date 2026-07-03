import SwiftUI

/// A palette entry carrying its precomputed luminance so views never need
/// UIKit color introspection (unavailable on Android).
struct PaletteColor: Hashable {
    let red: Double
    let green: Double
    let blue: Double
    let name: String

    init(hex: String, name: String) {
        let rgb = Self.parse(hex: hex)
        self.red = rgb.0
        self.green = rgb.1
        self.blue = rgb.2
        self.name = name
    }

    var color: Color { Color(red: red, green: green, blue: blue) }

    var isDark: Bool {
        (0.299 * red + 0.587 * green + 0.114 * blue) < 0.55
    }

    private static func parse(hex: String) -> (Double, Double, Double) {
        let hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
        guard hexString.count == 6, let rgb = UInt64(hexString, radix: 16) else {
            return (0.5, 0.5, 0.5)
        }
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        return (r, g, b)
    }
}

enum Palette {
    static let colors: [PaletteColor] = [
        PaletteColor(hex: "FF004A", name: "Pastel Red"),
        PaletteColor(hex: "4250FF", name: "Pastel Blue"),
        PaletteColor(hex: "FFC300", name: "Pastel Yellow"),
        PaletteColor(hex: "F897FF", name: "Pastel Pink"),
        PaletteColor(hex: "7415FE", name: "Pastel Purple"),
        PaletteColor(hex: "00D06B", name: "Pastel Green"),
        PaletteColor(hex: "FF5100", name: "Pastel Orange"),
        PaletteColor(hex: "948979", name: "Warm Stone"),
        PaletteColor(hex: "37353E", name: "Dark Ash"),
        PaletteColor(hex: "715A5A", name: "Warm Wood"),
        PaletteColor(hex: "901E3E", name: "Crimson"),
        PaletteColor(hex: "210F37", name: "Deep Night"),
        PaletteColor(hex: "511D43", name: "Berry Wine"),
        PaletteColor(hex: "4B4376", name: "Indigo Glow"),
        PaletteColor(hex: "9B3922", name: "Ember Orange"),
    ]

    static func entry(for index: Int) -> PaletteColor? {
        colors.indices.contains(index) ? colors[index] : nil
    }
}
