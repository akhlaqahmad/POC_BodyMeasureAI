//
//  DeviceIdentity.swift
//  BodyMeasureAI
//
//  Stable per-install anonymous identity. UUID generated once, persisted in
//  the Keychain so it survives reinstalls when iCloud Keychain is enabled
//  (and survives normal app launches always). Sent as the `X-Device-Id`
//  header on every backend request.
//

import Foundation
import Security
import os

enum DeviceIdentity {

    private static let service = "com.bodymeasureai.identity"
    private static let account = "device-id"

    /// Returns the persistent device id, generating + storing one on first call.
    static func current() -> String {
        if let existing = readFromKeychain() {
            AppLog.lifecycle.debug("DeviceIdentity reused")
            return existing
        }
        let fresh = UUID().uuidString
        let stored = writeToKeychain(fresh)
        if stored {
            AppLog.lifecycle.info("DeviceIdentity generated and stored")
        } else {
            AppLog.lifecycle.error("DeviceIdentity Keychain write failed; using in-memory id this launch")
        }
        return fresh
    }

    // MARK: - Keychain

    private static func keychainQuery(_ extras: [String: Any] = [:]) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        for (k, v) in extras { q[k] = v }
        return q
    }

    private static func readFromKeychain() -> String? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(
            keychainQuery([
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]) as CFDictionary,
            &item,
        )
        guard status == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    @discardableResult
    private static func writeToKeychain(_ value: String) -> Bool {
        let data = Data(value.utf8)
        // Delete any stale entry first so add doesn't error with duplicate.
        SecItemDelete(keychainQuery() as CFDictionary)
        let attrs = keychainQuery([
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ])
        return SecItemAdd(attrs as CFDictionary, nil) == errSecSuccess
    }
}
