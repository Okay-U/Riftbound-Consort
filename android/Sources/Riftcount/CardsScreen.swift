import SwiftUI

/// Cards tab, ported from the iOS CardsTabView/CardSearchView.
/// Wave 2a scope: gallery grid, name search, sort menu, quick detail.
/// Filter sheet and full detail view follow in 2b.
struct CardsScreen: View {
    @Environment(CardStore.self) var cardStore
    @State var query = ""
    @State var filters = CardFilters()
    @State var primarySort: CardSort = .set
    @State var secondarySort: CardSort? = .energy
    @State var showFilters = false
    @State var showSort = false

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
                    loadingView
                } else if let error = cardStore.loadError {
                    errorView(error)
                } else {
                    galleryView
                }
            }
            .navigationTitle("Cards (\(displayedCards.count))")
            .navigationDestination(for: Card.self) { card in
                CardQuickDetail(card: card)
            }
            .searchable(text: $query, prompt: "Search by name…")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showSort = true } label: {
                        Text("↑↓")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showFilters = true } label: {
                        FilterGlyph(active: filters.isActive)
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                CardFilterSheet(filters: $filters,
                                availableDomains: cardStore.availableDomains)
            }
            .sheet(isPresented: $showSort) {
                CardSortSheet(primarySort: $primarySort, secondarySort: $secondarySort)
            }
            .onAppear { cardStore.loadIfNeeded() }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading card database…")
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Text(error)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Retry") { cardStore.load() }
                .buttonStyle(.bordered)
        }
        .padding()
    }

    /// Cell size computed once out here: GeometryReader inside lazy grid
    /// items gets measured while cells are partially visible on Compose,
    /// which clipped/mislayered rows during scroll.
    private var galleryView: some View {
        GeometryReader { geo in
            let cellW: CGFloat = (geo.size.width - 32) / 3
            let cellH: CGFloat = cellW / 0.72

            ScrollView {
                if displayedCards.isEmpty {
                    Text("No cards match your filters.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                        .frame(maxWidth: .infinity)
                } else {
                    gridView(cellW: cellW, cellH: cellH)
                }
            }
        }
    }

    private func gridView(cellW: CGFloat, cellH: CGFloat) -> some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(displayedCards) { card in
                NavigationLink(value: card) {
                    CardGalleryCell(card: card, width: cellW, height: cellH)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }
}

/// Funnel-style filter icon drawn by hand — the iOS
/// line.3.horizontal.decrease symbols are not in SkipUI's mapped set.
struct FilterGlyph: View {
    let active: Bool

    var body: some View {
        VStack(spacing: 3) {
            Capsule().frame(width: 18, height: 2.5)
            Capsule().frame(width: 12, height: 2.5)
            Capsule().frame(width: 6, height: 2.5)
        }
        .foregroundStyle(active ? Color.accentColor : Color.primary)
        .frame(width: 24, height: 20)
    }
}

struct CardGalleryCell: View {
    let card: Card
    let width: CGFloat
    let height: CGFloat

    private var isBattlefield: Bool {
        card.classification?.type?.lowercased() == "battlefield"
    }

    var body: some View {
        CachedRemoteImage(url: card.media?.imageURL) { image in
            if isBattlefield {
                // Frame as landscape (h × w), then rotate -90° so it fills
                // the portrait (w × h) cell without cropping.
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: height, height: width)
                    .rotationEffect(Angle(degrees: -90))
                    .frame(width: width, height: height)
            } else {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            }
        } placeholder: {
            Color.secondary.opacity(0.15)
                .frame(width: width, height: height)
                .overlay {
                    ProgressView().scaleEffect(0.5)
                }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Minimal card detail for 2a: image + core facts. Full CardDetailView
/// (runes, tags, legality) ports in 2b.
struct CardQuickDetail: View {
    let card: Card
    @State var showAddToDeck = false

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

                VStack(alignment: .leading, spacing: 12) {
                    Text(card.name)
                        .font(.title2.bold())

                    statsRow

                    if let text = card.text?.plain, !text.isEmpty {
                        Text(text)
                            .font(.body)
                    }

                    if let flavour = card.text?.flavour, !flavour.isEmpty {
                        Text(flavour)
                            .font(.footnote.italic())
                            .foregroundStyle(.secondary)
                    }

                    if let artist = card.media?.artist {
                        Text("Art by \(artist)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let label = card.set?.label {
                        Text(label)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
        }
        .navigationTitle(card.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddToDeck = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddToDeck) {
            AddToDeckSheet(card: card)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            if let type = card.classification?.type {
                statBadge(label: type)
            }
            if let rarity = card.classification?.rarity {
                statBadge(label: rarity)
            }
            if let energy = card.attributes?.energy {
                statBadge(label: "⚡ \(energy)")
            }
            if let power = card.attributes?.power {
                statBadge(label: "♻ \(power)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statBadge(label: String) -> some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.secondary.opacity(0.2)))
    }
}

/// Sort options as a proper sheet — the old toolbar Menu rendered as a bare
/// two-line dropdown that read like a debug popup.
struct CardSortSheet: View {
    @Binding var primarySort: CardSort
    @Binding var secondarySort: CardSort?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(title: "Sort") { dismiss() }

                sectionTitle("Sort by")
                VStack(spacing: 8) {
                    ForEach(CardSort.allCases) { option in
                        sortRow(option.label, selected: primarySort == option) {
                            primarySort = option
                        }
                    }
                }
                .padding(.horizontal, 16)

                sectionTitle("Then by")
                VStack(spacing: 8) {
                    sortRow("None", selected: secondarySort == nil) {
                        secondarySort = nil
                    }
                    ForEach(CardSort.allCases) { option in
                        sortRow(option.label, selected: secondarySort == option) {
                            secondarySort = option
                        }
                    }
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 24)
            }
        }
        .presentationDetents([.fraction(0.85)])
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
    }

    private func sortRow(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack {
                Text(label)
                    .font(.system(size: 15, weight: selected ? .semibold : .regular))
                    .foregroundStyle(.white)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
}
