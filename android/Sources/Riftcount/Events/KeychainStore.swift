import Foundation
import SkipKeychain

/// Minimal secure-storage wrapper for the Locator auth token, ported from
/// the iOS Security-framework version. Backed by SkipKeychain: iOS Keychain
/// on Darwin, Android Keystore-encrypted storage on Android.
/// Token only — never store the password.
struct KeychainStore: Sendable {
    static let standard = KeychainStore(service: "pitopia.Riftcount.locator")

    let service: String
    private var account: String { "\(service).locatorToken" }

    var token: String? {
        get {
            (try? Keychain.shared.string(forKey: account)) ?? nil
        }
        nonmutating set {
            if let newValue, !newValue.isEmpty {
                try? Keychain.shared.set(newValue, forKey: account)
            } else {
                try? Keychain.shared.removeValue(forKey: account)
            }
        }
    }
}
