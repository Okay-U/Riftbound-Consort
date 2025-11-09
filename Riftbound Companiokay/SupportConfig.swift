//
//  SupportConfig.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 06.11.25.
//


import SwiftUI
import MessageUI
import SafariServices

enum SupportConfig {
    static let supportEmail: String = "okay.uenal@icloud.com"

    static let donationURL: URL = URL(string: "https://ko-fi.com/okayunal")!
}

struct MailComposer: UIViewControllerRepresentable {
    static var canSendMail: Bool { MFMailComposeViewController.canSendMail() }

    var subject: String
    var recipient: String
    var body: String

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setSubject(subject)
        vc.setToRecipients([recipient])
        vc.setMessageBody(body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct DonationView: View {
    @State private var showSafari = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Buy me a coffee ☕️")
                .font(.title2).bold()
            Text("If you enjoy this app, you can support me with a small donation. Thank you!")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
                showSafari = true
            } label: {
                Label("Donate", systemImage: "heart.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)

            Spacer()
        }
        .padding()
        .navigationTitle("Buy me a coffee")
        .sheet(isPresented: $showSafari) {
            SafariView(url: SupportConfig.donationURL)
        }
    }
}

enum DeviceDiagnostics {
    static var summary: String {
        let device = UIDevice.current
        let system = "\(device.systemName) \(device.systemVersion)"
        let model = device.model
        let locale = Locale.current.identifier
        let appVer = "\(Bundle.main.appVersion) (\(Bundle.main.appBuild))"
        return "App: \(appVer)\nDevice: \(model)\nSystem: \(system)\nLocale: \(locale)"
    }
}
