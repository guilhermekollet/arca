import CryptoKit
import Foundation

/// Something that agrees on a shared secret with a P256 public key: the Mac's Secure Enclave key
/// in the app (see DeviceKey), a software key in the tests.
protocol AgreementKey {
    var publicKey: P256.KeyAgreement.PublicKey { get }
    func sharedSecretFromKeyAgreement(with publicKeyShare: P256.KeyAgreement.PublicKey) throws -> SharedSecret
}

extension P256.KeyAgreement.PrivateKey: AgreementKey {}
extension SecureEnclave.P256.KeyAgreement.PrivateKey: AgreementKey {}

/// The vault as it is stored on disk.
///
/// The contents are sealed with ChaCha20-Poly1305 under a random 256-bit vault key. The vault key
/// itself is sealed for the device key: an ephemeral P256 key agrees on a secret with it, HKDF
/// turns that secret into a wrapping key, and the ephemeral public half is kept next to it.
/// Opening the vault therefore needs the device key, which lives in the Secure Enclave and only
/// works after Touch ID or the Mac's password. The header is bound to both seals, so it can't be
/// swapped from another vault.
struct VaultFile: Codable, Equatable {
    static let formatName = "keys-vault"
    static let currentVersion = 1

    var format = VaultFile.formatName
    var version = VaultFile.currentVersion
    /// The device key's public half (X9.63). A vault made for another key is recognized as such
    /// instead of failing as if it were damaged.
    var recipient: Data
    /// The ephemeral public key the vault key was wrapped with (X9.63).
    var ephemeral: Data
    /// The vault key, sealed (nonce, ciphertext and tag).
    var wrappedKey: Data
    /// The contents, sealed with the vault key.
    var contents: Data

    /// A new vault for `deviceKey`, with a fresh vault key, holding `plaintext`.
    static func create(_ plaintext: Data, for deviceKey: AgreementKey) throws -> (file: VaultFile, key: SymmetricKey) {
        let vaultKey = SymmetricKey(size: .bits256)
        let ephemeral = P256.KeyAgreement.PrivateKey()
        let recipient = deviceKey.publicKey.x963Representation
        let wrapping = try wrappingKey(
            ephemeral.sharedSecretFromKeyAgreement(with: deviceKey.publicKey),
            ephemeral: ephemeral.publicKey.x963Representation,
            recipient: recipient
        )
        let rawKey = vaultKey.withUnsafeBytes { Data($0) }
        // The header covers only the format and the keys, so it is known before anything is sealed.
        var file = VaultFile(recipient: recipient, ephemeral: ephemeral.publicKey.x963Representation, wrappedKey: Data(), contents: Data())
        file.wrappedKey = try ChaChaPoly.seal(rawKey, using: wrapping, authenticating: file.header).combined
        file.contents = try ChaChaPoly.seal(plaintext, using: vaultKey, authenticating: file.header).combined
        return (file, vaultKey)
    }

    /// The vault key, recovered with the device key. With the Secure Enclave key this is the step
    /// that asks for Touch ID, unless its authentication context was already evaluated.
    func unwrapKey(with deviceKey: AgreementKey) throws -> SymmetricKey {
        try checkHeader()
        guard deviceKey.publicKey.x963Representation == recipient else { throw VaultError.otherDeviceKey }
        let ephemeralKey: P256.KeyAgreement.PublicKey
        do {
            ephemeralKey = try P256.KeyAgreement.PublicKey(x963Representation: ephemeral)
        } catch {
            throw VaultError.damaged
        }
        let wrapping = try Self.wrappingKey(
            deviceKey.sharedSecretFromKeyAgreement(with: ephemeralKey),
            ephemeral: ephemeral,
            recipient: recipient
        )
        do {
            let rawKey = try ChaChaPoly.open(ChaChaPoly.SealedBox(combined: wrappedKey), using: wrapping, authenticating: header)
            return SymmetricKey(data: rawKey)
        } catch {
            throw VaultError.damaged
        }
    }

    /// The contents, decrypted with the vault key.
    func open(with vaultKey: SymmetricKey) throws -> Data {
        try checkHeader()
        do {
            return try ChaChaPoly.open(ChaChaPoly.SealedBox(combined: contents), using: vaultKey, authenticating: header)
        } catch {
            throw VaultError.damaged
        }
    }

    /// The same vault holding `plaintext` instead, sealed with a fresh nonce. The wrapped key is
    /// kept, so saving never needs the device key (or Touch ID) again.
    func resealing(_ plaintext: Data, with vaultKey: SymmetricKey) throws -> VaultFile {
        var file = self
        file.contents = try ChaChaPoly.seal(plaintext, using: vaultKey, authenticating: header).combined
        return file
    }

    /// What both seals authenticate: the format, the version and the keys they were made for.
    private var header: Data {
        var data = Data("\(format)/\(version)".utf8)
        data.append(recipient)
        data.append(ephemeral)
        return data
    }

    private func checkHeader() throws {
        guard format == Self.formatName else { throw VaultError.notAVault }
        guard version <= Self.currentVersion else { throw VaultError.newerVersion }
    }

    private static func wrappingKey(_ secret: SharedSecret, ephemeral: Data, recipient: Data) -> SymmetricKey {
        secret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: ephemeral + recipient,
            sharedInfo: Data("keys vault key v1".utf8),
            outputByteCount: 32
        )
    }

    // MARK: Disk

    static func read(from url: URL) throws -> VaultFile {
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode(VaultFile.self, from: data)
        } catch {
            throw VaultError.notAVault
        }
    }

    /// Writes atomically, readable only by the user.
    func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
        )
        try encoder.encode(self).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

enum VaultError: LocalizedError, Equatable {
    case notAVault
    case newerVersion
    case otherDeviceKey
    case damaged
    case missingDeviceKey
    case noSecureEnclave

    var errorDescription: String? {
        switch self {
        case .notAVault:
            localized("O arquivo do cofre não é um cofre do Chaves.")
        case .newerVersion:
            localized("Este cofre foi salvo por uma versão mais nova do Chaves. Atualize o app para abri-lo.")
        case .otherDeviceKey:
            localized("Este cofre foi trancado com outra chave: ele foi criado em outro Mac ou a chave deste Mac foi trocada.")
        case .damaged:
            localized("O arquivo do cofre está danificado ou foi alterado.")
        case .missingDeviceKey:
            localized("A chave deste Mac não está no Keychain, então o cofre não pode ser aberto aqui.")
        case .noSecureEnclave:
            localized("Este Mac não tem Secure Enclave, que o Chaves usa para guardar a chave do cofre.")
        }
    }
}
