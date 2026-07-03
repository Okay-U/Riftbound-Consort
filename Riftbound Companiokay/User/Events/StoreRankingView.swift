//
//  StoreRankingView.swift
//  Riftbound Companiokay
//
//  Shows the eloshowdown community (city) leaderboard on a store page. The store
//  comes from the Locator (which addresses cities in their local language, e.g.
//  "München"), while eloshowdown keys communities by their English city name
//  ("Munich"). We bridge the two by reverse-geocoding the store's coordinates with
//  an English locale, then matching the resulting city against /communities to get
//  the slug the leaderboard endpoint expects. Renders nothing if no match/data.
//

import SwiftUI
import CoreLocation

struct StoreRankingView: View {
    let store: LocatorStore
    var service: any EloShowdownService = EloCache.shared

    @State private var phase: Phase = .idle

    enum Phase {
        case idle, loading
        case loaded(city: String, rows: [EloLeaderRow])
        case unavailable
    }

    private let displayLimit = 20      // fetched + scrollable
    private let visibleRows = 10       // rows shown before scrolling
    private let rowHeight: CGFloat = 44

    var body: some View {
        Group {
            switch phase {
            case .idle, .loading:
                loadingCard
            case .loaded(let city, let rows):
                rankingCard(city: city, rows: rows)
            case .unavailable:
                unavailableCard
            }
        }
        .task { await load() }
    }

    // MARK: - Cards

    private var loadingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("trophy.fill", "Local ranking")
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .eventsCard(radius: 18)
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("trophy.fill", "Local ranking")
            HStack(spacing: 10) {
                Image(systemName: "person.2.slash")
                    .font(.system(size: 16)).foregroundStyle(EventsTheme.textTertiary)
                Text("Not enough player data for this region's community yet.")
                    .font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .eventsCard(radius: 18)
    }

    private func rankingCard(city: String, rows: [EloLeaderRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("trophy.fill", "Local ranking") {
                Text(city)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(EventsTheme.green)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(EventsTheme.greenSoft, in: Capsule())
            }
            Text("Top players in \(city), via eloshowdown.")
                .font(.system(size: 12)).foregroundStyle(EventsTheme.textSecondary)

            let shown = Array(rows.prefix(displayLimit))
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    ForEach(shown) { row in
                        rankRow(row)
                        Rectangle().fill(EventsTheme.hairline).frame(height: 1)
                    }
                }
            }
            .frame(height: CGFloat(min(shown.count, visibleRows)) * rowHeight)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .eventsCard(radius: 18)
    }

    private func rankRow(_ row: EloLeaderRow) -> some View {
        HStack(spacing: 10) {
            Text("#\(row.rank ?? 0)")
                .font(.system(size: 14, weight: .heavy).monospacedDigit())
                .foregroundStyle(rankColor(row.rank))
                .frame(width: 34, alignment: .leading)
            Text(row.displayName ?? "—")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                .lineLimit(1).truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let wr = row.winRate {
                Text("\(Int(wr.rounded()))%")
                    .font(.system(size: 12)).foregroundStyle(EventsTheme.textTertiary)
            }
            Text("\(row.currentElo ?? 0)")
                .font(.system(size: 14, weight: .heavy).monospacedDigit())
                .foregroundStyle(EventsTheme.green)
                .frame(width: 52, alignment: .trailing)
        }
        .frame(height: rowHeight - 1)   // + 1pt divider = rowHeight, so visibleRows fill the viewport
    }

    private func rankColor(_ rank: Int?) -> Color {
        switch rank {
        case 1: return EventsTheme.gold
        case 2, 3: return EventsTheme.green
        default: return EventsTheme.textTertiary
        }
    }

    // MARK: - Load

    @MainActor
    private func load() async {
        guard case .idle = phase else { return }
        guard let lat = store.latitude, let lon = store.longitude else { phase = .unavailable; return }
        phase = .loading

        // 1) Store coordinates → English city name (bridges München → Munich).
        guard let place = await geocodeCity(lat: lat, lon: lon) else { phase = .unavailable; return }

        // 2) Resolve the city to an eloshowdown community slug.
        guard let community = try? await resolveCommunity(city: place.city, country: place.country)
        else { phase = .unavailable; return }

        // 3) Pull the community leaderboard for the current season.
        guard let season = try? await service.currentSeason(),
              let rows = try? await service.leaderboard(season: season.slug, community: community.slug,
                                                         country: nil, limit: 20),
              !rows.isEmpty else { phase = .unavailable; return }

        phase = .loaded(city: community.name ?? place.city, rows: rows)
    }

    /// English-locale reverse geocode so the city matches eloshowdown's naming.
    private func geocodeCity(lat: Double, lon: Double) async -> (city: String, country: String?)? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: lat, longitude: lon)
        let placemarks = try? await geocoder.reverseGeocodeLocation(location,
                                                                    preferredLocale: Locale(identifier: "en_US"))
        guard let placemark = placemarks?.first, let city = placemark.locality else { return nil }
        return (city, placemark.country)
    }

    /// Match the geocoded city to a community by name, preferring a same-country hit.
    private func resolveCommunity(city: String, country: String?) async throws -> EloCommunity? {
        let all = try await service.communities()
        let matches = all.filter {
            ($0.name ?? "").caseInsensitiveCompare(city) == .orderedSame && ($0.isActive ?? true)
        }
        if let country, matches.count > 1,
           let byCountry = matches.first(where: { ($0.country ?? "").caseInsensitiveCompare(country) == .orderedSame }) {
            return byCountry
        }
        return matches.first
    }
}
