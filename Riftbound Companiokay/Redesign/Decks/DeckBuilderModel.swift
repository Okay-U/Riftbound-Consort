//
//  DeckBuilderModel.swift
//  Riftbound Companiokay
//
//  What the Decks tab keeps while the builder is open (Android `DecksUi`): the draft, its step and a card from
//  the Cards tab that joins the deck once a legend it fits is picked. Lives at the redesign's root, so Cards'
//  "New deck with this card" can start it.
//

import Foundation
internal import Combine

@MainActor
final class DeckBuilderModel: ObservableObject {
    @Published private(set) var draft: Draft?
    @Published var step: BuildStep = .legend
    /// A card from the Cards tab that joins the deck once a legend it fits is picked.
    @Published private(set) var pending: Card?

    /// New deck; a legend starts it, any other card waits for a legend it fits.
    func start(with card: Card? = nil) {
        pending = nil
        if let card, card.isLegend {
            draft = Builder.pickLegend(Draft(), card)
            step = .champion
        } else {
            draft = Draft()
            step = .legend
            pending = card
        }
    }

    func edit(_ draft: Draft) {
        pending = nil
        self.draft = draft
        step = .main
    }

    func update(_ draft: Draft) { self.draft = draft }

    /// The legend pick, with the waiting card added when it fits; returns a note for the toast.
    func pickLegend(_ legend: Card) -> String? {
        var next = Builder.pickLegend(draft ?? Draft(), legend)
        guard let card = pending else {
            draft = next
            return nil
        }
        let champion = card.isChampionUnit && card.matchesLegend(legend)
        let fits = champion || DeckRules.eligible(card, legendDomains: Set(next.domains.map { $0.lowercased() }))
        if champion {
            next = Builder.pickChampion(next, card)
        } else if fits {
            next = Builder.add(next, .main, card)
        }
        draft = next
        if fits { pending = nil }
        return fits ? "\(card.title) is in the deck" : "\(card.title) does not fit \(legend.title)'s domains"
    }

    func close() {
        draft = nil
        pending = nil
        step = .legend
    }
}
