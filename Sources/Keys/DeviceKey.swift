import CryptoKit
import Foundation
import LocalAuthentication
import Security

/// The key that ties the vault to this Mac: a P256 key created inside the Secure Enclave, which
/// never leaves it. Using it takes Touch ID or the Mac's password. The Keychain keeps only the
/// key's handle, which the Secure Enclave encrypted and which is useless on any other Mac.
enum DeviceKey {
    static var isAvailable: Bool { SecureEnclave.isAvailable }

    /// A new device key, replacing the one in the Keychain. Creating it doesn't ask for Touch ID:
    /// only using its private half does.
    static func create() throws -> SecureEnclave.P256.KeyAgreement.PrivateKey {
        guard isAvailable else { throw VaultError.noSecureEnclave }
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, [.privateKeyUsage, .userPresence], &error
        ) else {
            throw error!.takeRetainedValue() as Error
        }
        let key = try SecureEnclave.P256.KeyAgreement.PrivateKey(accessControl: access)
        try Keychain.save(key.dataRepresentation)
        return key
    }

    /// The device key's public half (X9.63), or nil when the Keychain has no device key. Reading
    /// it doesn't ask for Touch ID.
    static func publicKey() -> Data? {
        guard let handle = Keychain.load() else { return nil }
        return try? SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: handle).publicKey.x963Representation
    }

    /// The device key, once the person confirms with Touch ID or the Mac's password. The
    /// authentication context comes along with the key, so the Secure Enclave doesn't ask again
    /// when the vault key is unwrapped.
    static func unlock(reason: String) async throws -> SecureEnclave.P256.KeyAgreement.PrivateKey {
        guard let handle = Keychain.load() else { throw VaultError.missingDeviceKey }
        let context = LAContext()
        try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        return try SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: handle, authenticationContext: context)
    }

    /// Whether `error` only means the person dismissed the Touch ID prompt.
    static func isCancellation(_ error: Error) -> Bool {
        guard let error = error as? LAError else { return false }
        return [.userCancel, .appCancel, .systemCancel].contains(error.code)
    }
}

/// The device key's handle in the user's login Keychain.
private enum Keychain {
    private static let item: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.guilhermekollet.keys",
        kSecAttrAccount as String: "device-key",
    ]

    static func load() -> Data? {
        var query = item
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func save(_ data: Data) throws {
        SecItemDelete(item as CFDictionary)
        var entry = item
        entry[kSecValueData as String] = data
        entry[kSecAttrLabel as String] = "Keys"
        entry[kSecAttrDescription as String] = "Keys vault key (Secure Enclave)"
        let status = SecItemAdd(entry as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}
