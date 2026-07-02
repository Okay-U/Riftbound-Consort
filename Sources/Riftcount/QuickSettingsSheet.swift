import SwiftUI

struct QuickSettingsSheet: View {
    let vm: ScoreboardViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SheetHeader(title: "Quick Settings") { dismiss() }

            Text("PLAYERS")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            Picker("Number of Players", selection: Binding(
                get: { vm.playerCount },
                set: { vm.playerCount = $0 }
            )) {
                Text("2 Players").tag(2)
                Text("4 Players").tag(4)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            Spacer()
        }
    }
}
