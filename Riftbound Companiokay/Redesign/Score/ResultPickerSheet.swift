//
//  ResultPickerSheet.swift
//  Riftbound Companiokay
//
//  "End the match" and "Set them yourself" (Android `ResultPickerDialog`, classic report sheet): what
//  happened in each game, also games nobody kept score of or an intentional draw. Games unlock in order
//  and lock after the deciding game. A native sheet (Liquid Glass on iOS 26).
//

import SwiftUI

struct ResultPickerSheet: View {
    @ObservedObject var c: ScoreController
    let colors: [Color]

    var body: some View {
        if let picker = c.picker {
            let me = picker.picks.filter { $0 == Seat.you }.count
            let them = picker.picks.filter { $0 == Seat.opponent }.count
            let accent = me == them ? Color.white : me > them ? colors[Seat.you] : colors[Seat.opponent]
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(picker.ending
                             ? "Pick what happened in each game, also games nobody kept score of or an intentional draw. Empty games are left out."
                             : "Pick the result of each game.")
                            .font(RiftFont.text(13, .regular))
                            .lineSpacing(4)
                            .foregroundStyle(.white.opacity(0.8))
                        ForEach(picker.picks.indices, id: \.self) { game in row(game, picker) }
                        HStack {
                            Text(c.shortName(Seat.you)).font(RiftFont.text(14, .semibold))
                            Spacer()
                            Text("\(me) – \(them)").font(RiftFont.display(22)).foregroundStyle(accent)
                            Spacer()
                            Text(c.shortName(Seat.opponent)).font(RiftFont.text(14, .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(16)
                }
                .navigationTitle(picker.ending ? "End the match" : "Set the game results")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { c.closePicker() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(picker.ending ? "End match" : "Done") { c.pickDone() }
                            .disabled(!picker.picks.contains { $0 != nil })
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func row(_ game: Int, _ picker: ResultPicker) -> some View {
        let locked = picker.locked(game)
        let choices: [(who: Int, label: String)] = [(Seat.you, c.shortName(Seat.you)), (Seat.draw, "Draw"), (Seat.opponent, c.shortName(Seat.opponent))]
        return VStack(alignment: .leading, spacing: 8) {
            Text("GAME \(game + 1)").caps(12, tracking: 0.06).foregroundStyle(.white.opacity(0.72))
            HStack(spacing: 6) {
                ForEach(choices, id: \.who) { choice in
                    let on = picker.picks[game] == choice.who
                    let fill = !on ? Color.white.opacity(0.06) : choice.who < 0 ? .white : colors[choice.who]
                    Pill(text: choice.label, height: 44, fullWidth: true, fill: fill, ink: on ? .black : .white, stroke: .white.opacity(0.18), enabled: !locked) {
                        c.choose(game, choice.who)
                    }
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .opacity(locked ? 0.35 : 1)
    }
}
