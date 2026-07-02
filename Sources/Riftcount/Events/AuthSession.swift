import Foundation
import Observation
import SkipFuse

/// Observable auth state for the Events tab, ported from iOS
/// (ObservableObject → @Observable). Owns the token via KeychainStore,
/// exposes signed-in/out state, restores on launch.
@Observable @MainActor
final class AuthSession {
    enum State: Equatable {
        case signedOut
        case signedIn(LocatorUser)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.signedOut, .signedOut): return true
            case let (.signedIn(a), .signedIn(b)): return a.id == b.id
            default: return false
            }
        }
    }

    private(set) var state: State = .signedOut
    private(set) var isWorking = false
    var errorMessage: String?

    private let service: any AuthService
    private let keychain: KeychainStore

    /// Bearer token for authed Locator calls, when signed in.
    var token: String? { keychain.token }

    var userID: Int? { currentUser?.id }

    var currentUser: LocatorUser? {
        if case let .signedIn(user) = state { return user }
        return nil
    }

    init(service: any AuthService = RiftboundAuthService(),
         keychain: KeychainStore = .standard) {
        self.service = service
        self.keychain = keychain
    }

    /// Validate any stored token on launch.
    func restore() async {
        guard let token = keychain.token else { return }
        do {
            let user = try await service.currentUser(token: token)
            state = .signedIn(user)
        } catch {
            keychain.token = nil
            state = .signedOut
        }
    }

    func login(email: String, password: String) async {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !password.isEmpty else { return }
        await signIn { try await self.service.login(email: email, password: password) }
    }

    /// Shared sign-in flow: obtain a token, persist it, then load the user.
    private func signIn(_ obtainToken: () async throws -> String) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let token = try await obtainToken()
            keychain.token = token
            let user = try await service.currentUser(token: token)
            state = .signedIn(user)
        } catch {
            keychain.token = nil
            state = .signedOut
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Sign in failed. Please try again."
        }
    }

    func logout() {
        keychain.token = nil
        errorMessage = nil
        state = .signedOut
    }

    /// If an authed call failed because the token is no longer valid (401),
    /// sign out so the user re-authenticates. Returns true if it signed out.
    @discardableResult
    func signOutIfUnauthorized(_ error: Error) -> Bool {
        if case LocatorError.http(401) = error {
            logout()
            errorMessage = "Your session ended. Please sign in again."
            return true
        }
        if let authError = error as? AuthError, case .tokenExpired = authError {
            logout()
            errorMessage = "Your session ended. Please sign in again."
            return true
        }
        return false
    }
}
