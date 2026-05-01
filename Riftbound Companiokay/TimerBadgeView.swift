//
//  TimerBadgeView.swift
//  Riftbound Companiokay
//

import SwiftUI

struct TimerBadgeView: View {
    @EnvironmentObject var timer: GameTimer

    var body: some View {
        HStack(spacing: 10) {
            Text(formattedTime)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.primary)

            Button {
                if timer.isRunning { timer.pause() } else { timer.start() }
            } label: {
                Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                    .imageScale(.small)
            }
            .buttonStyle(.bordered)

            Button { timer.reset() } label: {
                Image(systemName: "stop.fill")
                    .imageScale(.small)
            }
            .buttonStyle(.bordered)
        }
    }

    private var formattedTime: String {
        let total = Int(timer.elapsed)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
