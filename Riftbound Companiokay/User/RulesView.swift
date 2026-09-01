//
//  RulesView.swift
//  Riftbound Companiokay
//
//  Riot publishes the rules, FAQs, patch notes and errata as separate articles
//  and PDFs across two domains, and players end up hunting for them mid-event.
//  This is a directory, not a copy: every row opens Riot's own page, so nothing
//  here can go stale against the official wording.
//
//  Links use playriftbound.com throughout. The riftbound.leagueoflegends.com
//  equivalents all 301 to it, so pointing at the canonical host saves a hop and
//  survives the old domain being retired.
//

import SwiftUI

struct RulesLink: Identifiable, Hashable {
    let title: String
    let detail: String?
    let url: String
    /// PDFs open in a viewer rather than a page; worth signalling before the tap.
    let isPDF: Bool

    var id: String { url }
    var destination: URL? { URL(string: url) }

    init(_ title: String, _ detail: String? = nil, _ url: String, pdf: Bool = false) {
        self.title = title
        self.detail = detail
        self.url = url
        self.isPDF = pdf
    }
}

enum RulesLibrary {
    static let rules: [RulesLink] = [
        RulesLink("Rules Hub", "Riot's index of current rules documents",
                  "https://playriftbound.com/en-us/rules-hub/"),
        RulesLink("Core Rules", "The full rulebook",
                  "https://cmsassets.rgpub.io/sanity/files/dsfx7636/news_live/e9ac8e3d33e0f78cef296f5945aba7bc1313b086.pdf", pdf: true),
        RulesLink("Tournament Rules", "Event procedure and penalties",
                  "https://cmsassets.rgpub.io/sanity/files/dsfx7636/news_live/503da65669ced10598d62925a6f6bc15111af726.pdf", pdf: true),
        RulesLink("Bans & Restrictions", "Announcing Riftbound's first bans",
                  "https://playriftbound.com/en-us/news/announcements/announcing-riftbounds-first-bans/"),
    ]

    static let faqs: [RulesLink] = [
        RulesLink("Core Rules FAQ", nil,
                  "https://cmsassets.rgpub.io/sanity/files/dsfx7636/news_live/e53e7f4dc1c258c5b203e044e538f101df2cb161.pdf", pdf: true),
        RulesLink("Origins FAQ", nil,
                  "https://playriftbound.com/en-us/news/rules-and-releases/riftbound-origins-faq/"),
        RulesLink("Spiritforged FAQ", nil,
                  "https://playriftbound.com/en-us/news/rules-and-releases/riftbound-spiritforged-faq/"),
        RulesLink("Unleashed FAQ", nil,
                  "https://playriftbound.com/en-us/news/rules-and-releases/unleashed-rules-faq-and-clarifications/"),
        RulesLink("Vendetta FAQ", nil,
                  "https://playriftbound.com/en-us/news/rules-and-releases/vendetta-rules-faq-and-clarifications/"),
    ]

    static let patchNotes: [RulesLink] = [
        RulesLink("Core Rules", nil,
                  "https://playriftbound.com/en-us/news/rules-and-releases/riftbound-core-rules-patch-notes/"),
        RulesLink("Spiritforged", nil,
                  "https://playriftbound.com/en-us/news/rules-and-releases/riftbound-core-rules-spiritforged-patch-notes/"),
        RulesLink("Unleashed", nil,
                  "https://playriftbound.com/en-us/news/rules-and-releases/riftbound-core-rules-unleashed-patch-notes/"),
        RulesLink("Vendetta", nil,
                  "https://playriftbound.com/en-us/news/announcements/core-rules-vendetta-patch-notes/"),
    ]

    static let errata: [RulesLink] = [
        RulesLink("Origins", "33 cards",
                  "https://playriftbound.com/en-us/news/rules-and-releases/riftbound-origins-card-errata/"),
        RulesLink("Spiritforged", "16 cards",
                  "https://playriftbound.com/en-us/news/rules-and-releases/riftbound-spiritforged-errata/"),
        RulesLink("Unleashed", "8 cards",
                  "https://playriftbound.com/en-us/news/rules-and-releases/unleashed-errata-updates/"),
        RulesLink("Vendetta", "8 cards",
                  "https://playriftbound.com/en-us/news/announcements/vendetta-errata-updates/"),
    ]
}

struct RulesView: View {
    var body: some View {
        List {
            Section("Rules") {
                ForEach(RulesLibrary.rules) { row(_: $0) }
            }
            Section("FAQs") {
                ForEach(RulesLibrary.faqs) { row(_: $0) }
            }
            Section("Core rules patch notes") {
                ForEach(RulesLibrary.patchNotes) { row(_: $0) }
            }
            Section {
                ForEach(RulesLibrary.errata) { row(_: $0) }
            } header: {
                Text("Card errata")
            } footer: {
                Text("Errata'd cards are marked in the card database, with the corrected text on the card.")
            }
        }
        .navigationTitle("Rules & FAQs")
    }

    @ViewBuilder
    private func row(_ link: RulesLink) -> some View {
        if let destination = link.destination {
            Link(destination: destination) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(link.title)
                            .foregroundStyle(.primary)
                        if let detail = link.detail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    if link.isPDF {
                        Text("PDF")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    ExternalLinkGlyph()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Drawn rather than `Image(systemName: "arrow.up.right")`: that symbol is not
/// in SkipUI's map and renders as a warning triangle on Android.
struct ExternalLinkGlyph: View {
    var size: CGFloat = 11

    var body: some View {
        ExternalLinkArrow()
            .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

struct ExternalLinkArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        // Shaft, then the corner arrowhead.
        path.move(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: w, y: 0))
        path.move(to: CGPoint(x: w * 0.42, y: 0))
        path.addLine(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w, y: h * 0.58))
        return path
    }
}
