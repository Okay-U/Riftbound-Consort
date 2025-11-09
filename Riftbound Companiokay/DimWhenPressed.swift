//
//  DimWhenPressed.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 02.11.25.
//


import SwiftUI

struct DimWhenPressed: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                Color.black.opacity(configuration.isPressed ? 0.16 : 0)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
