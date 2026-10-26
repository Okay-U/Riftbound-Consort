//
//  LegendPicture.swift
//  Riftbound Companiokay
//
//  Legend art on the board (Android `LegendPicture`, mock "1 · Art under a shade" with the middle "d"): the
//  picture behind a half and the shade that keeps its number readable. `LegendArt` names the picture.
//

import SwiftUI
import UIKit

/// One half's picture, fixed to the screen: it hangs from the board's middle and reaches 90pt past it with a
/// 70pt fade, and the territory line cuts it, so the leader uncovers more of theirs. The far half's is turned
/// round for the player across. Darkened to 72 % like the mock.
struct LegendPicture: View {
    let image: UIImage?
    /// The far half's: from the top of the screen to past the middle, upside down.
    let turned: Bool
    /// The board's middle and the line, from the top of the screen.
    let middle: CGFloat
    let line: CGFloat
    let screen: CGSize

    private static let reach: CGFloat = 90
    private static let fade: CGFloat = 70

    var body: some View {
        if let image {
            // Both halves the same height, so both pictures sit at the same scale.
            let box = max(middle, screen.height - middle) + Self.reach
            let top = turned ? middle + Self.reach - box : middle - Self.reach
            let soft = Self.fade / box
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: screen.width, height: box)
                .clipped()
                .colorMultiply(Color(white: 0.72))
                .saturation(1.05)
                .rotationEffect(.degrees(turned ? 180 : 0))
                .mask {
                    LinearGradient(
                        stops: turned
                            ? [.init(color: .black, location: 1 - soft), .init(color: .clear, location: 1)]
                            : [.init(color: .clear, location: 0), .init(color: .black, location: soft)],
                        startPoint: .top, endPoint: .bottom
                    )
                }
                // The far picture shows above the line, yours below it.
                .mask(alignment: .top) {
                    Rectangle().frame(height: box).offset(y: turned ? line - top - box : line - top)
                }
                .offset(y: top)
                .transition(.opacity)
        }
    }
}

/// Behind an art half's number: the mock's dark radial shade (an ellipse 75 % of the width and half the height
/// across), so the score reads on any picture.
struct LegendShade: View {
    var body: some View {
        GeometryReader { geo in
            // The ellipse's frame keeps its shape and is 8 % larger, so it covers the whole half.
            EllipticalGradient(
                stops: [
                    .init(color: .black.opacity(0.55), location: 0),
                    .init(color: .black.opacity(0.12), location: 0.72),
                    .init(color: .black.opacity(0.35), location: 1),
                ],
                center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5 / 1.08
            )
            .frame(width: geo.size.width * 1.5 * 1.08, height: geo.size.height * 1.08)
            .position(x: geo.size.width / 2, y: geo.size.height * 0.46)
        }
        .clipped()
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}
