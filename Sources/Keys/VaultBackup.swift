import CommonCrypto
import CryptoKit
import Foundation

/// A copy of the vault that opens with a password instead of this Mac's Secure Enclave: the way to
/// take the vault to another Mac, or to keep it somewhere safe in case this one is lost.
///
/// The contents are sealed with ChaCha20-Poly1305 under a key derived from the password with
/// PBKDF2-HMAC-SHA256 and a random salt. The header (format, version, how the key was derived,
/// when it was made) is authenticated with the contents, so none of it can be changed without the
/// file being refused. The password is never stored anywhere.
struct VaultBackup: Codable, Equatable {
    static let formatName = "keys-backup"
    static let currentVersion = 1
    static let fileExtension = "keys-backup"
    /// PBKDF2 rounds for a new backup: about half a second on a recent Mac, to make guessing slow.
    static let defaultIterations = 1_000_000
    /// Round counts a backup may ask for. The ceiling keeps a crafted file from hanging the app;
    /// the floor is low only so the tests run quickly.
    static let iterationRange = 1_000...20_000_000
    /// The shortest password a backup accepts.
    static let minimumPasswordLength = 10

    var format = VaultBackup.formatName
    var version = VaultBackup.currentVersion
    var kdf = "pbkdf2-sha256"
    var iterations: Int
    var salt: Data
    var createdAt: Date
    /// The vault contents, sealed (nonce, ciphertext and tag).
    var sealed: Data

    /// A backup of `plaintext` that opens with `password`.
    static func seal(_ plaintext: Data, password: String, iterations: Int = defaultIterations, createdAt: Date = Date()) throws -> VaultBackup {
        guard password.count >= minimumPasswordLength else { throw BackupError.weakPassword }
        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        guard status == errSecSuccess else { throw BackupError.notABackup }
        var backup = VaultBackup(iterations: iterations, salt: salt, createdAt: createdAt, sealed: Data())
        let key = try deriveKey(password: password, salt: salt, iterations: iterations)
        backup.sealed = try ChaChaPoly.seal(plaintext, using: key, authenticating: backup.header).combined
        return backup
    }

    /// The contents, if `password` is the one the backup was made with.
    func open(password: String) throws -> Data {
        guard format == Self.formatName, kdf == "pbkdf2-sha256", Self.iterationRange.contains(iterations), salt.count >= 16 else {
            throw BackupError.notABackup
        }
        guard version <= Self.currentVersion else { throw BackupError.newerVersion }
        let key = try Self.deriveKey(password: password, salt: salt, iterations: iterations)
        do {
            return try ChaChaPoly.open(ChaChaPoly.SealedBox(combined: sealed), using: key, authenticating: header)
        } catch {
            // A wrong password and a changed file look the same: the seal doesn't open.
            throw BackupError.wrongPassword
        }
    }

    /// What the seal authenticates besides the contents.
    private var header: Data {
        var data = Data("\(format)/\(version)/\(kdf)/\(iterations)/\(createdAt.timeIntervalSinceReferenceDate)".utf8)
        data.append(salt)
        return data
    }

    /// The key for `password`. The password is normalized first, so an accented letter typed as
    /// one character or as a letter and an accent gives the same key on any keyboard.
    static func deriveKey(password: String, salt: Data, iterations: Int) throws -> SymmetricKey {
        let normalized = password.precomposedStringWithCanonicalMapping
        var derived = [UInt8](repeating: 0, count: 32)
        let status = salt.withUnsafeBytes { saltBytes in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                normalized, normalized.utf8.count,
                saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(iterations),
                &derived, derived.count
            )
        }
        guard status == kCCSuccess else { throw BackupError.notABackup }
        return SymmetricKey(data: derived)
    }

    // MARK: Disk

    static func read(from url: URL) throws -> VaultBackup {
        do {
            return try JSONDecoder().decode(VaultBackup.self, from: Data(contentsOf: url))
        } catch {
            throw BackupError.notABackup
        }
    }

    /// Writes atomically, readable only by the user.
    func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    /// "Keys-backup-2026-11-02.keys-backup": the name offered when saving one.
    static func suggestedFileName(on date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "Keys-backup-\(formatter.string(from: date)).\(fileExtension)"
    }
}

enum BackupError: LocalizedError, Equatable {
    case notABackup
    case newerVersion
    case wrongPassword
    case weakPassword
    case passwordsDiffer

    var errorDescription: String? {
        switch self {
        case .notABackup:
            localized("Este arquivo não é um backup do cofre.")
        case .newerVersion:
            localized("Este backup foi feito por uma versão mais nova do app. Atualize o app para abri-lo.")
        case .wrongPassword:
            localized("A senha não abre este backup. Confira a senha; se ela estiver certa, o arquivo foi alterado.")
        case .weakPassword:
            localized("Use uma senha com pelo menos \(VaultBackup.minimumPasswordLength) caracteres.")
        case .passwordsDiffer:
            localized("As duas senhas não são iguais.")
        }
    }
}

extension VaultContents {
    /// These contents with a backup's added in: projects that aren't here come in, and a project
    /// that is in both keeps whichever copy was changed last. Nothing here is deleted.
    func merging(_ other: VaultContents) -> (contents: VaultContents, added: Int, updated: Int) {
        var merged = projects
        var added = 0
        var updated = 0
        for project in other.projects {
            if let index = merged.firstIndex(where: { $0.id == project.id }) {
                if project.updatedAt > merged[index].updatedAt {
                    merged[index] = project
                    updated += 1
                }
            } else {
                merged.append(project)
                added += 1
            }
        }
        return (VaultContents(projects: merged), added, updated)
    }
}
