//
//  RiftTheme.swift
//  Riftbound Companiokay
//
//  The redesign's identity (docs/IOS_REDESIGN.md, Android `Tokens.kt`): true black, green for you,
//  violet for the opponent, Big Shoulders Display numerals, Barlow text, one ease-out for every move.
//

import CoreText
import SwiftUI
import UIKit

enum RiftColor {
    static let ink = Color.white
    static let inkSoft = Color.white.opacity(0.72)
    static let inkMuted = Color.white.opacity(0.6)
    static let inkFaint = Color.white.opacity(0.45)
    static let you = Color(hex: "2BE38B")
    static let opponent = Color(hex: "A99BFF")
    static let gold = Color(hex: "FFC75E")
    static let danger = Color(hex: "FF6B61")
    static let card = Color(hex: "0D0D0D")
    static let sheet = Color(hex: "101010")
    static let hairline = Color.white.opacity(0.12)
}

enum RiftFont {
    /// Big Shoulders Display ships as one variable file (default instance Thin); the weight goes on its
    /// wght axis. Fixed size: it sets the big numbers and titles.
    static func display(_ size: CGFloat, weight: CGFloat = 900) -> Font {
        let wght = 0x7767_6874 // "wght"
        let descriptor = UIFontDescriptor(name: "BigShouldersDisplay-Thin", size: size)
            .addingAttributes([UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wght: weight]])
        return Font(UIFont(descriptor: descriptor, size: size))
    }

    /// Barlow at `size`, growing with Dynamic Type like `style`.
    static func text(_ size: CGFloat, _ weight: Font.Weight = .medium, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(barlow(weight), size: size, relativeTo: style)
    }

    private static func barlow(_ weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black: return "Barlow-Bold"
        case .semibold: return "Barlow-SemiBold"
        case .regular, .light, .thin, .ultraLight: return "Barlow-Regular"
        default: return "Barlow-Medium"
        }
    }
}

extension Animation {
    /// The mocks' exponential ease-out, cubic-bezier(.16, 1, .3, 1).
    static func rift(_ duration: TimeInterval) -> Animation {
        .timingCurve(0.16, 1, 0.3, 1, duration: duration)
    }
}
