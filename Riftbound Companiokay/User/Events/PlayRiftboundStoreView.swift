//
//  PlayRiftboundStoreView.swift
//  Riftbound Companiokay
//
//  One store: contact card from OrganizerSummary, favourite toggle, and its
//  upcoming events (the search centred on the store).
//

import SwiftUI

struct PlayRiftboundStoreView: View {
    let organizer: CompeteOrganizer

    @EnvironmentObject private var browser: PlayRiftboundBrowser
    @EnvironmentObject private var events: PlayRiftboundEventsStore
    @State private var summary: CompeteOrganizerSummary?
    @State private var upcoming: [CompeteSearchResult] = []
    @State private var isFavorite: Bool
    @State private var signedIn = false
    @State private var loading = true
    @State private var error: String?

    private let api = PlayRiftboundAPI()

    init(organizer: CompeteOrganizer) {
        self.organizer = organizer
        _isFavorite = State(initialValue: organizer.isFavorited ?? false)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if let summary { contact(summary) }
                calendar
            }
            .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 24)
        }
        .background(EventsTheme.bg.ignoresSafeArea())
        .navigationTitle(organizer.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(EventsTheme.bg, for: .navigationBar)
        .refreshable { await load() }
        .task { await load() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(organizer.name).font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                if let address = summary?.physicalAddress?.formattedAddress ?? organizer.physicalAddress?.formattedAddress {
                    Text(address).font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
                }
            }
            Spacer()
            if signedIn {
                Button { Task { await toggleFavorite() } } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isFavorite ? EventsTheme.green : EventsTheme.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(EventsTheme.cardInset, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFavorite ? "Remove from favourites" : "Add to favourites")
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .eventsCard()
    }

    private func contact(_ s: CompeteOrganizerSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("phone", "Contact")
            VStack(spacing: 0) {
                if let lat = s.physicalAddress?.latitude, let lng = s.physicalAddress?.longitude,
                   let url = URL(string: "https://maps.apple.com/?ll=\(lat),\(lng)&q=\(organizer.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Store")") {
                    contactRow("map", "Directions", url: url)
                }
                if let website = s.website, let url = URL(string: website.hasPrefix("http") ? website : "https://" + website) {
                    contactRow("globe", website.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: ""), url: url)
                }
                if let email = s.email, let url = URL(string: "mailto:\(email)") { contactRow("envelope", email, url: url) }
                if let phone = s.phone?.display, let url = URL(string: "tel:\(phone.filter { !$0.isWhitespace })") { contactRow("phone", phone, url: url) }
            }
            .eventsCard(radius: 15)
        }
    }

    private func contactRow(_ symbol: String, _ text: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 14)).foregroundStyle(EventsTheme.green).frame(width: 22)
                Text(text).font(.system(size: 14)).foregroundStyle(.white).lineLimit(1)
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 11)).foregroundStyle(EventsTheme.textTertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
        }
    }

    private var calendar: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("calendar", "Upcoming events") {
                if !upcoming.isEmpty { Text("\(upcoming.count)").foregroundStyle(EventsTheme.textTertiary) }
            }
            if loading {
                ProgressView().tint(EventsTheme.green).frame(maxWidth: .infinity).padding(.top, 10)
            } else if let error {
                Text(error).font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
            } else if upcoming.isEmpty {
                Text("No upcoming events listed for this store.").font(.system(size: 13)).foregroundStyle(EventsTheme.textSecondary)
            } else {
                let registered = Set(events.upcoming.map(\.tournament.id))
                ForEach(upcoming, id: \.tournament.id) { result in
                    NavigationLink(value: result.entry) {
                        PlayRiftboundEventCard(entry: result.entry, registered: registered.contains(result.tournament.id))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Loading

    private func load() async {
        loading = upcoming.isEmpty
        error = nil
        let credentials = try? await PlayRiftboundSession.validCredentials(refreshingVia: browser)
        signedIn = credentials != nil
        do {
            if summary == nil { summary = try await api.organizerSummary(id: organizer.id, credentials: credentials) }
            let lat = summary?.physicalAddress?.latitude ?? organizer.physicalAddress?.latitude
            let lng = summary?.physicalAddress?.longitude ?? organizer.physicalAddress?.longitude
            if let lat, let lng {
                upcoming = try await api.storeEvents(organizerID: organizer.id, latitude: lat, longitude: lng, credentials: credentials)
                    .sorted { ($0.tournament.startsAt ?? .distantFuture) < ($1.tournament.startsAt ?? .distantFuture) }
            } else {
                error = "This store has no location on PlayRiftbound, so its events can't be listed."
            }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        loading = false
    }

    private func toggleFavorite() async {
        guard let credentials = try? await PlayRiftboundSession.validCredentials(refreshingVia: browser) else { return }
        let target = !isFavorite
        isFavorite = target
        do { try await api.setFavorite(organizerID: organizer.id, on: target, credentials: credentials) }
        catch { isFavorite = !target; self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
    }
}
