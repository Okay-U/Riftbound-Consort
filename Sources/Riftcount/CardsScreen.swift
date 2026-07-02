import SwiftUI

/// Cards tab, ported from the iOS CardsTabView/CardSearchView.
/// Wave 2a scope: gallery grid, name search, sort menu, quick detail.
/// Filter sheet and full detail view follow in 2b.
struct CardsScreen: View {
    @State var cardStore = CardStore()
    @State var query = ""
    @State var filters = CardFilters()
    @State var primarySort: CardSort = .set
    @State var secondarySort: CardSort? = .energy

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    private var displayedCards: [Card] {
        cardStore.filtered(query: query,
                           filters: filters,
                           primarySort: primarySort,
                           secondarySort: secondarySort)
    }

    var body: some View {
        NavigationStack {
            Group {
                if cardStore.isLoading && cardStore.allCards.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading card database…")
                            .foregroundStyle(.secondary)
                    }
                } else if let error = cardStore.loadError {
                    VStack(spacing: 12) {
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
                                    NavigationLink(value: card) {
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
            .navigationDestination(for: Card.self) { card in
                CardQuickDetail(card: card)
            }
            .searchable(text: $query, prompt: "Search by name…")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Sort by", selection: $primarySort) {
                            ForEach(CardSort.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        Picker("Then by", selection: $secondarySort) {
                            Text("None").tag(CardSort?.none)
                            ForEach(CardSort.allCases) { option in
                                Text(option.label).tag(CardSort?.some(option))
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .onAppear { cardStore.loadIfNeeded() }
        }
    }
}

struct CardGalleryCell: View {
    let card: Card

    private var isBattlefield: Bool {
        card.classification?.type?.lowercased() == "battlefield"
    }

    var body: some View {
        // Clear placeholder fixes the cell size; GeometryReader reads real
        // dimensions so battlefield cards can swap w/h before rotating.
        Color.clear
            .aspectRatio(0.72, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height

                    CachedRemoteImage(url: card.media?.imageURL) { image in
                        if isBattlefield {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: h, height: w)
                                .rotationEffect(Angle(degrees: -90))
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

/// Minimal card detail for 2a: image + core facts. Full CardDetailView
/// (runes, tags, legality) ports in 2b.
struct CardQuickDetail: View {
    let card: Card

    private var isBattlefield: Bool {
        card.classification?.type?.lowercased() == "battlefield"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CachedRemoteImage(url: card.media?.imageURL) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    Color.secondary.opacity(0.15)
                        .aspectRatio(isBattlefield ? 1.39 : 0.72, contentMode: .fit)
                        .overlay { ProgressView() }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text(card.name)
                        .font(.title2.bold())

                    if let type = card.classification?.type {
                        Text([type, card.classification?.rarity]
                            .compactMap { $0 }
                            .joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let text = card.text?.plain, !text.isEmpty {
                        Text(text)
                            .font(.body)
                            .padding(.top, 4)
                    }

                    if let flavour = card.text?.flavour, !flavour.isEmpty {
                        Text(flavour)
                            .font(.footnote.italic())
                            .foregroundStyle(.secondary)
                    }

                    if let label = card.set?.label {
                        Text(label)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
        }
        .navigationTitle(card.name)
    }
}
