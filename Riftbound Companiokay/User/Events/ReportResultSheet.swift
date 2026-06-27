//
//  ReportResultSheet.swift
//  Riftbound Companiokay
//
//  Report a match result to the Locator. Best-of-1 = one row (You/Draw/Opp).
//  Best-of-3 = three game rows; partial reports are allowed (the server counts
//  game wins, e.g. just a game-1 win = a 1–0). Sends the PMR-id payload.
//

import SwiftUI

struct ReportResultSheet: View {
    let match: ResolvedMyMatch
    let isBestOfThree: Bool
    let token: String
    var service: any LocatorService = RiftboundLocatorService()
    var onReported: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var games: [GameOutcome]
    @State private var submitting = false
    @State private var errorMessage: String?
    @State private var confirming = false

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

    private var opponentName: String { match.opponent?.displayName ?? "Opponent" }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(games.indices, id: \.self) { index in
                        gameRow(index)
                    }
                } header: {
                    Text(isBestOfThree ? "Games (best of 3)" : "Result (best of 1)")
                } footer: {
                    if isBestOfThree {
                        Text("Set each game you played. You can report a partial result. Only the games you mark count.")
                    }
                }

                Section {
                    HStack {
                        Text("You report")
                        Spacer()
                        Text(summary).font(.body.weight(.semibold))
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("Report result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if submitting { ProgressView() }
                    else { Button("Submit") { confirming = true }.disabled(!canSubmit) }
                }
            }
            .confirmationDialog("Submit this result?",
                                isPresented: $confirming,
                                titleVisibility: .visible) {
                Button("Submit \(summary)") { Task { await submit() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This reports to the tournament for \(match.me.displayName) vs \(opponentName). The scorekeeper can still adjust it.")
            }
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
        VStack(alignment: .leading, spacing: 8) {
            if isBestOfThree {
                Text("Game \(index + 1)").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                choice("You", .me, index, tint: .blue)
                choice("Draw", .draw, index, tint: .gray)
                choice(opponentName, .opponent, index, tint: .red)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func choice(_ title: String, _ value: GameOutcome, _ index: Int, tint: Color) -> some View {
        let selected = games[index] == value
        Button {
            games[index] = selected ? .undecided : value
        } label: {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selected ? tint.opacity(0.25) : Color.secondary.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(selected ? tint : .primary)
        }
        .buttonStyle(.plain)
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
