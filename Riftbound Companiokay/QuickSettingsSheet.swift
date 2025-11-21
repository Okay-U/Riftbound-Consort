//
//  QuickSettingsSheet.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 17.11.25.
//


import SwiftUI

struct QuickSettingsSheet: View {
    @Binding var ninePointGame: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Scoring") {
                    Toggle("9 Points", isOn: $ninePointGame)
                        .toggleStyle(.switch)
                }
            }
            .navigationTitle("Quick Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
