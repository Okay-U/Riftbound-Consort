//
//  SeatShade.swift
//  Riftbound Companiokay
//
//  Colour model C, the board's look (docs/IOS_REDESIGN.md "Score tile look", Android `SeatShade`): each field
//  is its seat colour brought to one depth, so every seat reads alike under white text. What the board draws
//  in the seat colour (the line, dice, WIN, badges) is lifted where that colour would not show on its field.
//  tools/check-scoreboard checks every player colour.
//

import Foundation
import SwiftUI

nonisolated enum SeatShade {
    /// OKLab lightness of a field: white is 7:1 or more on every player colour.
    static let field: Float = 0.44
    /// The seat colour on the board is at least this light: 3.3:1 or more on its own field.
    static let lifted: Float = 0.74

    /// `rgb` (linear sRGB) at the field's depth times `depth` (1.125 a leading seat, 0.75 Conquer's ink).
    /// Linear RGB times k³ is OKLab's L, a and b times k: the hue stays and the chroma falls with the
    /// lightness. Colours darker than a field keep their own depth.
    static func deep(_ rgb: SIMD3<Float>, depth: Float = 1) -> SIMD3<Float> {
        let l = lightness(rgb)
        guard l > 0 else { return rgb }
        let k = min(l, field) * depth / l
        return rgb * (k * k * k)
    }

    /// `rgb` mixed with white until it is `lifted` light; lighter colours stay as they are.
    static func lift(_ rgb: SIMD3<Float>) -> SIMD3<Float> {
        guard lightness(rgb) < lifted else { return rgb }
        var low: Float = 0
        var high: Float = 1
        for _ in 0..<16 {
            let t = (low + high) / 2
            if lightness(rgb + t * (1 - rgb)) < lifted { low = t } else { high = t }
        }
        return rgb + high * (1 - rgb)
    }

    /// OKLab L of linear sRGB (Björn Ottosson's matrices).
    static func lightness(_ c: SIMD3<Float>) -> Float {
        let l = cbrt(0.4122214708 * c.x + 0.5363325363 * c.y + 0.0514459929 * c.z)
        let m = cbrt(0.2119034982 * c.x + 0.6806995451 * c.y + 0.1073969566 * c.z)
        let s = cbrt(0.0883024619 * c.x + 0.2817188376 * c.y + 0.6299787005 * c.z)
        return 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
    }
}

extension Color {
    /// The field of this seat colour; `depth` 1.125 for a leading seat, 0.75 for Conquer's ink.
    func deep(_ depth: Float = 1) -> Color { mapped { SeatShade.deep($0, depth: depth) } }

    /// This seat colour drawn on its field.
    var lifted: Color { mapped(SeatShade.lift) }

    private func mapped(_ change: (SIMD3<Float>) -> SIMD3<Float>) -> Color {
        let c = resolve(in: EnvironmentValues())
        let rgb = change(SIMD3(c.linearRed, c.linearGreen, c.linearBlue))
        return Color(.sRGBLinear, red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z))
    }
}
