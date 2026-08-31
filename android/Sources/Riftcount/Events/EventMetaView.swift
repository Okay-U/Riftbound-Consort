//
//  EventMetaView.swift
//  Riftcount
//
//  The metagame of one event: what the field brought, how each legend did, and
//  how much of it converted. Its own screen — inline on the event page it
//  crowded out the pairings and standings people actually came for.
//
//  Costs nothing to open: the standings rows it needs are the same ones the
//  event page already fetched for its gold legend lines, and LocatorCache still
//  has them.
//

import SwiftUI

struct EventMetaView: View {
    let roundID: Int
    let cutSize: Int?

    var service: any LocatorService = LocatorCache.shared

    @State var decks: [LocatorPlayerDeck] = []
    @State var meta: [LegendMeta] = []
    @State var sort: MetaSort = .played
    @State var failure: String?
    @State var loading = true

    init(roundID: Int, cutSize: Int?, service: any LocatorService = LocatorCache.shared) {
        self.roundID = roundID
        self.cutSize = cutSize
        self.service = service
    }

    /// Top 64 is only a meaningful bar when there were more than 64 players.
    var showsTop64: Bool { decks.count > 64 }

    enum MetaSort: Hashable {
        case played, winRate, conversion
    }

    /// A rate sort needs a floor. One player going 1-0 is not a 100% deck, and
    /// without this the top of the list is nothing but one-offs.
    static let minSample = 5

    var sorted: [LegendMeta] {
        switch sort {
        case .played:
            return meta   // breakdown already orders by player count
        case .winRate:
            return ranked { $0.winRate }
        case .conversion:
            return ranked { conversionRate($0) }
        }
    }

    /// Legends under the sample floor are not hidden — they drop below the
    /// qualified ones, so the list still accounts for the whole field.
    func ranked(_ value: (LegendMeta) -> Double) -> [LegendMeta] {
        let qualified = meta.filter { $0.players >= Self.minSample }
        let rest = meta.filter { $0.players < Self.minSample }
        return qualified.sorted { value($0) > value($1) }
             + rest.sorted { $0.players > $1.players }
    }

    /// Conversion against whichever bar the screen is showing.
    func conversionRate(_ entry: LegendMeta) -> Double {
        guard entry.players > 0 else { return 0 }
        let made = showsTop64 ? entry.top64 : entry.converted
        return Double(made) / Double(entry.players)
    }

    var sortLabel: String {
        switch sort {
        case .played:     return "MOST PLAYED"
        case .winRate:    return "BEST WIN RATE"
        case .conversion: return "BEST CONVERSION"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if loading {
                    HStack { Spacer(); ProgressView().tint(EventsTheme.green); Spacer() }
                        .frame(height: 120)
                } else if let failure {
                    Text(failure)
                        .font(.system(size: 13))
                        .foregroundStyle(EventsTheme.textSecondary)
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .eventsCard(radius: 14)
                } else if meta.isEmpty {
                    Text("No decklists were submitted for this event.")
                        .font(.system(size: 13))
                        .foregroundStyle(EventsTheme.textSecondary)
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .eventsCard(radius: 14)
                } else {
                    summary
                    legends
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .background(EventsTheme.bg.ignoresSafeArea())
        .navigationTitle("Metagame")
        .task { await load() }
    }

    // MARK: - Summary

    var summary: some View {
        HStack(spacing: 0) {
            summaryCell("\(decks.count)", "decks")
            divider
            summaryCell("\(meta.count)", "legends")
            divider
            summaryCell(percent(topShare), "top share")
        }
        .eventsCard(radius: 14)
    }

    var topShare: Double {
        guard let first = meta.first, !decks.isEmpty else { return 0 }
        return Double(first.players) / Double(decks.count)
    }

    var divider: some View {
        Rectangle().fill(EventsTheme.hairline).frame(width: 1, height: 30)
    }

    func summaryCell(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(EventsTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
    }

    // MARK: - Legends

    var legends: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                sortChip("Played", .played)
                sortChip("Win rate", .winRate)
                sortChip("Conversion", .conversion)
            }

            HStack(spacing: 6) {
                Text(sortLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(EventsTheme.textSecondary)
                if sort != .played {
                    Text("· \(Self.minSample)+ players first")
                        .font(.system(size: 11))
                        .foregroundStyle(EventsTheme.textTertiary)
                }
            }

            // Not a lazy container: on Compose that measures to zero inside a
            // ScrollView. A field never has more than a few dozen legends.
            VStack(spacing: 0) {
                let rows = sorted
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
                    row(entry)
                    if index < rows.count - 1 {
                        Rectangle().fill(EventsTheme.hairline).frame(height: 1).padding(.leading, 14)
                    }
                }
            }
            .eventsCard(radius: 14)
        }
    }

    func sortChip(_ label: String, _ value: MetaSort) -> some View {
        let selected = sort == value
        return Text(label)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(selected ? EventsTheme.matchFillBottom : EventsTheme.textSecondary)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(selected ? EventsTheme.green : Color.white.opacity(0.06)))
            .onTapGesture { sort = value }
    }

    func row(_ entry: LegendMeta) -> some View {
        let share = decks.isEmpty ? 0 : Double(entry.players) / Double(decks.count)
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.legend)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white).lineLimit(1)
                    Text("\(entry.players) player\(entry.players == 1 ? "" : "s") · \(entry.record)")
                        .font(.system(size: 11))
                        .foregroundStyle(EventsTheme.textSecondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(percent(entry.winRate))
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(entry.winRate >= 0.5 ? EventsTheme.green : EventsTheme.textSecondary)
                    Text("WIN RATE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(EventsTheme.textTertiary)
                }
                .fixedSize()
            }

            // Share of field, drawn — the fastest read of a metagame.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule().fill(EventsTheme.green.opacity(0.55))
                        .frame(width: max(2, geo.size.width * share))
                }
            }
            .frame(height: 4)

            HStack(spacing: 10) {
                Text("\(percent(share)) of field")
                    .font(.system(size: 11))
                    .foregroundStyle(EventsTheme.textTertiary)
                if showsTop64 {
                    conversionChip("T64", entry.top64, entry.players)
                }
                if let cutSize, cutSize > 0, cutSize != 64 {
                    conversionChip("T\(cutSize)", entry.converted, entry.players)
                }
                Spacer(minLength: 4)
                if let best = entry.bestRank {
                    Text("best #\(best)")
                        .font(.system(size: 11))
                        .foregroundStyle(best <= 8 ? EventsTheme.gold.opacity(0.85) : EventsTheme.textTertiary)
                }
            }
        }
        .padding(.vertical, 11).padding(.horizontal, 14)
    }

    /// Conversion is the share of that legend's players who reached the bar —
    /// not the share of the bar they occupied.
    func conversionChip(_ label: String, _ made: Int, _ players: Int) -> some View {
        let rate = players == 0 ? 0 : Double(made) / Double(players)
        return Text("\(percent(rate)) → \(label)")
            .font(.system(size: 11))
            .foregroundStyle(made > 0 ? EventsTheme.green : EventsTheme.textTertiary)
    }

    func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    // MARK: - Load

    @MainActor
    func load() async {
        loading = true
        defer { loading = false }
        do {
            let fetched = try await service.eventDecks(roundID: roundID)
            decks = fetched
            meta = LegendMeta.breakdown(fetched, cut: cutSize)
        } catch {
            failure = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
