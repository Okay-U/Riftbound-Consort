//
//  RiftCardsView.swift
//  Riftbound Companiokay
//
//  The redesign's Cards tab (Android `CardsScreen.kt`, `CardsChrome.kt`, mock `CardsFinal`): the count in the
//  header, the search with its green ring, All plus six domain discs, Set · Energy · Type and the Filter
//  button with its badge, a three-column grid whose first 15 tiles rise in on every search or filter
//  change. A tile grows into the card's detail.
//

import SwiftUI
import UIKit

struct RiftCardsView: View {
    @EnvironmentObject private var cards: CardStore
    @EnvironmentObject private var errata: ErrataStore
    @EnvironmentObject private var decks: DecklistStore
    @EnvironmentObject private var shortlist: ShortlistStore
    @Environment(\.riftPage) private var page

    @State private var query = ""
    @State private var filters = CardFilters()
    @State private var sort: CardSort = .set
    @State private var shown: [Card] = []
    @State private var appliedKey: AppliedKey?
    /// Tiles play their entrance when this changes (tab opened, search or filters changed).
    @State private var generation = 0
    @State private var generationAt = Date.distantPast
    @State private var filtering = false
    @State private var replayPending = false
    @State private var open: Card?
    @State private var adding = false
    @Namespace private var hero

    private struct AppliedKey: Equatable {
        let query: String
        let filters: CardFilters
        let sort: CardSort
    }

    private struct QueryKey: Equatable {
        let applied: AppliedKey
        let kept: Set<String>
        let revision: Int
    }

    private var queryKey: QueryKey {
        QueryKey(applied: AppliedKey(query: query, filters: filters, sort: sort),
                 kept: filters.shortlistOnly ? Set(shortlist.ids) : [], revision: cards.revision)
    }

    var body: some View {
        GeometryReader { geo in
            // Three columns on a phone like the mock, more on a wider screen (tiles stay about 100pt).
            let columns = max(3, Int((geo.size.width - 22) / 106))
            let tile = (geo.size.width - 32 - 10 * CGFloat(columns - 1)) / CGFloat(columns)
            ZStack {
                VStack(spacing: 0) {
                    header
                    RiftSearchField(text: $query).padding(.horizontal, 16).padding(.top, 16)
                    DomainDiscs(selected: filters.domains) { filters.domains = $0 }
                        .padding(.horizontal, 12)
                        .padding(.top, 16)
                    CardControls(sort: $sort, active: sheetCount) { filtering = true }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                    content(columns: columns, tile: tile)
                }
                .opacity(open == nil ? 1 : 0.16)
                if let open {
                    CardDetailOverlay(
                        card: open, hero: hero, erratum: errata.erratum(for: open),
                        inDecks: decks.lists.filter { DeckRules.count(open, in: $0) > 0 }.count,
                        onClose: close, onAdd: { adding = true }
                    )
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
        .background(page.ignoresSafeArea())
        .toolbar(open == nil ? .visible : .hidden, for: .tabBar)
        .onAppear {
            cards.loadIfNeeded()
            replay()
        }
        .task(id: queryKey) { await apply() }
        .sheet(isPresented: $filtering, onDismiss: {
            if replayPending {
                replayPending = false
                replay()
            }
        }) {
            RiftFilterSheet(filters: $filters, count: liveCount)
        }
        .sheet(isPresented: $adding) {
            if let open { RiftAddToDeckSheet(card: open) }
        }
    }

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("Cards").font(RiftFont.display(46)).tracking(0.9).foregroundStyle(.white)
            Spacer()
            if !cards.allCards.isEmpty {
                Text((shown.count == 1 ? "1 card" : "\(shown.count) cards").uppercased())
                    .caps(12)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    @ViewBuilder private func content(columns: Int, tile: CGFloat) -> some View {
        if cards.allCards.isEmpty {
            LoadState(error: cards.loadError, onRetry: { cards.loadIfNeeded() })
        } else if shown.isEmpty && appliedKey != nil {
            VStack(spacing: 6) {
                Text("No cards match.").font(RiftFont.text(15, .semibold)).foregroundStyle(.white.opacity(0.8))
                Button("Clear search and filters") {
                    query = ""
                    filters = CardFilters()
                }
                .font(RiftFont.text(14, .semibold))
                .foregroundStyle(RiftColor.you)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
            Spacer()
        } else {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(tile), spacing: 10), count: columns), spacing: 10) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, card in
                        tileButton(card, index: index, width: tile)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.immediately)
            // A new search starts at the top, its tiles rising in again.
            .id(generation)
        }
    }

    private func tileButton(_ card: Card, index: Int, width: CGFloat) -> some View {
        Button {
            openCard(card)
        } label: {
            ZStack {
                if open?.id != card.id {
                    CardTile(card: card, errata: errata.erratum(for: card) != nil, imageWidth: width)
                        .matchedGeometryEffect(id: card.id, in: hero)
                }
            }
            .frame(width: width, height: width / cardAspect)
        }
        .buttonStyle(PressScale(scale: 0.96))
        .modifier(TileEntrance(index: index, play: Date().timeIntervalSince(generationAt) < 0.4))
        .accessibilityLabel(tileLabel(card))
    }

    private func tileLabel(_ card: Card) -> String {
        var label = "\(card.name), \(CardStyle.kind(card))"
        if let energy = card.attributes?.energy { label += ", \(energy) energy" }
        return label
    }

    private func openCard(_ card: Card) {
        guard open == nil else { return }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.rift(0.68)) { open = card }
    }

    private func close() {
        adding = false
        withAnimation(.timingCurve(0.2, 0, 0, 1, duration: 0.54)) { open = nil }
    }

    private func replay() {
        generation += 1
        generationAt = Date()
    }

    /// Filtering 1400 cards per keystroke or slider step is wasted work: wait for a pause.
    private func apply() async {
        let key = queryKey
        if !shown.isEmpty {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
        }
        shown = cards.filtered(query: query, filters: filters, primarySort: sort, secondarySort: .energy, shortlist: key.kept)
        if key.applied != appliedKey {
            if appliedKey != nil {
                if filtering { replayPending = true } else { replay() }
            }
            appliedKey = key.applied
        }
    }

    /// The filter sheet's live "Show N cards".
    private var liveCount: Int {
        cards.filtered(query: query, filters: filters, primarySort: sort, secondarySort: nil, shortlist: Set(shortlist.ids)).count
    }

    /// Filters set in the sheet (the domain discs are outside it).
    private var sheetCount: Int {
        var n = filters.types.count + filters.series.count + filters.rarities.count + (filters.shortlistOnly ? 1 : 0)
        if filters.minEnergy > 0 || filters.maxEnergy < CardFilters.energyCap { n += 1 }
        if filters.minPower > 0 || filters.maxPower < CardFilters.powerCap { n += 1 }
        if filters.minMight > 0 || filters.maxMight < CardFilters.mightCap { n += 1 }
        return n
    }
}

/// Staggered rise of the first 15 tiles; tiles that scroll in later just appear.
private struct TileEntrance: ViewModifier {
    let index: Int
    @State private var shown: Bool

    init(index: Int, play: Bool) {
        self.index = index
        _shown = State(initialValue: !(play && index < 15))
    }

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .scaleEffect(shown ? 1 : 0.96)
            .blur(radius: shown ? 0 : 6)
            .onAppear {
                guard !shown else { return }
                withAnimation(.rift(0.76).delay(Double(min(index, 14)) * 0.034)) { shown = true }
            }
    }
}

private struct LoadState: View {
    let error: String?
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(error ?? "Loading card database…")
                .font(RiftFont.text(15))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
            if error != nil { Pill(text: "Retry", height: 44, action: onRetry) }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 80)
        Spacer()
    }
}

/// "All" plus the six domains as glowing discs; several domains can be on at once.
private struct DomainDiscs: View {
    let selected: Set<String>
    let onChange: (Set<String>) -> Void

    var body: some View {
        HStack(spacing: 0) {
            disc(label: "All", on: selected.isEmpty, color: .white, glyph: nil) { onChange([]) }
            ForEach(CardStyle.domainsInOrder, id: \.self) { domain in
                disc(label: domain, on: selected.contains(domain), color: CardStyle.domainColor(domain), glyph: CardStyle.glyph(domain)) {
                    var next = selected
                    if next.contains(domain) { next.remove(domain) } else { next.insert(domain) }
                    onChange(next)
                }
            }
        }
    }

    private func disc(label: String, on: Bool, color: Color, glyph: String?, action: @escaping () -> Void) -> some View {
        let t: Double = on ? 1 : 0
        let ink = color.mix(with: .black, by: t)
        return Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.04).mix(with: color, by: t))
                    Circle().stroke(Color.white.opacity(0.18).mix(with: color, by: t), lineWidth: 1)
                    if let glyph {
                        Image(glyph).renderingMode(.template).resizable().scaledToFit().frame(width: 22, height: 22).foregroundStyle(ink)
                    } else {
                        Text("All").font(RiftFont.display(13, weight: 800)).tracking(1).foregroundStyle(ink)
                    }
                }
                .frame(width: 44, height: 44)
                .shadow(color: color.opacity(0.6 * t), radius: 11)
                Text(label.uppercased())
                    .caps(10, tracking: 0.12)
                    .foregroundStyle(Color.white.opacity(0.62).mix(with: .white, by: t))
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale(scale: 0.9))
        .animation(.easeInOut(duration: 0.35), value: on)
        .accessibilityLabel(glyph == nil ? "All domains" : "Domain \(label)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Sort switch (Set · Energy · Type) and the Filter button with its count of active filters.
private struct CardControls: View {
    @Binding var sort: CardSort
    let active: Int
    let onFilter: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            SortSwitch(sort: $sort)
            Spacer(minLength: 0)
            Button(action: onFilter) {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease").font(.system(size: 15, weight: .semibold))
                    Text("Filter").font(RiftFont.text(13, .semibold))
                    if active > 0 {
                        Text("\(active)")
                            .font(RiftFont.text(11, .bold))
                            .foregroundStyle(.black)
                            .frame(minWidth: 20, minHeight: 20)
                            .padding(.horizontal, 2)
                            .background(RiftColor.you, in: Capsule())
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
                .foregroundStyle(.white)
                .padding(.leading, 12)
                .padding(.trailing, 14)
                .frame(height: 40)
                .background(.white.opacity(0.06), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
                .contentShape(Capsule())
            }
            .buttonStyle(PressScale(scale: 0.95))
            .animation(.rift(0.42), value: active > 0)
            .accessibilityLabel(active > 0 ? "Filter, \(active) active" : "Filter")
        }
    }
}

/// 230pt like the mock, narrower when a small phone has less room.
private struct SortSwitch: View {
    @Binding var sort: CardSort
    private let options: [(CardSort, String)] = [(.set, "Set"), (.energy, "Energy"), (.type, "Type")]

    var body: some View {
        GeometryReader { geo in
            let thumb = (geo.size.width - 6) / CGFloat(options.count)
            let index = CGFloat(options.firstIndex { $0.0 == sort } ?? 0)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 16).fill(.white).frame(width: thumb, height: 32).offset(x: 3 + index * thumb)
                HStack(spacing: 0) {
                    ForEach(options, id: \.0) { option, label in
                        Button { sort = option } label: {
                            Text(label)
                                .font(RiftFont.text(13, .semibold))
                                .foregroundStyle(option == sort ? Color.black : .white.opacity(0.78))
                                .frame(width: thumb, height: 40)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(option == sort ? [.isSelected, .isButton] : .isButton)
                    }
                }
                .padding(.horizontal, 3)
            }
            .animation(.rift(0.52), value: sort)
        }
        .frame(maxWidth: 230)
        .frame(height: 40)
        .background(.white.opacity(0.07), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
    }
}
