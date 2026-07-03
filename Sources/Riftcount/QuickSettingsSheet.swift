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

            SegmentedControl(selection: Binding(
                get: { vm.playerCount },
                set: { vm.playerCount = $0 }
            ), options: [("2 Players", 2), ("4 Players", 4)])
            .padding(.horizontal, 16)

            Spacer()
        }
    }
}
