import SwiftUI

struct QuickSettingsSheet: View {
    let vm: ScoreboardViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        // NavigationStack so the rules directory can push; the sheet has none
        // of its own, and a nested sheet on Compose is not worth the risk.
        NavigationStack {
            content
        }
    }

    var content: some View {
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

            Text("REFERENCE")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            NavigationLink {
                RulesView()
            } label: {
                HStack(spacing: 10) {
                    Text("Rules, FAQs & errata")
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}
