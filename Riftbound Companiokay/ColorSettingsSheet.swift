//
//  ColorSettingsSheet.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 02.11.25.
//


import SwiftUI

struct ColorSettingsSheet: View {
    @EnvironmentObject var vm: ScoreboardViewModel
    let visibleSlots: [Int]
    @Binding var showSheet: Bool

    private let grid = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    ForEach(visibleSlots, id: \.self) { slot in
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Player \(slot + 1)")
                                .font(.headline)

                            // Default / neutral
                            Button {
                                vm.setColorIndex(-1, for: slot)
                            } label: {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.thinMaterial)
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                        )
                                    Text("Default")
                                    Spacer()
                                    if vm.colorIndex(for: slot) == -1 {
                                        Image(systemName: "checkmark")
                                    }
                                }
                                .padding(.vertical, 6)
                            }

                            // Palette
                            LazyVGrid(columns: grid, spacing: 12) {
                                ForEach(Array(Palette.colors.enumerated()), id: \.0) { pair in
                                    let index = pair.0
                                    let color = pair.1
                                    let selected = vm.colorIndex(for: slot) == index

                                    Button {
                                        vm.setColorIndex(index, for: slot)
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(color)
                                                .frame(height: 44)
                                            if selected {
                                                Image(systemName: "checkmark")
                                                    .imageScale(.medium)
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("Tile Colors")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showSheet = false }
                }
            }
        }
    }
}
