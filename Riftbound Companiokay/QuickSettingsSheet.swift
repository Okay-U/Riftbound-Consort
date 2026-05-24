//
//  QuickSettingsSheet.swift
//  Riftbound Companiokay
//

import SwiftUI

struct QuickSettingsSheet: View {
    @EnvironmentObject var vm: ScoreboardViewModel
    @Environment(\.dismiss) private var dismiss

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
