//
//  QuickSettingsSheet.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 17.11.25.
//


import SwiftUI

struct QuickSettingsSheet: View {
    @Binding var targetScore: Int      // kommt jetzt als Int-Binding rein
    @Environment(\.dismiss) private var dismiss

    private let allowedScores = Array(8...12) // 8–12, bei Bedarf ändern

    var body: some View {
        NavigationStack {
            Form {
                Section("Scoring") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Winning Score")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Picker("Winning Score", selection: $targetScore) {
                            ForEach(allowedScores, id: \.self) { value in
                                Text("\(value)")
                                    .tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
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
