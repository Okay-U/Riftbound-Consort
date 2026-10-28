//
//  BuilderView.swift
//  Riftbound Companiokay
//
//  The builder (Android `BuilderView.kt`, mock `DecksMix`): seven stops on a light rail, a page per stop
//  sliding sideways, Back and Next at the bottom. The first time, a card lists the steps.
//

import SwiftUI

struct RiftBuilderView: View {
    @ObservedObject var model: DeckBuilderModel
    let draft: Draft
    let pool: [Card]
    let cards: [String: Card]
    let onToast: (String) -> Void
    let onSave: (Draft) -> Void
    let onClose: () -> Void
    @Environment(\.riftPage) private var page
    @State private var direction = SlideDirection()

    var body: some View {
        let step = model.step
        let champions = Builder.champions(legend: draft.legend, pool: pool)
        let issues = DeckRules.issues(Builder.toDeck(draft, pool: pool, at: Date()), cards: cards)
        let done = [
            draft.legend != nil, draft.champion != nil, draft.battlefields.count == DeckRules.battlefields,
            draft.mainCount == DeckRules.main, true, draft.runeCount == DeckRules.runes, false,
        ]
        VStack(spacing: 0) {
            HStack {
                PanelIcon(symbol: "xmark", label: "Close the builder", action: onClose)
                Spacer()
                Text("\(draft.editing == nil ? "NEW DECK" : "EDIT DECK") · STEP \(step.rawValue + 1) OF 7")
                    .caps(11.5, tracking: 0.16)
                    .foregroundStyle(.white.opacity(0.66))
                Spacer()
                Color.clear.frame(width: 42, height: 42)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            BuildRail(step: step, done: done, reachable: { i in i <= step.rawValue || (0..<i).allSatisfy { done[$0] || $0 >= 3 } }, onGo: go)
            Text(step.title)
                .font(RiftFont.display(32))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 20)
                .softIn(duration: 0.6)
                .id(step)
            GeometryReader { geo in
                ZStack {
                    page(step, champions: champions, issues: issues)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .id(step)
                        .transition(PageSlide.transition(direction, width: geo.size.width))
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }
            buttons(step, champions: champions, issues: issues)
        }
        .background(page.ignoresSafeArea())
    }

    private func go(_ next: BuildStep) {
        guard next != model.step else { return }
        direction.forward = next.rawValue > model.step.rawValue
        withAnimation(.rift(0.62)) { model.step = next }
    }

    @ViewBuilder
    private func page(_ step: BuildStep, champions: [Card], issues: [String]) -> some View {
        switch step {
        case .legend:
            LegendPage(draft: draft, pool: pool) { legend in
                if let note = model.pickLegend(legend) { onToast(note) }
                Haptics.selection()
            }
        case .champion:
            ChampionPage(draft: draft, champions: champions) { champion in
                model.update(Builder.pickChampion(draft, champion))
                Haptics.selection()
            }
        case .fields: FieldsPage(draft: draft, pool: pool, onToast: onToast, onChange: model.update)
        case .main: PoolPage(draft: draft, pile: .main, pool: pool, cards: cards, onToast: onToast, onChange: model.update)
        case .side: PoolPage(draft: draft, pile: .side, pool: pool, cards: cards, onToast: onToast, onChange: model.update)
        case .runes: RunesPage(draft: draft, onChange: model.update)
        case .save: SavePage(draft: draft, issues: issues) { name in
            var next = draft
            next.name = String(name.prefix(40))
            model.update(next)
        }
        }
    }

    private func buttons(_ step: BuildStep, champions: [Card], issues: [String]) -> some View {
        let noChampions = step == .champion && champions.isEmpty
        let label: String
        switch step {
        case .save: label = draft.editing != nil ? "Save changes" : issues.isEmpty ? "Save deck" : "Save as draft"
        case .main where draft.mainCount < DeckRules.main: label = "Continue · \(draft.mainCount)/\(DeckRules.main)"
        default: label = noChampions ? "Skip" : "Next"
        }
        let enabled: Bool
        switch step {
        case .legend: enabled = draft.legend != nil
        case .champion: enabled = draft.champion != nil || noChampions
        case .save: enabled = !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
        default: enabled = true
        }
        return HStack(spacing: 10) {
            WideButton(text: "Back", enabled: step.rawValue > 0) {
                if let back = BuildStep(rawValue: step.rawValue - 1) { go(back) }
            }
            WideButton(text: label, fill: RiftColor.you, ink: .black, enabled: enabled) {
                if step == .save {
                    onSave(draft)
                } else if let next = BuildStep(rawValue: step.rawValue + 1) {
                    go(next)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 22)
    }
}

/// The builder's page direction, read when a page slides, so the page leaving goes the new way too (a
/// transition built into the old page would still carry the last direction).
final class SlideDirection {
    var forward = true
}

private struct PageSlide: ViewModifier {
    let active: Bool
    let insertion: Bool
    let width: CGFloat
    let direction: SlideDirection

    func body(content: Content) -> some View {
        let sign: CGFloat = direction.forward ? 1 : -1
        content
            .offset(x: active ? (insertion ? sign : -sign) * width : 0)
            .opacity(active ? 0 : 1)
    }

    static func transition(_ direction: SlideDirection, width: CGFloat) -> AnyTransition {
        func slide(_ insertion: Bool) -> AnyTransition {
            .modifier(active: PageSlide(active: true, insertion: insertion, width: width, direction: direction),
                      identity: PageSlide(active: false, insertion: insertion, width: width, direction: direction))
        }
        return .asymmetric(insertion: slide(true), removal: slide(false))
    }
}

/// The light rail: a glowing fill up to the current stop; done stops green with a check, the current one white.
private struct BuildRail: View {
    let step: BuildStep
    let done: [Bool]
    let reachable: (Int) -> Bool
    let onGo: (BuildStep) -> Void

    var body: some View {
        GeometryReader { geo in
            let left: CGFloat = 34
            let span = geo.size.width - left * 2
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.12)).frame(width: span, height: 3).offset(x: left, y: 24)
                RoundedRectangle(cornerRadius: 2)
                    .fill(RiftColor.you)
                    .frame(width: span, height: 3)
                    .shadow(color: RiftColor.you.opacity(0.8), radius: 6)
                    .scaleEffect(x: CGFloat(step.rawValue) / 6, y: 1, anchor: .leading)
                    .offset(x: left, y: 24)
                    .animation(.rift(0.7), value: step)
                ForEach(BuildStep.allCases, id: \.self) { stop in
                    node(stop, x: left + span * CGFloat(stop.rawValue) / 6)
                }
            }
        }
        .frame(height: 74)
        .padding(.top, 6)
    }

    private func node(_ stop: BuildStep, x: CGFloat) -> some View {
        let i = stop.rawValue
        let current = stop == step
        let before = i < step.rawValue
        let fill: Color = current ? .white : before ? RiftColor.you : .white.opacity(0.14)
        let glow: Color = current ? .white.opacity(0.4) : before ? RiftColor.you.opacity(0.7) : .clear
        return ZStack(alignment: .topLeading) {
            Button { onGo(stop) } label: {
                ZStack {
                    Circle().fill(fill)
                    if before && done[i] {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.black)
                    }
                }
                .frame(width: 26, height: 26)
                .overlay { if current { Circle().stroke(RiftColor.you.opacity(0.35), lineWidth: 5).padding(-5) } }
                .shadow(color: glow, radius: current ? 9 : 6)
                .scaleEffect(current ? 1.12 : 1)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .allowsHitTesting(reachable(i))
            .animation(.rift(0.4), value: step)
            .offset(x: x - 22, y: 4)
            .accessibilityLabel("Step \(i + 1), \(stop.label)")
            .accessibilityAddTraits(current ? .isSelected : [])
            Text(stop.label)
                .font(RiftFont.text(10, .semibold))
                .tracking(0.6)
                .foregroundStyle(current ? .white : before ? RiftColor.you.opacity(0.9) : .white.opacity(0.4))
                .frame(width: 80)
                .offset(x: x - 40, y: 46)
                .accessibilityHidden(true)
        }
    }
}
