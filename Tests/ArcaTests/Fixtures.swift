// Test helpers that need Foundation or CryptoKit live here, in a file that does not import
// Testing: with only the Command Line Tools installed (no Xcode), importing Testing next to
// Foundation fails because the `_Testing_Foundation` overlay is missing. Test files import just
// Testing and Arca and talk to these helpers through plain values.
import CryptoKit
import Foundation
@testable import Arca

// MARK: Vault file

/// Ways to break a vault file, to check that each one is caught.
enum Tampering: String, CaseIterable {
    case none
    case contentsByte
    case wrappedKeyByte
    case ephemeralFromAnotherVault
    case contentsFromAnotherVault
    case otherDeviceKey
    case newerVersion
    case otherFormat
}

/// Creates a vault for a software device key, tampers with it and tries to open it: "opened"
/// with the original text, or the error it fails with.
func openVault(after tampering: Tampering) -> String {
    let deviceKey = P256.KeyAgreement.PrivateKey()
    let secret = Data("SUPABASE_SERVICE_ROLE_KEY=abc".utf8)
    do {
        var (file, _) = try VaultFile.create(secret, for: deviceKey)
        let (other, _) = try VaultFile.create(secret, for: deviceKey)
        var opener: AgreementKey = deviceKey
        switch tampering {
        case .none: break
        case .contentsByte: file.contents[file.contents.count - 20] ^= 1
        case .wrappedKeyByte: file.wrappedKey[14] ^= 1
        case .ephemeralFromAnotherVault: file.ephemeral = other.ephemeral
        case .contentsFromAnotherVault: file.contents = other.contents
        case .otherDeviceKey: opener = P256.KeyAgreement.PrivateKey()
        case .newerVersion: file.version = VaultFile.currentVersion + 1
        case .otherFormat: file.format = "something-else"
        }
        let key = try file.unwrapKey(with: opener)
        let opened = try file.open(with: key)
        return opened == secret ? "opened" : "wrong contents"
    } catch let error as VaultError {
        return "\(error)"
    } catch {
        return "unexpected: \(error)"
    }
}

/// Saving again keeps the wrapped key and changes only the contents, which then open with the
/// same device key.
func resealingKeepsTheKey() -> Bool {
    let deviceKey = P256.KeyAgreement.PrivateKey()
    guard let (file, key) = try? VaultFile.create(Data("first".utf8), for: deviceKey),
          let saved = try? file.resealing(Data("second".utf8), with: key),
          let reopened = try? saved.unwrapKey(with: deviceKey),
          let contents = try? saved.open(with: reopened)
    else { return false }
    return saved.wrappedKey == file.wrappedKey && saved.contents != file.contents && contents == Data("second".utf8)
}

/// Two seals of the same contents differ (fresh nonces), so the file reveals nothing about edits.
func sealsDiffer() -> Bool {
    let deviceKey = P256.KeyAgreement.PrivateKey()
    guard let (file, key) = try? VaultFile.create(Data("same".utf8), for: deviceKey),
          let first = try? file.resealing(Data("same".utf8), with: key),
          let second = try? file.resealing(Data("same".utf8), with: key)
    else { return false }
    return first.contents != second.contents
}

/// Writes a vault to a temporary folder and reads it back: whether it is the same, and the file's
/// permissions in octal ("600").
func vaultOnDisk() -> (sameAfterReading: Bool, permissions: String, plaintextVisible: Bool) {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("arca-tests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("vault.arca")
    do {
        let (file, _) = try VaultFile.create(try Vault.encode(VaultContents(projects: SampleVault.projects)), for: P256.KeyAgreement.PrivateKey())
        try file.write(to: url)
        let read = try VaultFile.read(from: url)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let permissions = String((attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0, radix: 8)
        let raw = try String(contentsOf: url, encoding: .utf8)
        return (read == file, permissions, raw.contains("Loja Aurora") || raw.contains("sample-password"))
    } catch {
        return (false, "", true)
    }
}

/// A file that isn't JSON at all is reported as not being a vault.
func readingGarbage() -> String {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("arca-garbage-\(UUID().uuidString).arca")
    defer { try? FileManager.default.removeItem(at: url) }
    try? Data("not a vault".utf8).write(to: url)
    do {
        _ = try VaultFile.read(from: url)
        return "read"
    } catch {
        return "\(error)"
    }
}

// MARK: Contents

/// The sample vault survives encoding and decoding unchanged, dates included.
func sampleRoundTrips() -> Bool {
    let projects = SampleVault.projects
    guard let data = try? Vault.encode(VaultContents(projects: projects)),
          let decoded = try? Vault.decode(data)
    else { return false }
    return decoded.projects == projects
}

/// Decodes `json` as vault contents and describes the first project: name, status, symbol and
/// how many environments and accesses it has.
func firstProjectDecoded(from json: String) -> String {
    guard let contents = try? Vault.decode(Data(json.utf8)) else { return "failed" }
    guard let project = contents.projects.first else { return "no projects" }
    return "\(project.name)|\(project.status.rawValue)|\(project.symbol)|\(project.environments.count)|\(project.credentials.count)"
}

// MARK: Environment variables

/// Merges `file` into a set holding `existing`, and returns the counts and the result as
/// "KEY=value" lines, with "(secret)" after secret ones.
func merge(_ file: String, into existing: [(String, String)]) -> (added: Int, updated: Int, lines: [String]) {
    var environment = EnvironmentSet(name: "development", variables: existing.map { Variable(key: $0.0, value: $0.1) })
    let result = environment.merge(DotEnv.parse(file))
    let lines = environment.variables.map { "\($0.key)=\($0.value)\($0.isSecret ? " (secret)" : "")" }
    return (result.added, result.updated, lines)
}

// MARK: Search

/// The titles (access names and variable keys) the menu bar search finds in the sample vault.
func quickMatchTitles(_ query: String) -> [String] {
    Search.quickMatches(in: SampleVault.projects, query: query).map { match in
        switch match.item {
        case .credential(let credential): credential.displayTitle
        case .variable(let variable, let environment): "\(variable.key)@\(environment)"
        }
    }
}

/// The sample projects whose name matches `query` in the sidebar search.
func projectsMatching(_ query: String) -> [String] {
    SampleVault.projects.filter { $0.matches(query) }.map(\.name)
}

// MARK: Translations

private let sources = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Sources/Arca")

/// The interface's translation table for `language` ("en", "es"), read from the sources.
func translationTable(_ language: String) -> [String: String] {
    let url = sources.appendingPathComponent("Resources/\(language).lproj/Localizable.strings")
    return NSDictionary(contentsOf: url) as? [String: String] ?? [:]
}

/// The format specifiers in `text`, in order (`%@`, `%lld`, `%%`): a translation must keep its key's.
func formatSpecifiers(_ text: String) -> [String] {
    let pattern = try! NSRegularExpression(pattern: "%(%|@|l{0,2}[dfu])")
    return pattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
        .map { String(text[Range($0.range, in: text)!]) }
}

/// The key of every `localized("…")` in Sources/Arca, the way `String.LocalizationValue` builds
/// it, except that interpolations become `%@` whatever their type (the source doesn't say).
func localizedKeysInSources() -> [String] {
    let files = (try? FileManager.default.contentsOfDirectory(at: sources, includingPropertiesForKeys: nil)) ?? []
    var keys: [String] = []
    for file in files where file.pathExtension == "swift" {
        let text = Array((try? String(contentsOf: file, encoding: .utf8)) ?? "")
        let opening = Array("localized(\"")
        var index = 0
        while index + opening.count <= text.count {
            guard Array(text[index..<index + opening.count]) == opening else {
                index += 1
                continue
            }
            index += opening.count
            var key = ""
            while text[index] != "\"" {
                if text[index] == "\\", text[index + 1] == "(" {
                    // Skips the interpolated expression, which may have parentheses of its own.
                    var depth = 1
                    index += 2
                    while depth > 0 {
                        if text[index] == "(" { depth += 1 }
                        if text[index] == ")" { depth -= 1 }
                        index += 1
                    }
                    key += "%@"
                } else if text[index] == "\\" {
                    key += String(text[index...index + 1])
                    index += 2
                } else {
                    key += text[index] == "%" ? "%%" : String(text[index])
                    index += 1
                }
            }
            keys.append(key)
        }
    }
    return keys
}

/// `key` with every specifier but `%%` written as `%@`, to compare with `localizedKeysInSources`.
func normalizedKey(_ key: String) -> String {
    key.replacingOccurrences(of: "%l{0,2}[dfu]", with: "%@", options: .regularExpression)
}
