//
//  InfoPages.swift
//  Riftbound Companiokay
//
//  Settings' text pages (Android `InfoPages.kt`): report a bug or wish a feature through the mail app, the
//  acknowledgments with the fonts' licences to read in place, and Riot's rules documents.
//

import SwiftUI
import UIKit

private struct FootNote: View {
    let text: String

    var body: some View {
        Text(text).font(RiftFont.text(12.5, .regular)).lineSpacing(4).foregroundStyle(.white.opacity(0.55))
    }
}

// MARK: - Bug and wish

/// Report a bug / Wish a feature: a summary and the details, sent through the mail app.
struct FormPage: View {
    let bug: Bool
    let onToast: (String) -> Void
    @State private var summary = ""
    @State private var details = ""
    @State private var composing = false
    @State private var appeared = false

    var body: some View {
        let label = bug ? "What happened" : "Describe it"
        VStack(alignment: .leading, spacing: 0) {
            FootNote(text: bug
                     ? "Tell me what went wrong. Your mail app opens with the report filled in, you can read it before sending."
                     : "What would make Riftcount better for you? One idea per wish works best.")
                .padding(.horizontal, 4)
                .padding(.top, 8)
            CapsLabel(text: "Summary", size: 11).padding(.leading, 4).padding(.top, 18).padding(.bottom, 8)
            FormField(text: $summary, placeholder: bug ? "Score jumped back after undo" : "Show my opponent’s deck after the match", height: 52, single: true)
            CapsLabel(text: label, size: 11).padding(.leading, 4).padding(.top, 18).padding(.bottom, 8)
            FormField(text: $details, placeholder: bug ? "Steps, what you expected, what you saw" : "How would it work, when would you use it?", height: 180, single: false)
            WideButton(text: bug ? "Send report" : "Send wish", fill: RiftColor.you, ink: .black,
                       enabled: !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, action: send)
                .padding(.top, 12)
        }
        .riseIn(appeared, delay: 0)
        .onAppear { appeared = true }
        .sheet(isPresented: $composing) {
            MailComposer(subject: subject, recipient: SupportConfig.supportEmail, body: mailBody(label))
                .ignoresSafeArea()
        }
    }

    private var subject: String { "\(bug ? "[Bug]" : "[Feature]") \(summary.trimmingCharacters(in: .whitespacesAndNewlines))" }

    private func mailBody(_ label: String) -> String {
        let text = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let version = "\(Bundle.main.appVersion) (\(Bundle.main.appBuild))"
        return "Title: \(summary.trimmingCharacters(in: .whitespacesAndNewlines))\n\n\(bug ? label : "Description"):\n\(text.isEmpty ? "-" : text)\n\nRiftcount \(version) · iOS \(UIDevice.current.systemVersion)"
    }

    private func send() {
        if MailComposer.canSendMail {
            composing = true
            return
        }
        var parts = URLComponents()
        parts.scheme = "mailto"
        parts.path = SupportConfig.supportEmail
        parts.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: mailBody(bug ? "What happened" : "Describe it"))]
        guard let url = parts.url else {
            onToast("No mail app · write to \(SupportConfig.supportEmail)")
            return
        }
        UIApplication.shared.open(url) { opened in
            if opened {
                onToast(bug ? "Opens your mail app with the report" : "Thanks! Opens your mail app")
            } else {
                onToast("No mail app · write to \(SupportConfig.supportEmail)")
            }
        }
    }
}

/// The form's inputs: 52pt line or a 180pt box, the green ring while typing.
private struct FormField: View {
    @Binding var text: String
    let placeholder: String
    let height: CGFloat
    let single: Bool
    @FocusState private var focused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18)
        Group {
            if single {
                TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.4)))
                    .font(RiftFont.text(16, .regular))
                    .padding(.horizontal, 16)
            } else {
                TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.4)), axis: .vertical)
                    .font(RiftFont.text(15, .regular))
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .foregroundStyle(.white)
        .tint(RiftColor.you)
        .textInputAutocapitalization(.sentences)
        .focused($focused)
        .frame(height: height)
        .background(Color(hex: "0B0B0B"), in: shape)
        .overlay(shape.stroke(focused ? RiftColor.you.opacity(0.6) : .white.opacity(0.16), lineWidth: 1))
        .background(RoundedRectangle(cornerRadius: 22).fill(RiftColor.you.opacity(focused ? 0.1 : 0)).padding(-4))
        .animation(.easeInOut(duration: 0.25), value: focused)
        .contentShape(shape)
        .onTapGesture { focused = true }
    }
}

// MARK: - Acknowledgments

/// Riot, the rune icons and the two OFL fonts, each licence to read in place.
struct AckPage: View {
    @Environment(\.openURL) private var openURL
    @State private var license: String?
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AckCard(title: "Riot Games",
                    text: "Card data and images from the official Riftbound card gallery. Riftcount was created under Riot Games' \"Legal Jibber Jabber\" policy using assets owned by Riot Games. Riot Games does not endorse or sponsor this project.") {
                AckLink(text: "playriftbound.com") { open("https://playriftbound.com/en-us/card-gallery/") }
            }
            .riseIn(appeared, delay: 0.06)
            AckCard(title: "riftboundfaq", text: "Domain rune icons by Christian Ivicevic, used under CC BY-SA 4.0.") {
                AckLink(text: "github.com/ChristianIvicevic/riftboundfaq") { open("https://github.com/ChristianIvicevic/riftboundfaq") }
                AckLink(text: "CC BY-SA 4.0") { open("https://creativecommons.org/licenses/by-sa/4.0/") }
            }
            .riseIn(appeared, delay: 0.12)
            AckCard(title: "Fonts", text: "Big Shoulders Display and Barlow, used under the SIL Open Font License 1.1.") {
                licenseLink("Big Shoulders Display license", file: "OFL_big_shoulders_display")
                licenseLink("Barlow license", file: "OFL_barlow")
            }
            .riseIn(appeared, delay: 0.18)
            FootNote(text: "Riftbound is a trademark of Riot Games. This app is an unofficial fan project and is not affiliated with Riot Games.")
                .padding(.horizontal, 6)
                .padding(.top, 6)
        }
        .onAppear { appeared = true }
    }

    private func open(_ link: String) {
        if let url = URL(string: link) { openURL(url) }
    }

    @ViewBuilder
    private func licenseLink(_ name: String, file: String) -> some View {
        AckLink(text: license == file ? "Hide the \(name)" : name) {
            withAnimation(.easeInOut(duration: 0.3)) { license = license == file ? nil : file }
        }
        if license == file {
            Text(Self.licenseText(file))
                .font(RiftFont.text(12, .regular))
                .lineSpacing(4)
                .foregroundStyle(.white.opacity(0.66))
                .padding(.vertical, 8)
                .textSelection(.enabled)
        }
    }

    private static func licenseText(_ file: String) -> String {
        guard let url = Bundle.main.url(forResource: file, withExtension: "txt"), let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "The licence text is at openfontlicense.org."
        }
        return reflow(text)
    }

    /// The licence files wrap at 72 columns; joined into paragraphs they reflow on any width. Rules of dashes
    /// go, headings in capitals keep a line of their own.
    static func reflow(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n").filter { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            return t.isEmpty || !t.allSatisfy { $0 == "-" }
        }
        let marked = lines.map { line -> String in
            let t = line.trimmingCharacters(in: .whitespaces)
            let heading = !t.isEmpty && t.allSatisfy { $0.isUppercase || $0 == " " || $0 == "&" }
            return heading ? line + "\n" : line
        }
        .joined(separator: "\n")
        return marked.replacingOccurrences(of: #"\n\s*\n"#, with: "\u{0}", options: .regularExpression)
            .components(separatedBy: "\u{0}")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: #"\s*\n\s*"#, with: " ", options: .regularExpression) }
            .joined(separator: "\n\n")
    }
}

private struct AckCard<Links: View>: View {
    let title: String
    let text: String
    @ViewBuilder let links: () -> Links

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22)
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(RiftFont.text(16, .bold)).foregroundStyle(.white)
            Text(text)
                .font(RiftFont.text(13.5, .regular))
                .lineSpacing(5)
                .foregroundStyle(.white.opacity(0.72))
                .padding(.top, 6)
                .padding(.bottom, 2)
            links()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.045), in: shape)
        .overlay(shape.stroke(.white.opacity(0.08), lineWidth: 1))
    }
}

private struct AckLink: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text).font(RiftFont.text(13, .semibold)).foregroundStyle(RiftColor.you).padding(.vertical, 4)
        }
        .buttonStyle(PressScale(scale: 0.97))
    }
}

// MARK: - Rules

/// Riot's documents by kind (classic `RulesView`), each row opening Riot's own page.
struct RulesPage: View {
    @Environment(\.openURL) private var openURL
    @State private var appeared = false

    var body: some View {
        let sections: [(title: String, links: [RulesLink], footer: String?)] = [
            ("Rules", RulesLibrary.rules, nil),
            ("FAQs", RulesLibrary.faqs, nil),
            ("Core rules patch notes", RulesLibrary.patchNotes, nil),
            ("Card errata", RulesLibrary.errata, "Errata'd cards are marked in the card database, with the corrected text on the card."),
        ]
        VStack(alignment: .leading, spacing: 0) {
            FootNote(text: "Riot's documents open in your browser.").padding(.horizontal, 4).padding(.top, 6).padding(.bottom, 6)
            ForEach(Array(sections.enumerated()), id: \.offset) { s, section in
                VStack(alignment: .leading, spacing: 0) {
                    SectionHead(title: section.title)
                    SettingsGroup {
                        ForEach(Array(section.links.enumerated()), id: \.element.id) { i, link in
                            LinkRow(title: link.title, symbol: nil, sub: link.detail, divider: i > 0, external: true) {
                                if link.isPDF {
                                    Text("PDF").font(RiftFont.text(10, .bold)).foregroundStyle(.white.opacity(0.5))
                                }
                            } action: {
                                if let url = link.destination { openURL(url) }
                            }
                        }
                    }
                    if let footer = section.footer { FootNote(text: footer).padding(.horizontal, 6).padding(.top, 8) }
                }
                .padding(.top, s == 0 ? 8 : 22)
                .riseIn(appeared, delay: 0.06 + Double(s) * 0.07)
            }
        }
        .onAppear { appeared = true }
    }
}
