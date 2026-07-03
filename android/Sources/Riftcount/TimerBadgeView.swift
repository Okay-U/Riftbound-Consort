import SwiftUI

/// Timer pill, ported from iOS. Pause/stop glyphs drawn by hand
/// (pause.fill / stop.fill are not in SkipUI's symbol map).
struct TimerBadgeView: View {
    @Environment(GameTimer.self) var timer

    var body: some View {
        HStack(spacing: 10) {
            Text(formattedTime)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)

            Button {
                if timer.isRunning { timer.pause() } else { timer.start() }
            } label: {
                Group {
                    if timer.isRunning {
                        HStack(spacing: 3) {
                            Capsule().frame(width: 3.5, height: 12)
                            Capsule().frame(width: 3.5, height: 12)
                        }
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13))
                    }
                }
                .foregroundStyle(.primary)
                .frame(width: 32, height: 28)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)

            Button {
                timer.reset()
            } label: {
                RoundedRectangle(cornerRadius: 2.5)
                    .frame(width: 11, height: 11)
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 28)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
        }
    }

    private var formattedTime: String {
        let total = Int(timer.elapsed)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
