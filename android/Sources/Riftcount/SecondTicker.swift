import SwiftUI

/// SkipUI's TimelineView is an unimplemented stub, so live clocks tick a
/// @State date once per second instead (view-owned @State is the reliable
/// recomposition channel on Compose).
struct SecondTicker<Content: View>: View {
    @ViewBuilder let content: (Date) -> Content
    @State var now = Date()

    var body: some View {
        content(now)
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    now = Date()
                }
            }
    }
}
