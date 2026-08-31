//
//  EventDetailView.swift
//  Riftbound Companiokay
//
//  Live event screen ("Arena" redesign): overview card, your-match (green),
//  "Can I draw?" outlook, pairings (crown winners, your table highlighted),
//  standings. Public TV data + authed my-match. Green is the only accent.
//

import SwiftUI
import EventKit

struct EventDetailView: View {
    let eventID: Int
    var myAlias: String? = nil
    var service: any LocatorService = LocatorCache.shared

    @EnvironmentObject private var session: AuthSession
    @EnvironmentObject private var matchMode: MatchModeStore
    @AppStorage("currentTab") private var currentTab: String = "score"
    @Environment(\.dismiss) private var dismiss
    @State private var state: LoadState = .idle
    @State private var reporting: ResolvedMyMatch?
    @State private var registered = false
    @State private var registering = false
    @State private var registerError: String?
    @State private var confirmingRegister = false
    @State private var myDeck: LocatorDeckSubmission?
    @State private var calendarStore: EKEventStore?
    @State private var calendarDraft: CalendarEventDraft?
    @State private var calendarError: String?
    @State private var selectedRoundID: Int?
    @State private var standingsPending = false
    @State private var playerQuery = ""
    @State private var deckCards: [String: String] = [:]
    @State private var deckCount = 0
    @State private var deckCardsRound: Int?
    @State private var currentRoundID: Int?
    @State private var roster: [LocatorRosterEntry] = []
    @State private var rosterLimit = initialRowCap
    @State private var pairingLimit = initialRowCap
    @State private var standingsLimit = initialRowCap
    /// Pairings per round id. Completed rounds never change, so this cache
    /// survives pull-to-refresh.
    @State private var roundPairings: [Int: [LocatorMatch]] = [:]
    @State private var myResults: [RoundResult]?
    @State private var myResultsLoading = false

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
        let capacity: LocatorEventCapacity?
    }

    /// Rows rendered before the "show more" control appears, and how many
    /// each tap adds. A 626-player event is ~313 pairings and 626 standings;
    /// building every row up front is what made big events slow to open and
    /// rough to scroll. Compose rules out a lazy container here — it measures
    /// to zero inside the page ScrollView and takes the scrolling with it — so
    /// rows are revealed in bounded steps instead of all at once, which would
    /// just move the same stall to the tap.
    static let initialRowCap = 50
    static let rowRevealStep = 100

    /// Search shows a screenful; past that, typing more is faster than scrolling.
    static let searchResultCap = 25

    /// A player as the search field sees them: wherever the event happens to
    /// know about them — standings, this round's pairings, or the roster.
    struct FoundPlayer: Identifiable {
        let name: String
        let rank: Int?
        let detail: String?
        let tableNumber: Int?
        let checkedIn: Bool
        let inCut: Bool
        let isMe: Bool
        let legend: String?
        var id: String { name }
    }

    /// One finished round in "Your results": opponent, game score, outcome.
    struct RoundResult: Identifiable {
        enum Outcome { case win, loss, draw, bye }
        let id: Int            // round id
        let roundLabel: String
        let opponent: String?
        let myGames: Int
        let oppGames: Int
        let outcome: Outcome
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
        // Must sit on the ScrollView itself — on an inner view the environment
        // action never reaches the scroll view and the gesture does nothing.
        .refreshable { await service.invalidate(); await load() }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Event").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if #available(iOS 17.0, *), let event = currentEvent,
                   event.startDatetime != nil, !event.isFinished {
                    Button { addToCalendar(event) } label: {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Add to Calendar")
                }
            }
        }
        .task { if case .idle = state { await load() } }
        .sheet(item: $reporting) { match in
            ReportResultSheet(match: match,
                              isBestOfThree: currentEvent?.isBestOfThree ?? true,
                              token: session.token ?? "",
                              onReported: { Task { await load() } })
        }
        .sheet(item: $calendarDraft) { draft in
            if let store = calendarStore {
                CalendarEditView(draft: draft, store: store) { calendarDraft = nil }
                    .ignoresSafeArea()
            }
        }
        .alert("Calendar", isPresented: Binding(
            get: { calendarError != nil },
            set: { if !$0 { calendarError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(calendarError ?? "")
        }
    }

    @MainActor
    private func addToCalendar(_ event: LocatorEvent) {
        guard let start = event.startDatetime else { return }
        Task {
            // Create the store only when the user actually adds an event.
            let store = EKEventStore()
            let granted: Bool
            do {
                if #available(iOS 17.0, *) {
                    granted = try await store.requestWriteOnlyAccessToEvents()
                } else {
                    granted = false
                }
            } catch {
                calendarError = "Couldn't access your calendar."
                return
            }
            guard granted else {
                calendarError = "Calendar access is off. Turn it on in Settings to add events."
                return
            }
            let end = event.endDatetime ?? start.addingTimeInterval(3 * 60 * 60)
            calendarStore = store
            calendarDraft = CalendarEventDraft(title: event.name,
                                               location: event.fullAddress,
                                               start: start, end: end)
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

            playerSearchSection(data)

            if data.event.isUpcoming {
                upcomingCard(data.event, data.capacity)
                rosterSection()
            }

            if data.myMatch == nil, session.token != nil, !data.event.isFinished,
               registered || data.event.isOpenForRegistration {
                registerCard(data.event)
            }

            if let mine = data.myMatch {
                yourMatchCard(mine, roundLabel: data.event.currentRoundLabel)
            }

            if registered, data.event.usesDecklists { deckCard(data.event) }

            cutOutlookCard(data)

            myResultsCard(data)

            if !data.matches.isEmpty || data.event.browsableRounds.count > 1 {
                pairingsSection(data)
            }

            metaLink(data)

            if !data.standings.isEmpty || standingsPending {
                VStack(alignment: .leading, spacing: 11) {
                    SectionHeader("list.number", "Standings")
                    if data.standings.isEmpty {
                        // Standings arrive after the rest of the page; a row here
                        // beats the section popping in with no warning.
                        HStack(spacing: 8) {
                            ProgressView().tint(EventsTheme.green)
                            Text("Loading standings…")
                                .font(.system(size: 13))
                                .foregroundStyle(EventsTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .eventsCard(radius: 14)
                    } else {
                        standingsCard(data)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .task(id: currentRoundID) { await loadDeckCards() }
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
                    Image(systemName: registered ? "checkmark.circle.fill" : "ticket.fill")
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
                        if registering { ProgressView().tint(EventsTheme.textSecondary) }
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
                        HStack(spacing: 6) {
                            Image(systemName: "safari"); Text("Open on website"); Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(EventsTheme.matchFillBottom)
                        .frame(maxWidth: .infinity).frame(height: 42)
                        .background(EventsTheme.green, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            } else {
                Button { confirmingRegister = true } label: {
                    HStack(spacing: 6) {
                        if registering { ProgressView().tint(EventsTheme.matchFillBottom) }
                        else { Image(systemName: "ticket.fill"); Text("Register · pay in person") }
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(EventsTheme.matchFillBottom)
                    .frame(maxWidth: .infinity).frame(height: 42)
                    .background(EventsTheme.green, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain).disabled(registering)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .greenGradientBorder(radius: 17)
    }

    private func priceLine(_ event: LocatorEvent) -> String {
        if event.priceText == "Free" { return "Free" }
        return event.requiresOnlinePayment ? "\(event.priceText) · online" : "\(event.priceText) · pay in person"
    }

    // MARK: - Your decklist

    @ViewBuilder
    private func deckCard(_ event: LocatorEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("doc.text", "Your decklist")
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
                        Image(systemName: myDeck == nil ? "square.and.arrow.up" : "pencil")
                        Text(myDeck == nil ? "Submit on website" : "View or edit on website")
                        Image(systemName: "arrow.up.right")
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
                    Image(systemName: "mappin.and.ellipse")
                    Text(address).lineLimit(1)
                }
                .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
            }
            roundProgress(event)

            if let url = event.webURL {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "map.fill")
                        Text("View on Locator")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(EventsTheme.green)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(alignment: .topTrailing) {
            RadialGradient(colors: [EventsTheme.green.opacity(0.28), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 220)
                .allowsHitTesting(false)
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
            if let ends = event.roundEndsAt, !event.isFinished {
                roundClock(ends)
            }
        }
    }

    /// Live countdown fed by the scorekeeper's round clock.
    private func roundClock(_ ends: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = ends.timeIntervalSince(context.date)
            HStack(spacing: 6) {
                Image(systemName: "timer")
                Text(left > 0 ? "Round clock  \(Self.clockText(left))" : "Round time is up — turns")
            }
            .font(.system(size: 12, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(left > 0 ? EventsTheme.green : EventsTheme.gold)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(left > 0 ? EventsTheme.greenSoft : EventsTheme.gold.opacity(0.14), in: Capsule())
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private static func clockText(_ t: TimeInterval) -> String {
        let total = Int(t)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - Your match

    @ViewBuilder
    private func yourMatchCard(_ match: ResolvedMyMatch, roundLabel: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                    Text("Your match" + (roundLabel.map { " · \($0)" } ?? ""))
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(EventsTheme.green)
                Spacer()
                Text(match.isComplete ? "Reported" : "In progress")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(EventsTheme.greenSoft, in: Capsule())
                    .foregroundStyle(EventsTheme.green)
            }

            if match.isBye {
                Text("Bye. You advance this round.")
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "chair.fill")
                    Text("Table \(match.tableNumber.map(String.init) ?? "—")")
                }
                .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)

                if match.isMultiplayer {
                    podMatchList(match)
                } else {
                    matchVS(match)
                    OpponentEloBadge(riftboundID: match.opponent?.userEventStatus.user?.id,
                                     opponentName: match.opponent?.displayName,
                                     myRiftboundID: session.userID,
                                     myName: match.me.displayName)
                }

                if match.isComplete {
                    Divider().overlay(EventsTheme.hairline)
                    if let score = match.reportedScore {
                        HStack(spacing: 8) {
                            Text(match.isDraw ? "Drew" : ((match.me.gamesWon ?? 0) > (match.opponent?.gamesWon ?? 0) ? "Won" : "Lost"))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                            Text(score)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(EventsTheme.green)
                            Spacer()
                            Text("as reported")
                                .font(.system(size: 11))
                                .foregroundStyle(EventsTheme.textTertiary)
                        }
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                        Text("Result reported. Ask the scorekeeper to change it.")
                    }
                    .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
                } else if match.isMultiplayer {
                    // Our reporter is 1v1 only — multiplayer pods report on the website.
                    if let url = currentEvent?.webURL {
                        Link(destination: url) {
                            HStack(spacing: 6) {
                                Image(systemName: "safari"); Text("Report on website"); Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(EventsTheme.matchFillBottom)
                            .frame(maxWidth: .infinity).frame(height: 42)
                            .background(EventsTheme.green, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                } else if match.opponent != nil, session.token != nil {
                    Button { reporting = match } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.pencil")
                            Text("Report result")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(EventsTheme.matchFillBottom)
                        .frame(maxWidth: .infinity).frame(height: 42)
                        .background(EventsTheme.green, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                Image(systemName: "gamecontroller.fill")
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
            roundLabel: event.currentRoundLabel,
            roundEndsAt: event.roundEndsAt
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
                .foregroundStyle(mine ? EventsTheme.green : .white).lineLimit(1)
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
                SectionHeader("chart.bar.doc.horizontal", "Can I draw?")
                Text("Top \(cut) · \(roundsLeft) round\(roundsLeft == 1 ? "" : "s") left · you have \(myPoints) pts")
                    .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)
                outlookRow("Win" + suffix, outlook.win)
                outlookRow("Draw" + suffix, outlook.draw)
                outlookRow("Lose" + suffix, outlook.lose)
                Text("“Locked in” is guaranteed regardless of other results. “Bubble” depends on other matches and tiebreakers.")
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
        let icon: String
        switch chance {
        case .locked: color = EventsTheme.green;        bg = EventsTheme.greenSoft;          icon = "checkmark.seal.fill"
        case .bubble: color = EventsTheme.textSecondary; bg = Color.white.opacity(0.08);      icon = "exclamationmark.triangle.fill"
        case .out:    color = .red;                      bg = Color.red.opacity(0.16);        icon = "xmark.seal.fill"
        }
        return HStack(spacing: 5) {
            Image(systemName: icon)
            Text(chance.label)
        }
        .font(.system(size: 12, weight: .semibold))
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(bg, in: Capsule())
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
                matchCentre(match)
                playerSide(match.players.dropFirst().first, myName, trailing: true)
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 14)

        if mine {
            row.greenGradientBorder(radius: 12.5)
        } else if match.isDraw {
            // A drawn table used to look exactly like one nobody had reported.
            row.eventsCard(radius: 14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(EventsTheme.gold.opacity(0.45), lineWidth: 1))
        } else {
            row.eventsCard(radius: 14)
        }
    }

    /// The middle of a pairing row: the games actually recorded for this match,
    /// a draw marker, or "vs" before anything is decided. The players' own
    /// tournament records sit beside their names — showing only those made a
    /// 12-1 season record read like the score of this match.
    @ViewBuilder
    private func matchCentre(_ match: LocatorMatch) -> some View {
        VStack(spacing: 3) {
            if let score = match.gameScore {
                Text(score)
                    .font(.system(size: 14, weight: .bold)).monospacedDigit()
                    .foregroundStyle(.white)
            } else {
                Text(match.isDraw ? "–" : "vs")
                    .font(.system(size: 11))
                    .foregroundStyle(EventsTheme.textTertiary)
            }
            if match.isDraw {
                Text("DRAW")
                    .font(.system(size: 9, weight: .heavy)).tracking(0.5)
                    .foregroundStyle(EventsTheme.gold)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(EventsTheme.gold.opacity(0.16), in: Capsule())
            }
        }
        .fixedSize()
    }

    @ViewBuilder
    private func playerSide(_ player: LocatorMatchPlayer?, _ myName: String?, trailing: Bool) -> some View {
        if let player {
            let mine = isMe(player.tvDisplayName, myName)
            let won = player.isWinner ?? false
            let nameColor: Color = mine ? EventsTheme.green : (won ? .white : EventsTheme.textSecondary)
            // Never gold: this is the player's tournament record, and gold beside
            // a crown made it read as the score of this match.
            let recordColor: Color = mine ? EventsTheme.green : EventsTheme.textSecondary
            VStack(alignment: trailing ? .trailing : .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if !trailing && won { Image(systemName: "crown.fill").font(.system(size: 10)).foregroundStyle(EventsTheme.gold) }
                    Text(player.tvDisplayName).font(.system(size: 14, weight: .semibold)).foregroundStyle(nameColor).lineLimit(1)
                    if trailing && won { Image(systemName: "crown.fill").font(.system(size: 10)).foregroundStyle(EventsTheme.gold) }
                }
                Text(mine ? "you · \(player.record)" : player.record)
                    .font(.system(size: 11)).foregroundStyle(recordColor)
                if let legend = deckCard(for: player.tvDisplayName) {
                    Text(legend)
                        .font(.system(size: 10))
                        .foregroundStyle(EventsTheme.gold.opacity(0.85))
                        .lineLimit(1)
                }
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
            if won { Image(systemName: "crown.fill").font(.system(size: 10)).foregroundStyle(EventsTheme.gold) }
            Text(mine ? "\(player.tvDisplayName) · you" : player.tvDisplayName)
                .font(.system(size: 14, weight: mine ? .bold : .semibold))
                .foregroundStyle(mine ? EventsTheme.green : (won ? .white : EventsTheme.textSecondary))
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(player.record).font(.system(size: 11))
                .foregroundStyle(won ? EventsTheme.gold : EventsTheme.textSecondary)
        }
    }

    // MARK: - Upcoming (pre-event)

    @ViewBuilder
    private func upcomingCard(_ event: LocatorEvent, _ capacity: LocatorEventCapacity?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "hourglass")
                    Text("Starts in")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(EventsTheme.green)
                Spacer()
                if let start = event.startDatetime {
                    Text(start.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(EventsTheme.textSecondary)
                }
            }

            if let start = event.startDatetime {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Self.countdownText(to: start, now: context.date))
                        .font(.system(size: 34, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
            }

            if let capacity, let count = capacity.registeredUserCount {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(EventsTheme.green)
                        Text(capacity.capacity.map { "\(count) of \($0) players registered" }
                             ?? "\(count) players registered")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    if let ratio = capacity.fillRatio {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.08))
                                Capsule().fill(EventsTheme.green)
                                    .frame(width: max(6, geo.size.width * ratio))
                            }
                        }
                        .frame(height: 5)
                    }
                }
            }

            formatChips(event)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .eventsCard(radius: 18)
    }

    private func formatChips(_ event: LocatorEvent) -> some View {
        var chips: [String] = [event.isBestOfThree ? "Best of 3" : "Best of 1"]
        if let rounds = event.swissRoundsTotal, rounds > 0 { chips.append("Swiss · \(rounds) rounds") }
        if let cut = event.resolvedCutSize, cut > 0 { chips.append("Top \(cut)") }
        chips.append(priceLine(event))
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(chips, id: \.self) { chip in
                    Text(chip)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(EventsTheme.textSecondary)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.white.opacity(0.06), in: Capsule())
                }
            }
        }
    }

    private static func countdownText(to start: Date, now: Date) -> String {
        let left = start.timeIntervalSince(now)
        guard left > 0 else { return "Starting…" }
        let total = Int(left)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return String(format: "%dh %02dm", hours, minutes) }
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Find a player

    /// One field over everything the event knows about a player: where they are
    /// sitting, how they are doing, and — before round one — whether they signed
    /// up at all. The Locator has no server-side search (every parameter it was
    /// offered came back ignored), so this filters what is already loaded, which
    /// is also why it can answer instantly.
    @ViewBuilder
    private func playerSearchSection(_ data: Loaded) -> some View {
        // Cheap enough to gate on; the pool itself is only built while typing.
        if data.standings.count + data.matches.count + roster.count > 4 {
            VStack(alignment: .leading, spacing: 11) {
                SectionHeader("magnifyingglass", "Find a player")

                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(EventsTheme.textSecondary)
                    TextField("Search by name", text: $playerQuery)
                        .foregroundStyle(.white)
                    if !playerQuery.isEmpty {
                        Button { playerQuery = "" } label: {
                            Image(systemName: "xmark").foregroundStyle(EventsTheme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).frame(height: 50)
                .eventsCard(radius: EventsTheme.pillRadius)

                let query = playerQuery.trimmingCharacters(in: .whitespaces).lowercased()
                if !query.isEmpty {
                    let hits = searchablePlayers(data).filter { $0.name.lowercased().contains(query) }
                    if hits.isEmpty {
                        Text("Nobody here by that name.")
                            .font(.system(size: 13))
                            .foregroundStyle(EventsTheme.textSecondary)
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .eventsCard(radius: 14)
                    } else {
                        let capped = Array(hits.prefix(Self.searchResultCap))
                        VStack(spacing: 0) {
                            ForEach(Array(capped.enumerated()), id: \.element.id) { index, hit in
                                foundPlayerRow(hit)
                                if index < capped.count - 1 {
                                    Rectangle().fill(EventsTheme.hairline).frame(height: 1).padding(.leading, 14)
                                }
                            }
                        }
                        .eventsCard(radius: 14)

                        if hits.count > capped.count {
                            Text("\(hits.count - capped.count) more — keep typing to narrow it down.")
                                .font(.system(size: 12))
                                .foregroundStyle(EventsTheme.textTertiary)
                        }
                    }
                }
            }
        }
    }

    /// Everyone the event knows about, standings order first (the meaningful
    /// one), then players only in pairings, then the roster. Built on demand:
    /// at a 626-player event this is 626 rows of work, so it runs while the
    /// field has text in it and not on every redraw of the page.
    private func searchablePlayers(_ data: Loaded) -> [FoundPlayer] {
        let cut = data.event.resolvedCutSize

        var seatByName: [String: (table: Int?, opponent: String?)] = [:]
        for match in data.matches {
            for player in match.players {
                let others = match.players
                    .filter { $0.tvDisplayName != player.tvDisplayName }
                    .map { $0.tvDisplayName }
                let opponent = match.isBye || others.isEmpty ? "bye" : others.joined(separator: ", ")
                seatByName[player.tvDisplayName] = (match.tableNumber, opponent)
            }
        }

        var standingByName: [String: LocatorStanding] = [:]
        for standing in data.standings { standingByName[standing.tvDisplayName] = standing }

        var names = data.standings.map { $0.tvDisplayName }
        var seen = Set(names)
        for name in seatByName.keys.sorted() where !seen.contains(name) {
            names.append(name)
            seen.insert(name)
        }
        for entry in roster where entry.isActive && !seen.contains(entry.tvDisplayName) {
            names.append(entry.tvDisplayName)
            seen.insert(entry.tvDisplayName)
        }

        let checkedIn = Set(roster.filter { $0.checkedIn == true }.map { $0.tvDisplayName })

        return names.map { name in
            let standing = standingByName[name]
            let seat = seatByName[name]
            var parts: [String] = []
            if let standing {
                parts.append(standing.record)
                if let points = standing.totalMatchPoints { parts.append("\(points) pts") }
            }
            if let opponent = seat?.opponent { parts.append("vs \(opponent)") }

            return FoundPlayer(
                name: name,
                rank: standing?.rank,
                detail: parts.isEmpty ? nil : parts.joined(separator: " · "),
                tableNumber: seat?.table,
                checkedIn: checkedIn.contains(name),
                inCut: cut != nil && standing != nil && standing!.rank <= cut!,
                isMe: isMe(name, myAlias),
                legend: deckCard(for: name)
            )
        }
    }

    private func foundPlayerRow(_ hit: FoundPlayer) -> some View {
        HStack(spacing: 12) {
            if let rank = hit.rank {
                Text("\(rank)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(hit.inCut ? EventsTheme.green : EventsTheme.textTertiary)
                    .frame(width: 32, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(hit.isMe ? "\(hit.name) · you" : hit.name)
                    .font(.system(size: 14, weight: hit.isMe ? .bold : .semibold))
                    .foregroundStyle(hit.isMe ? EventsTheme.green : .white)
                    .lineLimit(1)
                if let detail = hit.detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(EventsTheme.textSecondary)
                        .lineLimit(1)
                }
                if let legend = hit.legend {
                    Text(legend)
                        .font(.system(size: 11))
                        .foregroundStyle(EventsTheme.gold.opacity(0.85))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let table = hit.tableNumber {
                VStack(spacing: 1) {
                    Text("TABLE")
                        .font(.system(size: 8, weight: .heavy)).tracking(0.5)
                        .foregroundStyle(EventsTheme.textTertiary)
                    Text("\(table)")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .fixedSize()
            } else if hit.checkedIn {
                Text("CHECKED IN")
                    .font(.system(size: 9, weight: .heavy)).tracking(0.5)
                    .foregroundStyle(EventsTheme.green)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(EventsTheme.greenSoft, in: Capsule())
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .background(hit.isMe ? EventsTheme.greenSoft : Color.clear)
    }

    // MARK: - Metagame

    /// Entry point to the breakdown. Kept to one row on purpose: the event page
    /// is for finding your table and your standing, and the full table pushed
    /// both of those off the screen.
    @ViewBuilder
    private func metaLink(_ data: Loaded) -> some View {
        let legends = Set(deckCards.values).count
        if legends > 1, let roundID = currentRoundID {
            NavigationLink(value: EventMetaRoute(roundID: roundID,
                                                 cutSize: data.event.resolvedCutSize)) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Metagame")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("\(deckCount) decks · \(legends) legends · win rates and conversion")
                            .font(.system(size: 12))
                            .foregroundStyle(EventsTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(EventsTheme.textTertiary)
                }
                .padding(.vertical, 14).padding(.horizontal, 14)
                .eventsCard(radius: 14)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Who's playing (before the first round)

    /// Registered players, shown only while an event is still upcoming —
    /// standings and pairings are both empty until round one, so this is the
    /// only answer to "who else is coming" the app can give.
    @ViewBuilder
    private func rosterSection() -> some View {
        if !roster.isEmpty {
            let active = roster.filter(\.isActive)
            let capped = Array(active.prefix(rosterLimit))
            let checkedIn = active.filter { $0.checkedIn == true }.count

            VStack(alignment: .leading, spacing: 11) {
                SectionHeader("person.3.fill", "Who's playing (\(active.count))")

                if checkedIn > 0 {
                    Text("\(checkedIn) checked in")
                        .font(.system(size: 12))
                        .foregroundStyle(EventsTheme.textSecondary)
                }

                VStack(spacing: 0) {
                    ForEach(Array(capped.enumerated()), id: \.element.id) { index, player in
                        rosterRow(player)
                        if index < capped.count - 1 {
                            Rectangle().fill(EventsTheme.hairline).frame(height: 1).padding(.leading, 14)
                        }
                    }
                }
                .eventsCard(radius: 14)

                if active.count > capped.count {
                    showMoreButton(remaining: active.count - capped.count) {
                        rosterLimit += Self.rowRevealStep
                    }
                }
            }
        }
    }

    private func rosterRow(_ player: LocatorRosterEntry) -> some View {
        let mine = isMe(player.tvDisplayName, myAlias)
        return HStack(spacing: 12) {
            Text(mine ? "\(player.tvDisplayName) · you" : player.tvDisplayName)
                .font(.system(size: 14, weight: mine ? .bold : .regular))
                .foregroundStyle(mine ? EventsTheme.green : .white)
                .lineLimit(1)
            Spacer(minLength: 8)
            if player.checkedIn == true {
                Text("CHECKED IN")
                    .font(.system(size: 9, weight: .heavy)).tracking(0.5)
                    .foregroundStyle(EventsTheme.green)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(EventsTheme.greenSoft, in: Capsule())
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .background(mine ? EventsTheme.greenSoft : Color.clear)
    }

    // MARK: - Pairings section (round switcher)

    @ViewBuilder
    private func pairingsSection(_ data: Loaded) -> some View {
        let currentID = data.event.currentRound?.id
        let rounds = data.event.browsableRounds
        let shownID = selectedRoundID ?? currentID
        let shownRound = rounds.first { $0.id == shownID }
        let label = shownRound.map { " · " + data.event.label(for: $0) }
            ?? (data.event.currentRoundLabel.map { " · \($0)" } ?? "")

        VStack(alignment: .leading, spacing: 11) {
            SectionHeader("person.2.shield.fill", "Pairings" + label)

            if rounds.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(rounds) { round in
                            roundChip(round,
                                      isSelected: round.id == shownID,
                                      isCurrent: round.id == currentID,
                                      event: data.event)
                        }
                    }
                }
            }

            // Lazy: a 1000-player event is ~500 pairings, and building them all
            // before the first frame is what made big events crawl.
            if selectedRoundID == nil || selectedRoundID == currentID {
                pairingList(data.matches, myName: data.myName)
            } else if let matches = selectedRoundID.flatMap({ roundPairings[$0] }) {
                pairingList(matches, myName: data.myName)
            } else {
                HStack { Spacer(); ProgressView().tint(EventsTheme.green); Spacer() }
                    .frame(height: 80)
            }
        }
    }

    /// Caps how many rows are built at once and offers the rest behind a tap.
    /// Deliberately not a lazy container — on Compose that measures to zero
    /// inside the page ScrollView and takes the scrolling with it.
    @ViewBuilder
    private func pairingList(_ matches: [LocatorMatch], myName: String?) -> some View {
        // The search field doubles as the pairings filter: typing a name narrows
        // the round you are looking at rather than only listing hits above it.
        let query = playerQuery.trimmingCharacters(in: .whitespaces).lowercased()
        let shown = query.isEmpty ? matches : matches.filter { match in
            match.players.contains { $0.tvDisplayName.lowercased().contains(query) }
        }

        if shown.isEmpty, !query.isEmpty {
            Text("No pairing for that name this round.")
                .font(.system(size: 13))
                .foregroundStyle(EventsTheme.textSecondary)
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .eventsCard(radius: 14)
        } else {
            let capped = Array(shown.prefix(pairingLimit))
            LazyVStack(spacing: 8) {
                ForEach(capped) { pairingRow($0, myName: myName) }
            }
            if shown.count > capped.count {
                showMoreButton(remaining: shown.count - capped.count) {
                    pairingLimit += Self.rowRevealStep
                }
            }
        }
    }

    private func showMoreButton(remaining: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(remaining <= Self.rowRevealStep
                 ? "Show remaining \(remaining)"
                 : "Show \(Self.rowRevealStep) more · \(remaining) left")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(EventsTheme.green)
                .frame(maxWidth: .infinity).frame(height: 42)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(EventsTheme.green.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func roundChip(_ round: LocatorRound, isSelected: Bool, isCurrent: Bool, event: LocatorEvent) -> some View {
        Button {
            selectRound(round, currentID: event.currentRound?.id)
        } label: {
            HStack(spacing: 4) {
                if isCurrent {
                    Circle()
                        .fill(isSelected ? EventsTheme.matchFillBottom : EventsTheme.green)
                        .frame(width: 5, height: 5)
                }
                Text(event.shortLabel(for: round))
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(isSelected ? EventsTheme.matchFillBottom : EventsTheme.textSecondary)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(isSelected ? EventsTheme.green : Color.white.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func selectRound(_ round: LocatorRound, currentID: Int?) {
        if round.id == currentID { selectedRoundID = nil; return }
        selectedRoundID = round.id
        guard roundPairings[round.id] == nil else { return }
        Task { await loadRound(round) }
    }

    @MainActor
    private func loadRound(_ round: LocatorRound) async {
        guard let fetched = try? await service.pairings(eventID: eventID, roundID: round.id) else {
            // Fetch failed: drop back to the live round instead of spinning forever.
            if selectedRoundID == round.id { selectedRoundID = nil }
            return
        }
        roundPairings[round.id] = fetched.sorted { ($0.tableNumber ?? .max) < ($1.tableNumber ?? .max) }
    }

    // MARK: - Your results (round by round)

    @ViewBuilder
    private func myResultsCard(_ data: Loaded) -> some View {
        let completed = data.event.browsableRounds.filter { ($0.status ?? "").uppercased() == "COMPLETE" }
        if data.myName != nil, !completed.isEmpty, !data.event.isUpcoming {
            VStack(alignment: .leading, spacing: 11) {
                SectionHeader("clock.arrow.circlepath", "Your results")
                if let results = myResults {
                    if results.isEmpty {
                        Text("No finished matches for you yet.")
                            .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .eventsCard(radius: 14)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                                myResultRow(result)
                                if index < results.count - 1 {
                                    Rectangle().fill(EventsTheme.hairline).frame(height: 1).padding(.leading, 14)
                                }
                            }
                        }
                        .eventsCard(radius: 14)
                    }
                } else {
                    Button {
                        Task { await loadMyResults(data) }
                    } label: {
                        HStack(spacing: 6) {
                            if myResultsLoading {
                                ProgressView().tint(EventsTheme.green)
                            } else {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("Show round by round")
                            }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(EventsTheme.green)
                        .frame(maxWidth: .infinity).frame(height: 42)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(EventsTheme.green.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(myResultsLoading)
                }
            }
        }
    }

    private func myResultRow(_ result: RoundResult) -> some View {
        HStack(spacing: 12) {
            Text(result.roundLabel)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(EventsTheme.textTertiary)
                .frame(width: 30, alignment: .leading)
            Text(result.opponent.map { "vs \($0)" } ?? "Bye")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white).lineLimit(1)
            Spacer()
            if result.outcome != .bye {
                Text("\(result.myGames)–\(result.oppGames)")
                    .font(.system(size: 13, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(EventsTheme.textSecondary)
            }
            outcomeBadge(result.outcome)
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
    }

    private func outcomeBadge(_ outcome: RoundResult.Outcome) -> some View {
        let label: String
        let color: Color
        let bg: Color
        switch outcome {
        case .win:  label = "W";   color = EventsTheme.matchFillBottom; bg = EventsTheme.green
        case .loss: label = "L";   color = .white;                      bg = Color.red.opacity(0.72)
        case .draw: label = "D";   color = .white;                      bg = Color.white.opacity(0.16)
        case .bye:  label = "BYE"; color = EventsTheme.green;           bg = EventsTheme.greenSoft
        }
        return Text(label)
            .font(.system(size: 11, weight: .heavy))
            .padding(.horizontal, 8)
            .frame(minWidth: 26).frame(height: 24)
            .background(bg, in: Capsule())
            .foregroundStyle(color)
    }

    @MainActor
    private func loadMyResults(_ data: Loaded) async {
        guard let myName = data.myName, !myResultsLoading else { return }
        myResultsLoading = true
        defer { myResultsLoading = false }

        var out: [RoundResult] = []
        let completed = data.event.browsableRounds.filter { ($0.status ?? "").uppercased() == "COMPLETE" }
        for round in completed {
            let matches: [LocatorMatch]
            if let cached = roundPairings[round.id] {
                matches = cached
            } else if let fetched = try? await service.pairings(eventID: eventID, roundID: round.id) {
                let sorted = fetched.sorted { ($0.tableNumber ?? .max) < ($1.tableNumber ?? .max) }
                roundPairings[round.id] = sorted
                matches = sorted
            } else { continue }

            guard let match = matches.first(where: { $0.players.contains { isMe($0.tvDisplayName, myName) } })
            else { continue }
            let me = match.players.first { isMe($0.tvDisplayName, myName) }
            let opp = match.players.first { !isMe($0.tvDisplayName, myName) }
            let outcome: RoundResult.Outcome
            if match.isBye || opp == nil { outcome = .bye }
            else if me?.isWinner == true { outcome = .win }
            else if opp?.isWinner == true { outcome = .loss }
            else { outcome = .draw }
            out.append(RoundResult(id: round.id,
                                   roundLabel: data.event.shortLabel(for: round),
                                   opponent: opp?.tvDisplayName,
                                   myGames: me?.gamesWon ?? 0,
                                   oppGames: opp?.gamesWon ?? 0,
                                   outcome: outcome))
        }
        myResults = out
    }

    // MARK: - Standings

    @ViewBuilder
    private func standingsCard(_ data: Loaded) -> some View {
        let cut = data.event.resolvedCutSize
        let capped = Array(data.standings.prefix(standingsLimit))
        VStack(spacing: 11) {
            LazyVStack(spacing: 0) {
                ForEach(Array(capped.enumerated()), id: \.element.id) { index, standing in
                    standingRow(standing, myName: data.myName, cut: cut)
                    if index < capped.count - 1 {
                        Rectangle().fill(EventsTheme.hairline).frame(height: 1).padding(.leading, 14)
                    }
                }
            }
            .eventsCard(radius: 14)

            if data.standings.count > capped.count {
                showMoreButton(remaining: data.standings.count - capped.count) {
                    standingsLimit += Self.rowRevealStep
                }
            }
        }
    }

    private func standingRow(_ standing: LocatorStanding, myName: String?, cut: Int?) -> some View {
        let mine = isMe(standing.tvDisplayName, myName)
        let inCut = cut.map { standing.rank <= $0 } ?? false
        return HStack(spacing: 12) {
            Text("\(standing.rank)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(inCut ? EventsTheme.green : EventsTheme.textTertiary)
                .frame(width: 26, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(mine ? "\(standing.tvDisplayName) · you" : standing.tvDisplayName)
                    .font(.system(size: 14, weight: mine ? .bold : .regular))
                    .foregroundStyle(mine ? EventsTheme.green : .white)
                    .lineLimit(1)
                if let legend = deckCard(for: standing.tvDisplayName) {
                    Text(legend)
                        .font(.system(size: 10))
                        .foregroundStyle(EventsTheme.gold.opacity(0.85))
                        .lineLimit(1)
                }
            }
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
            Image(systemName: "wifi.exclamationmark").font(.system(size: 30)).foregroundStyle(EventsTheme.textSecondary)
            Text("Couldn't load event").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
            Text(message).font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary).multilineTextAlignment(.center)
            Button("Retry") { Task { await load() } }.tint(EventsTheme.green)
        }
        .frame(maxWidth: .infinity, minHeight: 400).padding(.horizontal, 24)
    }

    // MARK: - Helpers

    /// Submitted legend for a player, once the event's decks have loaded.
    private func deckCard(for name: String) -> String? { deckCards[name] }

    /// Every player's legend for this event. Fetched separately from the rest —
    /// it is a different, heavier service — so the page never waits on it and
    /// the legends fill in. Event-wide, so switching rounds costs nothing.
    @MainActor
    private func loadDeckCards() async {
        guard let roundID = currentRoundID, deckCardsRound != roundID else { return }
        guard let decks = try? await service.eventDecks(roundID: roundID) else { return }
        deckCardsRound = roundID

        var cards: [String: String] = [:]
        for deck in decks { cards[deck.displayName] = deck.legend }
        deckCards = cards
        deckCount = decks.count
    }

    private func isMe(_ name: String, _ myName: String?) -> Bool {
        guard let myName, !myName.isEmpty else { return false }
        return name == myName
    }

    // MARK: - Load

    private func fetchRegistrationStatus() async -> String? {
        guard let token = session.token else { return nil }
        return (try? await service.registrationStatus(eventID: eventID, token: token)) ?? nil
    }

    private func fetchMyMatch(for event: LocatorEvent) async -> ResolvedMyMatch? {
        guard let round = event.currentRound, let token = session.token,
              let match = try? await service.myMatch(roundID: round.id, token: token)
        else { return nil }
        return ResolvedMyMatch(match, myUserID: session.userID)
    }

    /// Sign-up counters only matter before the event starts.
    private func fetchCapacity(for event: LocatorEvent) async -> LocatorEventCapacity? {
        guard event.isUpcoming else { return nil }
        return try? await service.capacity(eventID: eventID)
    }

    /// Who has signed up. Only worth fetching before the first round: once
    /// pairings exist the standings carry the same players with more detail.
    private func fetchRoster(for event: LocatorEvent) async -> [LocatorRosterEntry] {
        guard event.isUpcoming else { return [] }
        return (try? await service.roster(eventID: eventID)) ?? []
    }

    @MainActor
    private func load() async {
        // Keep loaded content mounted during pull-to-refresh; a full swap to the
        // spinner branch tears down the scroll view and breaks the refresh gesture.
        if case .loaded = state {} else { state = .loading }
        do {
            // Standings are the slow one — ~4s per page server-side, and several
            // pages at a large event. Everything else lands in well under a
            // second, so the screen is published without them and they fill in
            // when they arrive rather than holding the whole page blank.
            async let standingsTask = service.standings(eventID: eventID)
            async let statusTask = fetchRegistrationStatus()

            async let eventTask = service.event(id: eventID)
            async let pairingsTask = service.pairings(eventID: eventID)
            let e = try await eventTask
            currentRoundID = e.currentRound?.id
            let m = try await pairingsTask

            // These depend on the event, but not on each other.
            async let myMatchTask = fetchMyMatch(for: e)
            async let capacityTask = fetchCapacity(for: e)
            async let rosterTask = fetchRoster(for: e)

            let resolved = await myMatchTask
            let capacity = await capacityTask
            roster = await rosterTask
            registered = isActiveRegistration(await statusTask)

            let sortedMatches = m.sorted { ($0.tableNumber ?? .max) < ($1.tableNumber ?? .max) }
            func compose(_ standings: [LocatorStanding]) -> Loaded {
                Loaded(event: e,
                       matches: sortedMatches,
                       standings: standings,
                       myMatch: resolved,
                       myName: resolved?.me.displayName ?? myAlias,
                       capacity: capacity)
            }

            // First paint: everything except standings.
            standingsPending = true
            state = .loaded(compose([]))

            if e.usesDecklists, let token = session.token {
                myDeck = (try? await service.myDeckSubmission(eventID: eventID, token: token)) ?? nil
            }

            let s = (try? await standingsTask) ?? []
            standingsPending = false
            let loaded = compose(s)
            state = .loaded(loaded)

            // A refresh may have completed another round; extend "Your results"
            // if the user already opened it (completed rounds stay cached).
            if myResults != nil {
                myResults = nil
                await loadMyResults(loaded)
            }
        } catch {
            if session.signOutIfUnauthorized(error) { dismiss(); return }
            state = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}

#Preview {
    NavigationStack {
        EventDetailView(eventID: 604874)
    }
    .environmentObject(AuthSession())
    .environmentObject(MatchModeStore())
}
