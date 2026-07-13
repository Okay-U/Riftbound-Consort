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
    var service: any LocatorService = RiftboundLocatorService()

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
                    SectionHeader("person.2.shield.fill", "Pairings" + label)
                    VStack(spacing: 8) { ForEach(data.matches) { pairingRow($0, myName: data.myName) } }
                }
            }

            if !data.standings.isEmpty {
                VStack(alignment: .leading, spacing: 11) {
                    SectionHeader("list.number", "Standings")
                    standingsCard(data)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .refreshable { await load() }
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
        }
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
                                     myRiftboundID: session.userID)
                }

                if match.isComplete {
                    Divider().overlay(EventsTheme.hairline)
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
            let nameColor: Color = mine ? EventsTheme.green : (won ? .white : EventsTheme.textSecondary)
            let recordColor: Color = mine ? EventsTheme.green : (won ? EventsTheme.gold : EventsTheme.textSecondary)
            VStack(alignment: trailing ? .trailing : .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if !trailing && won { Image(systemName: "crown.fill").font(.system(size: 10)).foregroundStyle(EventsTheme.gold) }
                    Text(player.tvDisplayName).font(.system(size: 14, weight: .semibold)).foregroundStyle(nameColor).lineLimit(1)
                    if trailing && won { Image(systemName: "crown.fill").font(.system(size: 10)).foregroundStyle(EventsTheme.gold) }
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
                .foregroundStyle(mine ? EventsTheme.green : .white)
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
            Image(systemName: "wifi.exclamationmark").font(.system(size: 30)).foregroundStyle(EventsTheme.textSecondary)
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

#Preview {
    NavigationStack {
        EventDetailView(eventID: 604874)
    }
    .environmentObject(AuthSession())
    .environmentObject(MatchModeStore())
}
