//
//  RiftInputs.swift
//  Riftbound Companiokay
//
//  The redesign's inputs (Android `ui/common`, `FilterSheet.kt`): the search field with its green focus
//  ring, the two-thumb range slider, the count stepper, chips that wrap.
//

import SwiftUI

/// Lays its children out in rows, wrapping to the next row when one is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                y += row + spacing
                x = 0
                row = 0
            }
            x += size.width + spacing
            row = max(row, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, width), height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += row + spacing
                x = bounds.minX
                row = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            row = max(row, size.height)
        }
    }
}

/// The mocks' search field: a pill that rings green while typing, × to clear.
struct RiftSearchField: View {
    @Binding var text: String
    var placeholder = "Search cards"
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.5)))
                .font(RiftFont.text(16))
                .foregroundStyle(.white)
                .tint(RiftColor.you)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($focused)
            if !text.isEmpty {
                RoundIcon(symbol: "xmark", label: "Clear search", size: 34) { text = "" }
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .frame(height: 50)
        .background(.white.opacity(0.07), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.12).mix(with: RiftColor.you.opacity(0.6), by: focused ? 1 : 0), lineWidth: 1))
        .background(Capsule().fill(RiftColor.you.opacity(focused ? 0.12 : 0)).padding(-4))
        .animation(.easeInOut(duration: 0.3), value: focused)
        .contentShape(Capsule())
        .onTapGesture { focused = true }
    }
}

/// Two-thumb slider on whole numbers from 0 to `cap`; the thumb nearer the finger moves, a tap jumps it there.
/// A maximum at the cap means "no limit".
struct RangeSlider: View {
    let label: String
    @Binding var lower: Int
    @Binding var upper: Int
    let cap: Int
    /// Which thumb the finger holds: 0 lower, 1 upper; nil until the first move decides between stacked thumbs.
    @State private var thumb: Int?
    @State private var dragging = false

    private var full: Bool { lower == 0 && upper == cap }
    private var valueText: String {
        if full { return "Any" }
        return lower == upper ? "\(lower)" : "\(lower) – \(upper)"
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label.uppercased()).caps(11).foregroundStyle(.white.opacity(0.66))
                Spacer()
                Text(valueText).font(RiftFont.display(16, weight: 800)).tracking(1).foregroundStyle(.white)
            }
            GeometryReader { geo in
                let unit = geo.size.width / CGFloat(cap)
                let x0 = CGFloat(lower) * unit
                let x1 = CGFloat(upper) * unit
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.14)).frame(height: 4)
                    Capsule().fill(RiftColor.you.opacity(0.22)).frame(width: max(0, x1 - x0), height: 10).offset(x: x0)
                    Capsule().fill(RiftColor.you).frame(width: max(0, x1 - x0), height: 4).offset(x: x0)
                    ForEach(0...cap, id: \.self) { i in
                        let lit = !full && i >= lower && i <= upper
                        Circle().fill(lit ? RiftColor.you : .white.opacity(0.28)).frame(width: 6, height: 6)
                            .offset(x: CGFloat(i) * unit - 3)
                    }
                    ForEach(0..<2, id: \.self) { i in
                        let x = i == 0 ? x0 : x1
                        Circle()
                            .fill(.white)
                            .frame(width: 28, height: 28)
                            .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
                            .background(Circle().fill(RiftColor.you.opacity(0.25)).padding(-4))
                            .offset(x: x - 14)
                    }
                }
                .frame(height: 34)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let value = drag.location.x / unit
                            if !dragging {
                                dragging = true
                                let start = drag.startLocation.x / unit
                                // Thumbs on one value: the first move decides which one the finger takes.
                                if lower == upper && abs(start - CGFloat(lower)) < 0.6 {
                                    thumb = nil
                                } else {
                                    thumb = abs(start - CGFloat(lower)) <= abs(start - CGFloat(upper)) ? 0 : 1
                                }
                            }
                            if thumb == nil, abs(drag.translation.width) > 2 { thumb = drag.translation.width < 0 ? 0 : 1 }
                            move(to: Int(value.rounded()))
                        }
                        .onEnded { _ in
                            dragging = false
                            thumb = nil
                        }
                )
            }
            .frame(height: 34)
            .padding(.horizontal, 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(valueText)
        .accessibilityRepresentation {
            VStack {
                Stepper("\(label) minimum \(lower)", value: $lower, in: 0...upper)
                Stepper("\(label) maximum \(upper)", value: $upper, in: lower...cap)
            }
        }
    }

    private func move(to raw: Int) {
        switch thumb {
        case 0: lower = min(max(0, raw), upper)
        case 1: upper = min(max(raw, lower), cap)
        default: break
        }
    }
}

/// − count +, the mocks' stepper; `canAdd` false greys the plus.
struct CountStepper: View {
    let count: Int
    var noun = "copy"
    var canAdd = true
    let onMinus: () -> Void
    let onPlus: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            RoundIcon(symbol: "minus", label: "One \(noun) less", size: 34, enabled: count > 0, action: onMinus)
            Text("\(count)")
                .font(RiftFont.display(18))
                .foregroundStyle(.white)
                .frame(minWidth: 26)
                .contentTransition(.numericText(value: Double(count)))
                .animation(.rift(0.4), value: count)
            RoundIcon(symbol: "plus", label: "One \(noun) more", tint: canAdd ? .black : .white, fill: canAdd ? RiftColor.you : .white.opacity(0.1), size: 34, enabled: canAdd, action: onPlus)
        }
    }
}

/// The mocks' choice chip: green and glowing when on; an optional gem in front.
struct ToggleChip: View {
    let label: String
    let on: Bool
    var gem: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let gem { Gem(color: gem) }
                Text(label).font(RiftFont.text(13, .semibold)).foregroundStyle(on ? Color.black : .white)
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(on ? RiftColor.you : .white.opacity(0.05), in: Capsule())
            .overlay(Capsule().stroke(on ? RiftColor.you : .white.opacity(0.16), lineWidth: 1))
            .shadow(color: RiftColor.you.opacity(on ? 0.45 : 0), radius: 8)
            .contentShape(Capsule())
        }
        .buttonStyle(PressScale(scale: 0.95))
        .animation(.easeInOut(duration: 0.26), value: on)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
