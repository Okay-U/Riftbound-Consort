//
//  KeychainStore.swift
//  Riftbound Companiokay
//
//  Minimal Keychain wrapper for the Locator auth token.
//  Token only — never store the password. (Security rule: secrets go in
//  Keychain, never UserDefaults.)
//

import Foundation
import Security

nonisolated struct KeychainStore: Sendable {
    static let standard = KeychainStore(service: "pitopia.Riftcount.locator")

    let service: String
    private let account = "locatorToken"

    var token: String? {
        get { read(account) }
        nonmutating set {
            if let newValue, !newValue.isEmpty { save(account, newValue) }
            else { delete(account) }
        }
    }

    // MARK: - Primitives

    private func save(_ account: String, _ value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        }
    }

    private func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    private func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
