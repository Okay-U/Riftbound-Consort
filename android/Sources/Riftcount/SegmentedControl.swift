import SwiftUI

/// iOS-style segmented control. Replaces .pickerStyle(.segmented), which
/// Compose renders as Material SegmentedButton (outlined pills + checkmark)
/// and reads as foreign next to the rest of the app: dark inset track,
/// elevated thumb behind the selected segment, no checkmark.
struct SegmentedControl<T: Hashable>: View {
    @Binding var selection: T
    let options: [(label: String, value: T)]

    private let trackColor = Color.white.opacity(0.09)
    private let thumbColor = Color(red: 0.39, green: 0.39, blue: 0.42)

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { i in
                segment(options[i].label, options[i].value)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(trackColor)
        )
    }

    private func segment(_ label: String, _ value: T) -> some View {
        let selected = selection == value
        return Button {
            guard selection != value else { return }
            Haptics.selection()
            withAnimation(.easeInOut(duration: 0.15)) { selection = value }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? .white : .secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(selected ? thumbColor : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}
