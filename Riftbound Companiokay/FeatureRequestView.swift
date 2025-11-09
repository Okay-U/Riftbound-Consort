//
//  FeatureRequestView.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 06.11.25.
//


import SwiftUI

struct FeatureRequestView: View {
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var showMailComposer: Bool = false
    @State private var showMailFallbackAlert: Bool = false

    private let recipient = SupportConfig.supportEmail

    var body: some View {
        Form {
            Section("Summary") {
                TextField("Feature title", text: $title)
            }
            Section("Description") {
                TextField("Describe your idea…", text: $description, axis: .vertical)
                    .lineLimit(4...10)
            }
            Section {
                Button {
                    sendFeature()
                } label: {
                    Label("Send Request", systemImage: "paperplane.fill")
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Wish a Feature")
        .sheet(isPresented: $showMailComposer) {
            MailComposer(
                subject: "[Feature] \(title)",
                recipient: recipient,
                body: featureBody()
            )
        }
        .alert("No Mail account configured", isPresented: $showMailFallbackAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("We tried to open Mail, but it’s not available on this device.")
        }
    }

    private func sendFeature() {
        if MailComposer.canSendMail {
            showMailComposer = true
        } else {
            if let url = URL(string: "mailto:\(recipient)?subject=\("[Feature] \(title)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(featureBody().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                UIApplication.shared.open(url) { ok in
                    if !ok { showMailFallbackAlert = true }
                }
            } else {
                showMailFallbackAlert = true
            }
        }
    }

    private func featureBody() -> String {
        """
        Title: \(title)

        Description:
        \(description.isEmpty ? "-" : description)
        """
    }
}
