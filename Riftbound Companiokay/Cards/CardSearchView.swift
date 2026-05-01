//
//  CardSearchView.swift
//  Riftbound Companiokay
//

import SwiftUI

struct CardSearchView: View {
    @EnvironmentObject var cardStore: CardStore
    @EnvironmentObject var decklistStore: DecklistStore

    @State private var query = ""
    @State private var filters = CardFilters()
    @State private var primarySort: CardSort = .set
    @State private var secondarySort: CardSort? = .energy
    @State private var showFilters = false

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    private var displayedCards: [Card] {
        cardStore.filtered(query: query,
                           filters: filters,
                           primarySort: primarySort,
                           secondarySort: secondarySort)
    }

    var body: some View {
        Group {
            if cardStore.isLoading && cardStore.allCards.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading card database…")
                        .foregroundStyle(.secondary)
                }
            } else if let error = cardStore.loadError {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Retry") { cardStore.load() }
                        .buttonStyle(.bordered)
                }
                .padding()
            } else {
                ScrollView {
                    if displayedCards.isEmpty {
                        Text("No cards match your filters.")
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                            .frame(maxWidth: .infinity)
                    } else {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(displayedCards) { card in
                                NavigationLink(destination:
                                    CardDetailView(card: card)
                                        .environmentObject(decklistStore)
                                ) {
                                    CardGalleryCell(card: card)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .navigationTitle("Cards (\(displayedCards.count))")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search by name…")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Sort by", selection: $primarySort) {
                        ForEach(CardSort.allCases) { option in
                            Label(option.label, systemImage: option.systemImage)
                                .tag(option)
                        }
                    }
                    Picker("Then by", selection: $secondarySort) {
                        Text("None").tag(CardSort?.none)
                        ForEach(CardSort.allCases) { option in
                            Label(option.label, systemImage: option.systemImage)
                                .tag(CardSort?.some(option))
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showFilters = true } label: {
                    Image(systemName: filters.isActive
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showFilters) {
            CardFilterSheet(filters: $filters,
                            availableDomains: cardStore.availableDomains)
        }
        .onAppear { cardStore.loadIfNeeded() }
    }
}

struct CardGalleryCell: View {
    let card: Card

    private var isBattlefield: Bool {
        card.classification?.type?.lowercased() == "battlefield"
    }

    var body: some View {
        // Use a clear placeholder to fix the cell size, then overlay the image.
        // This lets GeometryReader read the real pixel dimensions so we can
        // swap w/h for battlefield cards before rotating.
        Color.clear
            .aspectRatio(0.72, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height

                    CachedRemoteImage(url: card.media?.imageURL) { image in
                        if isBattlefield {
                            // Frame as landscape (h × w), then rotate -90° so it
                            // fills the portrait (w × h) cell without cropping.
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: h, height: w)
                                .rotationEffect(.degrees(-90))
                                .frame(width: w, height: h)
                        } else {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: w, height: h)
                                .clipped()
                        }
                    } placeholder: {
                        Color.secondary.opacity(0.15)
                            .frame(width: w, height: h)
                            .overlay {
                                ProgressView().scaleEffect(0.5)
                            }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
