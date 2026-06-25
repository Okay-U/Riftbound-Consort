//
//  LoginView.swift
//  Riftbound Companiokay
//
//  Email/password sign-in for the Locator. Password is sent once over HTTPS
//  and never stored — only the returned token is kept (in Keychain).
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: AuthSession
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && !session.isWorking
    }

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .focused($focus, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { submit() }
            } header: {
                Text("Sign in to Riftbound Locator")
            } footer: {
                if let message = session.errorMessage {
                    Text(message).foregroundStyle(.red)
                }
            }

            Section {
                Button(action: submit) {
                    HStack {
                        Spacer()
                        if session.isWorking { ProgressView() }
                        else { Text("Sign in").bold() }
                        Spacer()
                    }
                }
                .disabled(!canSubmit)
            } footer: {
                Text("Uses your existing locator.riftbound.uvsgames.com account. We store only a login token on this device (in the Keychain). Never your password.")
            }
        }
        .navigationTitle("Events")
        .onAppear { focus = .email }
    }

    private func submit() {
        guard canSubmit else { return }
        let email = email, password = password
        Task { await session.login(email: email, password: password) }
    }
}

#Preview {
    NavigationStack { LoginView() }
        .environmentObject(AuthSession())
}
