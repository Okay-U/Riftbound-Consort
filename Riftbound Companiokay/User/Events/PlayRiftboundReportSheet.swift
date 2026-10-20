//
//  PlayRiftboundReportSheet.swift
//  Riftbound Companiokay
//
//  Report the player's own match result to PlayRiftbound. Same interaction as the
//  Locator sheet: best-of-1 = one row (You / Draw / Opponent), best-of-3 = one row
//  per game, locked once a side has two wins. Only games the player marks are sent.
//

import SwiftUI

struct PlayRiftboundReportSheet: View {
    let strip: PlayRiftboundStrip
    @State private var pairing: CompetePairing
    var onReported: () -> Void
    @State private var refreshing = true

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var browser: PlayRiftboundBrowser
    @State private var games: [GameOutcome]
    @State private var submitting = false
    @State private var errorMessage: String?
    @State private var confirming = false

    private let api = PlayRiftboundAPI()

    enum GameOutcome: Equatable { case undecided, me, opponent, draw }

    init(strip: PlayRiftboundStrip, pairing: CompetePairing, onReported: @escaping () -> Void) {
        self.strip = strip
        _pairing = State(initialValue: pairing)
        self.onReported = onReported
        _games = State(initialValue: Array(repeating: .undecided, count: max(1, min(pairing.bestOf, pairing.gameIDs.count))))
    }

    private var isSeries: Bool { games.count > 1 }
    private var myWins: Int { games.filter { $0 == .me }.count }
    private var oppWins: Int { games.filter { $0 == .opponent }.count }
    private var draws: Int { games.filter { $0 == .draw }.count }
    private var winsNeeded: Int { games.count / 2 + 1 }
    private var matchDecided: Bool { isSeries && (myWins >= winsNeeded || oppWins >= winsNeeded) }
    private var canSubmit: Bool { (myWins + oppWins + draws) > 0 && !submitting && !refreshing && !pairing.isComplete }
    private var opponentName: String { pairing.opponentName ?? "Opponent" }

    private func isRowLocked(_ index: Int) -> Bool { matchDecided && games[index] == .undecided }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(games.indices, id: \.self) { index in gameRow(index) }
                } header: {
                    Text(isSeries ? "Games (best of \(games.count))" : "Result (best of 1)")
                } footer: {
                    if isSeries {
                        Text(matchDecided
                             ? "Match is decided at \(winsNeeded) game wins. The remaining game is disabled."
                             : "Set each game you played. Only the games you mark are sent.")
                    }
                }
                Section {
                    HStack {
                        Text("You report")
                        Spacer()
                        if refreshing { ProgressView() } else { Text(summary).font(.body.weight(.semibold)) }
                    }
                    if pairing.isComplete {
                        Label("This match already has a result on PlayRiftbound.", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green).font(.footnote)
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("Report result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if submitting { ProgressView() } else { Button("Submit") { confirming = true }.disabled(!canSubmit) }
                }
            }
            .task { await refreshPairing() }
            .confirmationDialog("Submit this result?", isPresented: $confirming, titleVisibility: .visible) {
                Button("Submit \(summary)") { Task { await submit() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This reports your result for round \(pairing.roundNumber) to PlayRiftbound. The organizer can still adjust it.")
            }
        }
    }

    private var summary: String {
        var text = "You \(myWins) – \(oppWins) \(opponentName)"
        if draws > 0 { text += " (\(draws) draw\(draws == 1 ? "" : "s"))" }
        return text
    }

    @ViewBuilder
    private func gameRow(_ index: Int) -> some View {
        let locked = isRowLocked(index)
        VStack(alignment: .leading, spacing: 8) {
            if isSeries { Text("Game \(index + 1)").font(.caption).foregroundStyle(.secondary) }
            HStack(spacing: 8) {
                choice("You", .me, index, tint: .blue, locked: locked)
                choice("Draw", .draw, index, tint: .gray, locked: locked)
                choice(opponentName, .opponent, index, tint: .red, locked: locked)
            }
        }
        .padding(.vertical, 4)
        .opacity(locked ? 0.4 : 1)
    }

    @ViewBuilder
    private func choice(_ title: String, _ value: GameOutcome, _ index: Int, tint: Color, locked: Bool) -> some View {
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
        .disabled(locked)
    }

    /// Pairings change (re-pairs, results entered on the site), so the sheet works from the
    /// latest round data: fetched when it opens and again right before sending.
    /// Returns false when the player's match changed under the open sheet (re-pair, next
    /// round): the marks are cleared so they never go to the wrong match. A failed fetch
    /// keeps the pairing the sheet opened with, which came from a fetch moments earlier.
    @MainActor
    @discardableResult
    private func refreshPairing() async -> Bool {
        refreshing = true
        defer { refreshing = false }
        guard let credentials = try? await PlayRiftboundSession.validCredentials(refreshingVia: browser),
              let gameName = credentials.gameName,
              let tournament = try? await api.tournament(id: strip.tournamentID, credentials: credentials),
              let playerID = tournament.playerID(gameName: gameName, tagLine: credentials.tagLine),
              let fresh = CompetePairing.resolve(in: tournament, playerID: playerID) else { return true }
        let sameMatch = fresh.matchID == pairing.matchID && fresh.gameIDs == pairing.gameIDs
        if !sameMatch {
            games = Array(repeating: .undecided, count: max(1, min(fresh.bestOf, fresh.gameIDs.count)))
        }
        pairing = fresh
        return sameMatch
    }

    @MainActor
    private func submit() async {
        guard !submitting else { return }
        submitting = true
        errorMessage = nil
        defer { submitting = false }
        guard await refreshPairing() else {
            errorMessage = "Your pairing changed. Check the games and submit again."
            return
        }
        if pairing.isComplete {
            // Already reported (by us on a lost response, by the opponent or the organizer).
            onReported()
            dismiss()
            return
        }
        guard let me = pairing.myParticipantID, let opp = pairing.opponentParticipantID else {
            errorMessage = "Couldn't find your match in the current round."
            return
        }

        let results: [PlayRiftboundAPI.GameResult] = zip(pairing.gameIDs, games).compactMap { gameID, outcome in
            switch outcome {
            case .undecided: return nil
            case .me: return .init(gameId: gameID, draw: false, winnerParticipantId: me)
            case .opponent: return .init(gameId: gameID, draw: false, winnerParticipantId: opp)
            case .draw: return .init(gameId: gameID, draw: true, winnerParticipantId: nil)
            }
        }
        guard !results.isEmpty else {
            errorMessage = "Mark at least one game."
            return
        }
        do {
            guard let credentials = try await PlayRiftboundSession.validCredentials(refreshingVia: browser) else {
                errorMessage = PlayRiftboundError.notSignedIn.errorDescription
                return
            }
            do {
                try await api.submitGameResults(tournamentID: strip.tournamentID, games: results, credentials: credentials)
            } catch PlayRiftboundError.sessionExpired {
                // The site renews its token on a page load; do that once and retry.
                let renewed = try await PlayRiftboundSession.renewed(via: browser)
                try await api.submitGameResults(tournamentID: strip.tournamentID, games: results, credentials: renewed)
            }
            onReported()
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't submit the result. Please try again."
        }
    }
}
