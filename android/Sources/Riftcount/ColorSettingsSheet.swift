import SwiftUI

struct ColorSettingsSheet: View {
    let vm: ScoreboardViewModel
    let visibleSlots: [Int]
    @Binding var showSheet: Bool

    private let swatchesPerRow = 6

    // Palette chunked into fixed rows: LazyVGrid nested in a ScrollView is a
    // nested-lazy-scrollable conflict on Compose and blocks sheet scrolling.
    private var swatchRows: [[Int]] {
        stride(from: 0, to: Palette.colors.count, by: swatchesPerRow).map { start in
            Array(start..<min(start + swatchesPerRow, Palette.colors.count))
        }
    }

    var body: some View {
        // Header lives inside the ScrollView: a VStack-wrapped ScrollView
        // stops scrolling inside a Compose bottom sheet.
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SheetHeader(title: "Tile Colors") { showSheet = false }
                    ForEach(visibleSlots, id: \.self) { slot in
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Player \(slot + 1)")
                                .font(.headline)

                            Button {
                                vm.setColorIndex(-1, for: slot)
                            } label: {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.25))
                                        .frame(width: 28, height: 28)
                                    Text("Default")
                                    Spacer()
                                    if vm.colorIndex(for: slot) == -1 {
                                        Image(systemName: "checkmark")
                                    }
                                }
                                .padding(.vertical, 6)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(swatchRows, id: \.self) { row in
                                    HStack(spacing: 12) {
                                        ForEach(row, id: \.self) { index in
                                            let entry = Palette.colors[index]
                                            let selected = vm.colorIndex(for: slot) == index

                                            Button {
                                                vm.setColorIndex(index, for: slot)
                                            } label: {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(entry.color)
                                                        .frame(width: 48, height: 48)
                                                    if selected {
                                                        Image(systemName: "checkmark")
                                                            .foregroundStyle(.primary)
                                                    }
                                                }
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
    }
}
