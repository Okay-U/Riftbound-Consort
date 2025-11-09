//
//  BugReportView.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 06.11.25.
//


import SwiftUI

struct BugReportView: View {
    @State private var title: String = ""
    @State private var steps: String = ""
    @State private var expected: String = ""
    @State private var actual: String = ""
    @State private var showMailComposer: Bool = false
    @State private var showMailFallbackAlert: Bool = false

    private let recipient = SupportConfig.supportEmail

    var body: some View {
        Form {
            Section("Summary") {
                TextField("Short title (e.g. Wrong score animation)", text: $title)
            }
            Section("Details") {
                TextField("Steps to reproduce", text: $steps, axis: .vertical).lineLimit(3...6)
                TextField("Expected result", text: $expected, axis: .vertical).lineLimit(2...4)
                TextField("Actual result", text: $actual, axis: .vertical).lineLimit(2...6)
            }
            Section {
                Button {
                    sendReport()
                } label: {
                    Label("Send Report", systemImage: "paperplane.fill")
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Report Bug")
        .sheet(isPresented: $showMailComposer) {
            MailComposer(
                subject: "[Bug] \(title)",
                recipient: recipient,
                body: mailBody()
            )
        }
        .alert("No Mail account configured", isPresented: $showMailFallbackAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("We tried to open Mail, but it’s not available on this device.")
        }
    }

    private func sendReport() {
        if MailComposer.canSendMail {
            showMailComposer = true
        } else {
            if let url = URL(string: "mailto:\(recipient)?subject=\("[Bug] \(title)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(mailBody().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                UIApplication.shared.open(url) { ok in
                    if !ok { showMailFallbackAlert = true }
                }
            } else {
                showMailFallbackAlert = true
            }
        }
    }

    private func mailBody() -> String {
        """
        Title: \(title)

        Steps to reproduce:
        \(steps.isEmpty ? "-" : steps)

        Expected:
        \(expected.isEmpty ? "-" : expected)

        Actual:
        \(actual.isEmpty ? "-" : actual)
        """
    }
}
