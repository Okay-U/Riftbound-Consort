//
//  QuickSettingsSheet.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 17.11.25.
//


import SwiftUI

struct QuickSettingsSheet: View {
    @Binding var targetScore: Int
    @EnvironmentObject var vm: ScoreboardViewModel
    @Environment(\.dismiss) private var dismiss

    private let allowedScores = Array(8...12)

    var body: some View {
        NavigationStack {
            Form {
                Section("Players") {
                    Picker("Number of Players", selection: Binding(
                        get: { vm.playerCount },
                        set: { vm.playerCount = $0 }
                    )) {
                        Text("2 Players").tag(2)
                        Text("4 Players").tag(4)
                    }
                    .pickerStyle(.segmented)
                }

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
