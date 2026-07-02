import SwiftUI

/// Live event screen ("Arena"), ported from iOS: overview card, register/drop,
/// your-match (green), decklist card, "Can I draw?" outlook, pairings (crown
/// winners, your table highlighted), standings.
/// Port notes: EventKit calendar-add omitted (no Android bridge); Android
/// system back replaces the custom back button; drawn crown glyph; opponent
/// ELO badge arrives with stage 3e.
struct EventDetailView: View {
    let eventID: Int
    var myAlias: String? = nil
    var service: any LocatorService = RiftboundLocatorService()

    @Environment(AuthSession.self) var session
    @Environment(MatchModeStore.self) var matchMode
    @AppStorage("batterySaver") var batterySaver = false
    @AppStorage("currentTab") var currentTab: String = "score"
    @Environment(\.dismiss) var dismiss
    @State var state: LoadState = .idle
    @State var reporting: ResolvedMyMatch?
    @State var showReport = false
    @State var registered = false
    @State var registering = false
    @State var registerError: String?
    @State var confirmingRegister = false
    @State var myDeck: LocatorDeckSubmission?

    enum LoadState {
        case idle, loading
        case loaded(Loaded)
        case failed(String)
    }

    struct Loaded {
        let event: LocatorEvent
        let matches: [LocatorMatch]
        let standings: [LocatorStanding]
        let myMatch: ResolvedMyMatch?
        let myName: String?
    }

    var body: some View {
        ScrollView {
            switch state {
            case .idle, .loading:
                ProgressView("Loading event…").frame(maxWidth: .infinity, minHeight: 400)
            case .failed(let message):
                failed(message)
            case .loaded(let data):
                content(data)
            }
        }
        .background(EventsTheme.bg.ignoresSafeArea())
        .navigationTitle("Event")
        .refreshable { await load() }
        .task { if case .idle = state { await load() } }
        .sheet(isPresented: $showReport) {
            if let reporting {
                ReportResultSheet(match: reporting,
                                  isBestOfThree: currentEvent?.isBestOfThree ?? true,
                                  token: session.token ?? "",
                                  onReported: { Task { await load() } })
            }
        }
    }

    private var currentEvent: LocatorEvent? {
        if case .loaded(let data) = state { return data.event }
        return nil
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ data: Loaded) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            overviewCard(data.event)

            if data.myMatch == nil, session.token != nil, !data.event.isFinished,
               registered || data.event.isOpenForRegistration {
                registerCard(data.event)
            }

            if let mine = data.myMatch {
                yourMatchCard(mine, roundLabel: data.event.currentRoundLabel)
            }

            if registered, data.event.usesDecklists { deckCard(data.event) }

            cutOutlookCard(data)

            if !data.matches.isEmpty {
                let label = data.event.currentRoundLabel.map { " · \($0)" } ?? ""
                VStack(alignment: .leading, spacing: 11) {
                    EventsSectionHeader("Pairings" + label) {
                        Image(systemName: "person.fill")
                    }
                    VStack(spacing: 8) { ForEach(data.matches) { pairingRow($0, myName: data.myName) } }
                }
            }

            if !data.standings.isEmpty {
                VStack(alignment: .leading, spacing: 11) {
                    EventsSectionHeader("Standings") {
                        Image(systemName: "list.bullet")
                    }
                    standingsCard(data)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .confirmationDialog("Register for this event?",
                            isPresented: $confirmingRegister, titleVisibility: .visible) {
            Button("Register · pay in person") { Task { await register(data.event) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll be signed up on the Locator. Any entry fee is paid in person at the store.")
        }
    }

    // MARK: - Register card

    @ViewBuilder
    private func registerCard(_ event: LocatorEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    if registered {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(registered ? "You're registered" : "Registration open")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(EventsTheme.green)
                Spacer()
                Text(priceLine(event))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(EventsTheme.textSecondary)
            }

            if let registerError {
                Text(registerError).font(.system(size: 12)).foregroundStyle(.red)
            }

            if registered {
                Button { Task { await drop(event) } } label: {
                    HStack(spacing: 6) {
                        if registering { ProgressView() }
                        else { Image(systemName: "xmark"); Text("Drop out") }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(EventsTheme.textSecondary)
                    .frame(maxWidth: .infinity).frame(height: 42)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(EventsTheme.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain).disabled(registering)
            } else if event.requiresOnlinePayment {
                Text("This event takes payment online. Register and pay on the Locator website.")
                    .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
                if let url = event.webURL {
                    Link(destination: url) {
                        greenCTA("Open on website")
                    }
                }
            } else {
                Button { confirmingRegister = true } label: {
                    if registering {
                        HStack { Spacer(); ProgressView(); Spacer() }
                            .frame(height: 42)
                    } else {
                        greenCTA("Register · pay in person")
                    }
                }
                .buttonStyle(.plain).disabled(registering)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .greenGradientBorder(radius: 17)
    }

    private func greenCTA(_ title: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
            Image(systemName: "arrow.forward")
        }
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(EventsTheme.matchFillBottom)
        .frame(maxWidth: .infinity).frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(EventsTheme.green)
        )
    }

    private func priceLine(_ event: LocatorEvent) -> String {
        if event.priceText == "Free" { return "Free" }
        return event.requiresOnlinePayment ? "\(event.priceText) · online" : "\(event.priceText) · pay in person"
    }

    // MARK: - Your decklist

    @ViewBuilder
    private func deckCard(_ event: LocatorEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            EventsSectionHeader("Your decklist") {
                Image(systemName: "list.bullet")
            }
            if let deck = myDeck {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(EventsTheme.green)
                    Text(deck.deckName ?? "Submitted")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                    Spacer()
                }
            } else {
                Text("No decklist submitted yet.")
                    .font(.system(size: 14)).foregroundStyle(EventsTheme.textSecondary)
            }
            if let url = event.webURL {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text(myDeck == nil ? "Submit on website" : "View or edit on website")
                        Image(systemName: "arrow.forward")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(EventsTheme.green)
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .eventsCard(radius: 18)
    }

    @MainActor
    private func register(_ event: LocatorEvent) async {
        guard !registering, let token = session.token else { return }
        registering = true; registerError = nil
        defer { registering = false }
        do { try await service.register(eventID: event.id, token: token); registered = true }
        catch {
            if session.signOutIfUnauthorized(error) { dismiss(); return }
            registerError = (error as? LocalizedError)?.errorDescription ?? "Couldn't register. Try again."
        }
    }

    @MainActor
    private func drop(_ event: LocatorEvent) async {
        guard !registering, let token = session.token else { return }
        registering = true; registerError = nil
        defer { registering = false }
        do { try await service.drop(eventID: event.id, token: token); registered = false }
        catch {
            if session.signOutIfUnauthorized(error) { dismiss(); return }
            registerError = (error as? LocalizedError)?.errorDescription ?? "Couldn't drop. Try again."
        }
    }

    // MARK: - Overview card

    @ViewBuilder
    private func overviewCard(_ event: LocatorEvent) -> some View {
        let live = (event.displayStatus ?? "").lowercased().contains("progress")
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(event.name)
                    .font(.system(size: 21, weight: .heavy))
                    .foregroundStyle(.white).lineLimit(2)
                Spacer(minLength: 8)
                if live { LiveBadge(pulsing: true) }
            }
            if let address = event.fullAddress, !address.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "location")
                    Text(address).lineLimit(1)
                }
                .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
            }
            roundProgress(event)

            if let url = event.webURL {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                        Text("View on Locator")
                        Image(systemName: "arrow.forward")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(EventsTheme.green)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(alignment: .topTrailing) {
            if !batterySaver {
                RadialGradient(colors: [EventsTheme.green.opacity(0.28), Color.clear],
                               center: .topTrailing, startRadius: 0, endRadius: 220)
                    .allowsHitTesting(false)
            }
        }
        .background(
            LinearGradient(colors: [EventsTheme.overviewFillTop, EventsTheme.overviewFillBottom],
                           startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(EventsTheme.hairline, lineWidth: 1))
    }

    @ViewBuilder
    private func roundProgress(_ event: LocatorEvent) -> some View {
        let meta = "\(event.isBestOfThree ? "Best of 3" : "Best of 1") · \(event.startingPlayerCount ?? 0) players"
        VStack(spacing: 8) {
            HStack {
                Text(event.currentRoundLabel ?? (event.isFinished ? "Complete" : "—"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(event.isFinished ? EventsTheme.textSecondary : EventsTheme.green)
                Spacer()
                Text(meta).font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
            }
            if let total = event.swissRoundsTotal, total > 0, !event.isFinished {
                HStack(spacing: 5) {
                    ForEach(0..<total, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(i < event.swissRoundsCompleted ? EventsTheme.green : Color.white.opacity(0.1))
                            .frame(height: 5)
                    }
                }
            }
        }
    }

    // MARK: - Your match

    @ViewBuilder
    private func yourMatchCard(_ match: ResolvedMyMatch, roundLabel: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.fill")
                    Text("Your match" + (roundLabel.map { " · \($0)" } ?? ""))
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(EventsTheme.green)
                Spacer()
                Text(match.isComplete ? "Reported" : "In progress")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(EventsTheme.greenSoft))
                    .foregroundStyle(EventsTheme.green)
            }

            if match.isBye {
                Text("Bye. You advance this round.")
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
            } else {
                Text("Table \(match.tableNumber.map(String.init) ?? "—")")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)

                if match.isMultiplayer {
                    podMatchList(match)
                } else {
                    matchVS(match)
                }

                if match.isComplete {
                    Rectangle().fill(EventsTheme.hairline).frame(height: 1)
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                        Text("Result reported. Ask the scorekeeper to change it.")
                    }
                    .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
                } else if match.isMultiplayer {
                    // Our reporter is 1v1 only — multiplayer pods report on the website.
                    if let url = currentEvent?.webURL {
                        Link(destination: url) {
                            greenCTA("Report on website")
                        }
                    }
                } else if match.opponent != nil, session.token != nil {
                    Button {
                        reporting = match
                        showReport = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                            Text("Report result")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(EventsTheme.matchFillBottom)
                        .frame(maxWidth: .infinity).frame(height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(EventsTheme.green)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if !match.isMultiplayer, match.opponent != nil, currentEvent?.isFinished == false {
                    playOnScoreboardButton(match)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .greenGradientBorder(radius: 17)
    }

    @ViewBuilder
    private func playOnScoreboardButton(_ match: ResolvedMyMatch) -> some View {
        Button { startOnScoreboard(match) } label: {
            HStack(spacing: 6) {
                Image(systemName: "play.fill")
                Text("Play on Scoreboard")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(EventsTheme.green)
            .frame(maxWidth: .infinity).frame(height: 42)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(EventsTheme.green.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func startOnScoreboard(_ match: ResolvedMyMatch) {
        guard let event = currentEvent else { return }
        matchMode.setManual(ActiveTournamentMatch(
            eventID: eventID,
            match: match,
            isBestOfThree: event.isBestOfThree,
            eventName: event.name,
            roundLabel: event.currentRoundLabel
        ))
        currentTab = "score"
    }

    private func matchVS(_ match: ResolvedMyMatch) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(match.me.displayName).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text("you · \(match.me.record)").font(.system(size: 12)).foregroundStyle(EventsTheme.green)
            }
            Spacer()
            Text("VS").font(.system(size: 12, weight: .bold)).foregroundStyle(EventsTheme.green)
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(match.opponent?.displayName ?? "TBD").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text(match.opponent?.record ?? "").font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
            }
        }
    }

    /// Multiplayer pod: list you + every opponent at the table.
    @ViewBuilder
    private func podMatchList(_ match: ResolvedMyMatch) -> some View {
        VStack(spacing: 6) {
            podMatchRow(name: match.me.displayName, record: match.me.record, mine: true)
            ForEach(match.opponents) { opp in
                podMatchRow(name: opp.displayName, record: opp.record, mine: false)
            }
        }
    }

    private func podMatchRow(name: String, record: String, mine: Bool) -> some View {
        HStack {
            Text(mine ? "\(name) · you" : name)
                .font(.system(size: 15, weight: mine ? .bold : .semibold))
                .foregroundStyle(mine ? EventsTheme.green : Color.white).lineLimit(1)
            Spacer()
            Text(record).font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
        }
    }

    // MARK: - Can I draw?

    @ViewBuilder
    private func cutOutlookCard(_ data: Loaded) -> some View {
        if data.event.hasTopCut,
           let cut = data.event.resolvedCutSize,
           let roundsLeft = data.event.swissRoundsLeft, roundsLeft >= 1,
           let myName = data.myName,
           let mine = data.standings.first(where: { $0.tvDisplayName == myName }) {

            let myPoints = mine.totalMatchPoints ?? 0
            let others = data.standings.filter { $0.tvDisplayName != myName }.map { $0.totalMatchPoints ?? 0 }
            let outlook = DrawCalc.outlook(myPoints: myPoints, others: others, cut: cut, roundsLeft: roundsLeft)
            let suffix = roundsLeft == 1 ? "" : " out"

            VStack(alignment: .leading, spacing: 12) {
                EventsSectionHeader("Can I draw?") {
                    FilterGlyph(active: false)
                }
                Text("Top \(cut) · \(roundsLeft) round\(roundsLeft == 1 ? "" : "s") left · you have \(myPoints) pts")
                    .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
                outlookRow("Win" + suffix, outlook.win)
                outlookRow("Draw" + suffix, outlook.draw)
                outlookRow("Lose" + suffix, outlook.lose)
                Text("\"Locked in\" is guaranteed regardless of other results. \"Bubble\" depends on other matches and tiebreakers.")
                    .font(.system(size: 11)).foregroundStyle(EventsTheme.textTertiary)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .eventsCard(radius: 18)
        }
    }

    private func outlookRow(_ title: String, _ chance: CutChance) -> some View {
        HStack {
            Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
            Spacer()
            chanceBadge(chance)
        }
    }

    private func chanceBadge(_ chance: CutChance) -> some View {
        let color: Color
        let bg: Color
        switch chance {
        case .locked: color = EventsTheme.green; bg = EventsTheme.greenSoft
        case .bubble: color = EventsTheme.textSecondary; bg = Color.white.opacity(0.08)
        case .out: color = .red; bg = Color.red.opacity(0.16)
        }
        return HStack(spacing: 5) {
            switch chance {
            case .locked: Image(systemName: "checkmark.circle.fill")
            case .bubble: Text("!").font(.system(size: 12, weight: .heavy))
            case .out: Image(systemName: "xmark")
            }
            Text(chance.label)
        }
        .font(.system(size: 12, weight: .semibold))
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Capsule().fill(bg))
        .foregroundStyle(color)
    }

    // MARK: - Pairings

    @ViewBuilder
    private func pairingRow(_ match: LocatorMatch, myName: String?) -> some View {
        let mine = match.players.contains { isMe($0.tvDisplayName, myName) }
        let row = HStack(spacing: 10) {
            Text("T\(match.tableNumber.map(String.init) ?? "—")")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(EventsTheme.textTertiary)
                .frame(width: 24, alignment: .leading)

            if match.isBye, let solo = match.players.first {
                Text("\(solo.tvDisplayName) (Bye)").font(.system(size: 14)).foregroundStyle(.white)
                Spacer()
            } else if match.isPod {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(match.players.enumerated()), id: \.offset) { _, player in
                        podPlayerRow(player, myName)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                playerSide(match.players.first, myName, trailing: false)
                Text("vs").font(.system(size: 11)).foregroundStyle(EventsTheme.textTertiary)
                playerSide(match.players.dropFirst().first, myName, trailing: true)
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 14)

        if mine {
            row.greenGradientBorder(radius: 12.5)
        } else {
            row.eventsCard(radius: 14)
        }
    }

    @ViewBuilder
    private func playerSide(_ player: LocatorMatchPlayer?, _ myName: String?, trailing: Bool) -> some View {
        if let player {
            let mine = isMe(player.tvDisplayName, myName)
            let won = player.isWinner ?? false
            let nameColor: Color = mine ? EventsTheme.green : (won ? Color.white : EventsTheme.textSecondary)
            let recordColor: Color = mine ? EventsTheme.green : (won ? EventsTheme.gold : EventsTheme.textSecondary)
            VStack(alignment: trailing ? .trailing : .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if !trailing && won { CrownGlyph() }
                    Text(player.tvDisplayName).font(.system(size: 14, weight: .semibold)).foregroundStyle(nameColor).lineLimit(1)
                    if trailing && won { CrownGlyph() }
                }
                Text(mine ? "you · \(player.record)" : player.record)
                    .font(.system(size: 11)).foregroundStyle(recordColor)
            }
            .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)
        } else {
            Text("—").foregroundStyle(EventsTheme.textTertiary).frame(maxWidth: .infinity)
        }
    }

    /// One player line inside a multiplayer pod row.
    @ViewBuilder
    private func podPlayerRow(_ player: LocatorMatchPlayer, _ myName: String?) -> some View {
        let mine = isMe(player.tvDisplayName, myName)
        let won = player.isWinner ?? false
        HStack(spacing: 4) {
            if won { CrownGlyph() }
            Text(mine ? "\(player.tvDisplayName) · you" : player.tvDisplayName)
                .font(.system(size: 14, weight: mine ? .bold : .semibold))
                .foregroundStyle(mine ? EventsTheme.green : (won ? Color.white : EventsTheme.textSecondary))
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(player.record).font(.system(size: 11))
                .foregroundStyle(won ? EventsTheme.gold : EventsTheme.textSecondary)
        }
    }

    // MARK: - Standings

    @ViewBuilder
    private func standingsCard(_ data: Loaded) -> some View {
        let cut = data.event.resolvedCutSize
        VStack(spacing: 0) {
            ForEach(Array(data.standings.enumerated()), id: \.element.id) { index, standing in
                standingRow(standing, myName: data.myName, cut: cut)
                if index < data.standings.count - 1 {
                    Rectangle().fill(EventsTheme.hairline).frame(height: 1).padding(.leading, 14)
                }
            }
        }
        .eventsCard(radius: 14)
    }

    private func standingRow(_ standing: LocatorStanding, myName: String?, cut: Int?) -> some View {
        let mine = isMe(standing.tvDisplayName, myName)
        let inCut = cut.map { standing.rank <= $0 } ?? false
        return HStack(spacing: 12) {
            Text("\(standing.rank)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(inCut ? EventsTheme.green : EventsTheme.textTertiary)
                .frame(width: 26, alignment: .leading)
            Text(mine ? "\(standing.tvDisplayName) · you" : standing.tvDisplayName)
                .font(.system(size: 14, weight: mine ? .bold : .regular))
                .foregroundStyle(mine ? EventsTheme.green : Color.white)
                .lineLimit(1)
            Spacer()
            Text(standing.record).font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
            Text("\(standing.totalMatchPoints ?? 0)p")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 34, alignment: .trailing)
            Text(standing.omwText)
                .font(.system(size: 11)).foregroundStyle(EventsTheme.textTertiary)
                .frame(width: 42, alignment: .trailing)
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .background(mine ? EventsTheme.greenSoft : Color.clear)
    }

    // MARK: - Failed

    private func failed(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("Couldn't load event").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
            Text(message).font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary).multilineTextAlignment(.center)
            Button("Retry") { Task { await load() } }.tint(EventsTheme.green)
        }
        .frame(maxWidth: .infinity, minHeight: 400).padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private func isMe(_ name: String, _ myName: String?) -> Bool {
        guard let myName, !myName.isEmpty else { return false }
        return name == myName
    }

    // MARK: - Load

    @MainActor
    private func load() async {
        state = .loading
        do {
            async let event = service.event(id: eventID)
            async let pairings = service.pairings(eventID: eventID)
            async let standings = service.standings(eventID: eventID)
            let (e, m, s) = try await (event, pairings, standings)

            var resolved: ResolvedMyMatch?
            if let round = e.currentRound, let token = session.token,
               let match = try? await service.myMatch(roundID: round.id, token: token) {
                resolved = ResolvedMyMatch(match, myUserID: session.userID)
            }

            if let token = session.token {
                let status = (try? await service.registrationStatus(eventID: eventID, token: token)) ?? nil
                registered = isActiveRegistration(status)
                if e.usesDecklists {
                    myDeck = (try? await service.myDeckSubmission(eventID: eventID, token: token)) ?? nil
                }
            }

            let sortedMatches = m.sorted { ($0.tableNumber ?? .max) < ($1.tableNumber ?? .max) }
            state = .loaded(Loaded(event: e,
                                   matches: sortedMatches,
                                   standings: s,
                                   myMatch: resolved,
                                   myName: resolved?.me.displayName ?? myAlias))
        } catch {
            if session.signOutIfUnauthorized(error) { dismiss(); return }
            state = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}

/// Drawn gold crown (crown.fill is not in SkipUI's symbol map).
struct CrownGlyph: View {
    var body: some View {
        CrownShape()
            .fill(EventsTheme.gold)
            .frame(width: 12, height: 9)
    }
}

struct CrownShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        // Three-point crown with a flat base band.
        p.move(to: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: 0, y: h * 0.35))
        p.addLine(to: CGPoint(x: w * 0.25, y: h * 0.6))
        p.addLine(to: CGPoint(x: w * 0.5, y: 0))
        p.addLine(to: CGPoint(x: w * 0.75, y: h * 0.6))
        p.addLine(to: CGPoint(x: w, y: h * 0.35))
        p.addLine(to: CGPoint(x: w, y: h))
        p.closeSubpath()
        return p
    }
}
