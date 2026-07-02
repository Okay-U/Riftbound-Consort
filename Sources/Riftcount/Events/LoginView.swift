import SwiftUI

/// Locator sign-in, ported from iOS. Title-led, rounded pill fields, green
/// gradient CTA. Password sent once over HTTPS, never stored — only the token
/// is kept (SkipKeychain). Port: FocusState/submitLabel dropped, eye glyph drawn.
struct LoginView: View {
    @Environment(AuthSession.self) var session
    @AppStorage("batterySaver") var batterySaver = false

    @State var email = ""
    @State var password = ""
    @State var revealPassword = false

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
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
        .background(EventsTheme.bg.ignoresSafeArea())
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
            TextField("Email", text: $email)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16).frame(height: 54)
        .eventsCard(radius: EventsTheme.pillRadius)
    }

    private var passwordField: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock").foregroundStyle(EventsTheme.textSecondary).frame(width: 20)
            Group {
                if revealPassword {
                    TextField("Password", text: $password)
                } else {
                    SecureField("Password", text: $password)
                }
            }
            .foregroundStyle(.white)

            Button { revealPassword.toggle() } label: {
                EyeGlyph(open: !revealPassword)
                    .foregroundStyle(EventsTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).frame(height: 54)
        .eventsCard(radius: EventsTheme.pillRadius)
    }

    private var signInButton: some View {
        Button(action: submit) {
            HStack(spacing: 8) {
                if session.isWorking {
                    ProgressView()
                } else {
                    Text("Sign in").font(.system(size: 17, weight: .bold))
                    Image(systemName: "arrow.forward").font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: EventsTheme.ctaRadius, style: .continuous)
                    .fill(LinearGradient(colors: [EventsTheme.green, EventsTheme.green.opacity(0.75)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .shadow(color: batterySaver ? Color.clear : EventsTheme.green.opacity(0.35), radius: 18, y: 10)
            .opacity(canSubmit ? 1 : 0.5)
        }
        .buttonStyle(.plain)
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

    // MARK: - Actions

    private func submit() {
        guard canSubmit else { return }
        let email = email, password = password
        Task { await session.login(email: email, password: password) }
    }
}

/// Drawn eye (show/hide password) — eye symbols are not in SkipUI's map.
struct EyeGlyph: View {
    let open: Bool

    var body: some View {
        ZStack {
            Ellipse()
                .stroke(lineWidth: 1.5)
                .frame(width: 20, height: 13)
            Circle()
                .fill()
                .frame(width: 6, height: 6)
            if !open {
                Rectangle()
                    .fill()
                    .frame(width: 22, height: 1.5)
                    .rotationEffect(Angle(degrees: -30))
            }
        }
        .frame(width: 24, height: 24)
    }
}
