//
//  LoginView.swift
//  Riftbound Companiokay
//
//  Locator sign-in (signed-out state of the Events tab). Title-led, rounded
//  pill fields, green gradient CTA, then Sign in with Apple. Password is sent
//  once over HTTPS and never stored — only the returned token is kept (Keychain).
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var session: AuthSession
    @AppStorage("batterySaver") private var batterySaver = false

    @State private var email = ""
    @State private var password = ""
    @State private var revealPassword = false
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && !session.isWorking
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                title
                emailField
                passwordField

                if let message = session.errorMessage {
                    Text(message).font(.footnote).foregroundStyle(.red)
                }

                signInButton
                tokenHint
                orDivider
                appleButton
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(EventsTheme.bg.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Pieces

    private var title: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Events")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(EventsTheme.textPrimary)
            Text("Sign in to follow standings, pairings and report your matches live.")
                .font(.system(size: 15))
                .foregroundStyle(EventsTheme.textSecondary)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var emailField: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope").foregroundStyle(EventsTheme.textSecondary).frame(width: 20)
            TextField("", text: $email, prompt: Text("Email").foregroundStyle(EventsTheme.textSecondary))
                .foregroundStyle(.white)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .email)
                .submitLabel(.next)
                .onSubmit { focus = .password }
        }
        .padding(.horizontal, 16).frame(height: 54)
        .eventsCard(radius: EventsTheme.pillRadius)
    }

    private var passwordField: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock").foregroundStyle(EventsTheme.textSecondary).frame(width: 20)
            Group {
                if revealPassword {
                    TextField("", text: $password, prompt: Text("Password").foregroundStyle(EventsTheme.textSecondary))
                } else {
                    SecureField("", text: $password, prompt: Text("Password").foregroundStyle(EventsTheme.textSecondary))
                }
            }
            .foregroundStyle(.white)
            .textContentType(.password)
            .focused($focus, equals: .password)
            .submitLabel(.go)
            .onSubmit { submit() }

            Button { revealPassword.toggle() } label: {
                Image(systemName: revealPassword ? "eye.slash" : "eye")
                    .foregroundStyle(EventsTheme.textSecondary)
            }
        }
        .padding(.horizontal, 16).frame(height: 54)
        .eventsCard(radius: EventsTheme.pillRadius)
    }

    private var signInButton: some View {
        Button(action: submit) {
            HStack(spacing: 8) {
                if session.isWorking {
                    ProgressView().tint(.white)
                } else {
                    Text("Sign in").font(.system(size: 17, weight: .bold))
                    Image(systemName: "arrow.right").font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 56)
            .background(
                LinearGradient(colors: [EventsTheme.green, EventsTheme.green.opacity(0.75)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: EventsTheme.ctaRadius, style: .continuous)
            )
            .shadow(color: batterySaver ? .clear : EventsTheme.green.opacity(0.35), radius: 18, y: 10)
            .opacity(canSubmit ? 1 : 0.5)
        }
        .disabled(!canSubmit)
    }

    private var tokenHint: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "lock").font(.system(size: 11)).foregroundStyle(EventsTheme.textTertiary)
            Text("Uses your locator.riftbound.uvsgames.com account. Only a login token is kept on device. Never your password.")
                .font(.system(size: 12.5))
                .foregroundStyle(EventsTheme.textSecondary)
        }
    }

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(EventsTheme.hairline).frame(height: 1)
            Text("or").font(.system(size: 12)).foregroundStyle(EventsTheme.textTertiary)
            Rectangle().fill(EventsTheme.hairline).frame(height: 1)
        }
    }

    private var appleButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            handleApple(result)
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: EventsTheme.ctaRadius, style: .continuous))
        .disabled(session.isWorking)
    }

    // MARK: - Actions

    private func submit() {
        guard canSubmit else { return }
        let email = email, password = password
        Task { await session.login(email: email, password: password) }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                session.errorMessage = "Apple sign-in returned no token. Try email instead."
                return
            }
            Task { await session.loginWithApple(idToken: idToken) }
        case .failure(let error):
            // User cancelling the sheet is not an error worth showing.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            session.errorMessage = "Apple sign-in failed. Please try again or use email."
        }
    }
}

#Preview {
    NavigationStack { LoginView() }
        .environmentObject(AuthSession())
}
