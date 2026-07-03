import SwiftUI

/// Report a match result to the Locator, ported from iOS. Best-of-1 = one
/// row; best-of-3 = three game rows, locked once decided at 2 wins.
/// Custom layout + SheetHeader (sheet-toolbar lessons).
struct ReportResultSheet: View {
    let match: ResolvedMyMatch
    let isBestOfThree: Bool
    let token: String
    var service: any LocatorService = RiftboundLocatorService()
    var onReported: () -> Void

    @Environment(\.dismiss) var dismiss
    @State var games: [GameOutcome]
    @State var submitting = false
    @State var errorMessage: String?
    @State var confirming = false

    enum GameOutcome: Equatable { case undecided, me, opponent, draw }

    init(match: ResolvedMyMatch,
         isBestOfThree: Bool,
         token: String,
         service: any LocatorService = RiftboundLocatorService(),
         onReported: @escaping () -> Void) {
        self.match = match
        self.isBestOfThree = isBestOfThree
        self.token = token
        self.service = service
        self.onReported = onReported
        _games = State(initialValue: Array(repeating: .undecided, count: isBestOfThree ? 3 : 1))
    }

    private var myWins: Int { games.filter { $0 == .me }.count }
    private var oppWins: Int { games.filter { $0 == .opponent }.count }
    private var draws: Int { games.filter { $0 == .draw }.count }
    private var canSubmit: Bool { (myWins + oppWins + draws) > 0 && !submitting }

    /// Best of 3 is over once a player reaches 2 game wins.
    private var matchDecided: Bool { isBestOfThree && (myWins >= 2 || oppWins >= 2) }

    /// Undecided rows lock once the match is decided; set rows stay editable.
    private func isRowLocked(_ index: Int) -> Bool {
        matchDecided && games[index] == .undecided
    }

    private var opponentName: String { match.opponent?.displayName ?? "Opponent" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(title: "Report result") { dismiss() }

                Text((isBestOfThree ? "Games (best of 3)" : "Result (best of 1)").uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)

                VStack(spacing: 12) {
                    ForEach(games.indices, id: \.self) { index in
                        gameRow(index)
                    }
                }
                .padding(.horizontal, 16)

                if isBestOfThree {
                    Text(matchDecided
                         ? "Match is decided at 2 game wins. The remaining game is disabled."
                         : "Set each game you played. You can report a partial result. Only the games you mark count.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }

                HStack {
                    Text("You report")
                    Spacer()
                    Text(summary).font(.body.weight(.semibold))
                }
                .padding(.horizontal, 16)

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                        .padding(.horizontal, 16)
                }

                Button {
                    confirming = true
                } label: {
                    HStack(spacing: 8) {
                        if submitting { ProgressView() }
                        else { Text("Submit").font(.system(size: 16, weight: .bold)) }
                    }
                    .foregroundStyle(EventsTheme.matchFillBottom)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(EventsTheme.green)
                    )
                    .opacity(canSubmit ? 1 : 0.5)
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .padding(.horizontal, 16)

                Spacer(minLength: 24)
            }
        }
        .background(EventsTheme.bg.ignoresSafeArea())
        .confirmationDialog("Submit this result?",
                            isPresented: $confirming,
                            titleVisibility: .visible) {
            Button("Submit \(summary)") { Task { await submit() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This reports to the tournament for \(match.me.displayName) vs \(opponentName). The scorekeeper can still adjust it.")
        }
    }

    private var summary: String {
        var parts = "You \(myWins) – \(oppWins) \(opponentName)"
        if draws > 0 { parts += " (\(draws) draw\(draws == 1 ? "" : "s"))" }
        return parts
    }

    // MARK: - Game row

    @ViewBuilder
    private func gameRow(_ index: Int) -> some View {
        let locked = isRowLocked(index)
        VStack(alignment: .leading, spacing: 8) {
            if isBestOfThree {
                Text("Game \(index + 1)").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                choice("You", .me, index, tint: .blue, locked: locked)
                choice("Draw", .draw, index, tint: .gray, locked: locked)
                choice(opponentName, .opponent, index, tint: .red, locked: locked)
            }
        }
        .opacity(locked ? 0.4 : 1)
    }

    @ViewBuilder
    private func choice(_ title: String, _ value: GameOutcome, _ index: Int, tint: Color, locked: Bool = false) -> some View {
        let selected = games[index] == value
        Button {
            games[index] = selected ? .undecided : value
        } label: {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selected ? tint.opacity(0.25) : Color.secondary.opacity(0.12))
                )
                .foregroundStyle(selected ? tint : Color.primary)
        }
        .buttonStyle(.plain)
        .disabled(locked)
    }

    // MARK: - Submit

    @MainActor
    private func submit() async {
        guard !submitting else { return }
        guard let opponent = match.opponent else {
            errorMessage = "No opponent to report against."
            return
        }
        submitting = true
        errorMessage = nil
        do {
            try await service.reportResult(matchID: match.matchID,
                                           token: token,
                                           myPMRID: match.me.id,
                                           myGamesWon: myWins,
                                           opponentPMRID: opponent.id,
                                           opponentGamesWon: oppWins,
                                           gamesDrawn: draws)
            onReported()
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Couldn't submit the result. Please try again."
        }
        submitting = false
    }
}
