// Test helpers that need Foundation or CryptoKit live here, in a file that does not import
// Testing: with only the Command Line Tools installed (no Xcode), importing Testing next to
// Foundation fails because the `_Testing_Foundation` overlay is missing. Test files import just
// Testing and Keys and talk to these helpers through plain values.
import AppKit
import CryptoKit
import Foundation
@testable import Keys

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
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("keys-tests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("vault.keys")
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
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("keys-garbage-\(UUID().uuidString).keys")
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
    return "\(project.name)|\(project.isArchived ? "archived" : "active")|\(project.symbol)|\(project.environments.count)|\(project.credentials.count)"
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
    .appendingPathComponent("Sources/Keys")

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

/// The key of every `localized("…")` in Sources/Keys, the way `String.LocalizationValue` builds
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

// MARK: Menu bar and locking

/// The titles the menu bar lists inside the sample project called `projectName`, as in
/// `quickMatchTitles`.
func projectItemTitles(_ projectName: String, query: String) -> [String] {
    let projects = SampleVault.projects
    guard let project = projects.first(where: { $0.name == projectName }) else { return ["no such project"] }
    return Search.items(in: project, among: projects, query: query).map { match in
        switch match.item {
        case .credential(let credential): credential.displayTitle
        case .variable(let variable, let environment): "\(variable.key)@\(environment)"
        }
    }
}

/// Whether the vault locks `minutesSinceUnlock` after Touch ID, with an unlock that lasts
/// `unlockMinutes`, the Mac idle for `idleMinutes` and the idle lock set to `idleLock` minutes.
func locks(minutesSinceUnlock: Double, unlockMinutes: Int, idleMinutes: Double = 0, idleLock: Int = 0) -> Bool {
    let unlockedAt = Date(timeIntervalSinceReferenceDate: 0)
    return AutoLock.shouldLock(
        now: unlockedAt.addingTimeInterval(minutesSinceUnlock * 60),
        locksAt: unlockedAt.addingTimeInterval(TimeInterval(unlockMinutes * 60)),
        idleSeconds: idleMinutes * 60,
        idleMinutes: idleLock
    )
}

// MARK: Projects inside projects

/// A small tree, by name: "Grupo" holds "Loja" and "API", "Loja" holds "Checkout", and "Site"
/// stands alone. `loop` also makes "A" and "B" each other's parent.
private func tree(loop: Bool = false) -> [Project] {
    var group = Project(name: "Grupo")
    var shop = Project(name: "Loja")
    var api = Project(name: "API")
    var checkout = Project(name: "Checkout")
    let site = Project(name: "Site")
    shop.parentID = group.id
    api.parentID = group.id
    checkout.parentID = shop.id
    group.parentID = nil
    var projects = [checkout, site, api, shop, group]
    if loop {
        var a = Project(name: "A")
        var b = Project(name: "B")
        a.parentID = b.id
        b.parentID = a.id
        projects += [a, b]
    }
    return projects
}

private func names(_ projects: [Project]) -> [String] { projects.map(\.name) }

/// The names directly inside `name` ("" for the top level).
func childrenNames(of name: String, loop: Bool = false) -> [String] {
    let projects = tree(loop: loop)
    let parent = projects.first { $0.name == name }?.id
    return names(ProjectTree.children(of: name.isEmpty ? nil : parent, in: projects))
}

/// The path shown above `name`, and the places it could be moved to.
func treeFacts(_ name: String) -> (path: String, parents: [String]) {
    let projects = tree()
    let project = projects.first { $0.name == name }!
    return (ProjectTree.path(of: project, in: projects), names(ProjectTree.possibleParents(for: project.id, in: projects)))
}

/// After deleting `name`, each remaining project with the name of its parent ("-" at the top).
func parentsAfterDeleting(_ name: String) -> [String] {
    let projects = tree()
    let id = projects.first { $0.name == name }!.id
    let remaining = ProjectTree.removing(id, from: projects)
    return remaining.map { project in "\(project.name)<\(remaining.first { $0.id == project.parentID }?.name ?? "-")" }.sorted()
}

/// Decodes a project saved before subprojects existed: whether it comes back at the top level.
func oldProjectHasNoParent() -> Bool {
    guard let contents = try? Vault.decode(Data(#"{"projects":[{"name":"Old"}]}"#.utf8)) else { return false }
    return contents.projects.first?.parentID == nil
}

// MARK: The app's name by language

/// The interface language a Mac set to `preferences` gets.
func interfaceLanguage(for preferences: [String]) -> String {
    Interface.pickLanguage(from: ["en", "es", "pt-BR"], preferring: preferences)
}

/// The app's name on a Mac set to `preferences`, read from the app's own tables.
func appName(onMacIn preferences: [String]) -> String {
    let language = interfaceLanguage(for: preferences)
    guard let table = Interface.table(for: language) else {
        return "no table for \(language)"
    }
    return String(localized: "Chaves", bundle: table)
}

/// The name Finder, the Dock and the app menu show in `language`.
func finderName(in language: String) -> String {
    let url = sources.appendingPathComponent("Resources/\(language).lproj/InfoPlist.strings")
    let table = NSDictionary(contentsOf: url) as? [String: String] ?? [:]
    return [table["CFBundleName"], table["CFBundleDisplayName"]].map { $0 ?? "-" }.joined(separator: "/")
}

// MARK: Backups

/// Ways to break a backup, to check that each one is refused.
enum BackupTampering: String, CaseIterable {
    case none, sealedByte, fewerIterations, otherSalt, otherDate, otherFormat, newerVersion
}

/// Seals a sample with `password` (few rounds, so the test is fast), tampers with it and opens it
/// with `attempt`: "opened" with the same contents, or the error.
func openBackup(sealedWith password: String, openedWith attempt: String, after tampering: BackupTampering = .none) -> String {
    let secret = Data("PIX_WEBHOOK_SECRET=abc".utf8)
    do {
        var backup = try VaultBackup.seal(secret, password: password, iterations: 2_000)
        switch tampering {
        case .none: break
        case .sealedByte: backup.sealed[backup.sealed.count - 5] ^= 1
        case .fewerIterations: backup.iterations = 1_000
        case .otherSalt: backup.salt[0] ^= 1
        case .otherDate: backup.createdAt = backup.createdAt.addingTimeInterval(60)
        case .otherFormat: backup.format = "something-else"
        case .newerVersion: backup.version = VaultBackup.currentVersion + 1
        }
        return try backup.open(password: attempt) == secret ? "opened" : "wrong contents"
    } catch let error as BackupError {
        return "\(error)"
    } catch {
        return "unexpected: \(error)"
    }
}

/// Writes a backup of the sample vault and reads it back: the same projects, the file's permissions,
/// and whether any name or secret can be read in it.
func backupOnDisk() -> (sameProjects: Bool, permissions: String, plaintextVisible: Bool) {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("keys-backup-\(UUID().uuidString).keys-backup")
    defer { try? FileManager.default.removeItem(at: url) }
    let projects = SampleVault.projects
    do {
        try VaultBackup.seal(try Vault.encode(VaultContents(projects: projects)), password: "correct horse battery", iterations: 2_000).write(to: url)
        let read = try VaultBackup.read(from: url)
        let contents = try Vault.decode(try read.open(password: "correct horse battery"))
        let permissions = String((try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?.intValue ?? 0, radix: 8)
        let raw = try String(contentsOf: url, encoding: .utf8)
        return (contents.projects == projects, permissions, raw.contains("Loja Aurora") || raw.contains("sample-password"))
    } catch {
        return (false, "", true)
    }
}

/// Merges `backup` into `current` (projects as name and minutes since a fixed date, same id when
/// the name is the same) and returns the counts and the names with their minutes.
func merge(backup: [(String, Int)], into current: [(String, Int)]) -> (added: Int, updated: Int, result: [String]) {
    var ids: [String: UUID] = [:]
    func project(_ entry: (String, Int)) -> Project {
        let id = ids[entry.0] ?? UUID()
        ids[entry.0] = id
        return Project(id: id, name: entry.0, updatedAt: Date(timeIntervalSinceReferenceDate: Double(entry.1) * 60))
    }
    let mine = VaultContents(projects: current.map(project))
    let theirs = VaultContents(projects: backup.map(project))
    let merged = mine.merging(theirs)
    let result = merged.contents.projects.map { "\($0.name)@\(Int($0.updatedAt.timeIntervalSinceReferenceDate / 60))" }
    return (merged.added, merged.updated, result)
}

/// The file name offered when saving a backup made on 2 November 2026.
func suggestedBackupName() -> String {
    var components = DateComponents()
    components.year = 2026
    components.month = 11
    components.day = 2
    components.hour = 12
    return VaultBackup.suggestedFileName(on: Calendar.current.date(from: components)!)
}

// MARK: Archiving

/// Archives (or brings back, with `archived` false) the project called `name` in the tree above,
/// and returns which projects end up archived, and the two sidebar lists' top rows.
func archiving(_ name: String, archived: Bool = true, startingArchived: [String] = []) -> (archived: [String], activeRoots: [String], archivedRoots: [String]) {
    var projects = treeForArchiving()
    let date = Date(timeIntervalSinceReferenceDate: 0)
    for index in projects.indices where startingArchived.contains(projects[index].name) {
        projects[index].archivedAt = date
    }
    let id = projects.first { $0.name == name }!.id
    let result = ProjectTree.settingArchived(id, at: archived ? date : nil, in: projects)
    return (
        result.filter(\.isArchived).map(\.name).sorted(),
        ProjectTree.roots(archived: false, in: result).map(\.name),
        ProjectTree.roots(archived: true, in: result).map(\.name)
    )
}

/// "Grupo" holds "Loja" and "API", "Loja" holds "Checkout", and "Site" stands alone.
private func treeForArchiving() -> [Project] {
    let group = Project(name: "Grupo")
    var shop = Project(name: "Loja")
    var api = Project(name: "API")
    var checkout = Project(name: "Checkout")
    let site = Project(name: "Site")
    shop.parentID = group.id
    api.parentID = group.id
    checkout.parentID = shop.id
    return [group, shop, api, checkout, site]
}

/// The quick search's titles when the sample's "Loja Aurora" is archived: archived results last.
func quickMatchTitlesWithShopArchived(_ query: String) -> [String] {
    var projects = SampleVault.projects
    for index in projects.indices where projects[index].name == "Loja Aurora" {
        projects[index].archivedAt = Date()
    }
    return Search.quickMatches(in: projects, query: query).map { match in
        switch match.item {
        case .credential(let credential): credential.displayTitle
        case .variable(let variable, let environment): "\(variable.key)@\(environment)"
        }
    }
}

/// The color the first project in `json` decodes with.
func firstProjectTint(from json: String) -> String {
    (try? Vault.decode(Data(json.utf8)))?.projects.first?.tint.rawValue ?? "failed"
}

/// Whether every symbol offered for a project exists on this Mac, and how many there are.
func projectSymbolsExist() -> (count: Int, missing: [String]) {
    (Project.symbols.count, Project.symbols.filter { NSImage(systemSymbolName: $0, accessibilityDescription: nil) == nil })
}

/// Whether every icon offered for an access exists on this Mac, and how many there are.
func credentialSymbolsExist() -> (count: Int, missing: [String]) {
    (Credential.symbols.count, Credential.symbols.filter { NSImage(systemSymbolName: $0, accessibilityDescription: nil) == nil })
}

/// The icon an access of `kind` shows after a trip through the vault file, with `picked` chosen
/// for it, or with the "symbol" key taken out, as in vaults from before accesses had icons.
func credentialIcon(kind: Credential.Kind, picked: String?, fromOldVault: Bool = false) -> String {
    var project = Project(name: "Icons")
    project.credentials = [Credential(kind: kind, title: "Panel", symbol: picked)]
    guard var data = try? Vault.encode(VaultContents(projects: [project])) else { return "failed" }
    if fromOldVault {
        guard var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var projects = json["projects"] as? [[String: Any]],
              var credentials = projects[0]["credentials"] as? [[String: Any]]
        else { return "failed" }
        credentials[0].removeValue(forKey: "symbol")
        projects[0]["credentials"] = credentials
        json["projects"] = projects
        guard let stripped = try? JSONSerialization.data(withJSONObject: json) else { return "failed" }
        data = stripped
    }
    return (try? Vault.decode(data))?.projects.first?.credentials.first?.displaySymbol ?? "failed"
}

/// The names left after deleting `name`, and everything inside it, for good.
func remainingAfterDeletingForGood(_ name: String) -> [String] {
    let projects = treeForArchiving()
    let id = projects.first { $0.name == name }!.id
    return ProjectTree.removingWithSubprojects(id, from: projects).map(\.name).sorted()
}

// MARK: The project's list

/// What the project list's search keeps of the sample's "Loja Aurora": access titles, variable
/// keys (with their environment) and link titles.
func projectListMatches(_ query: String) -> [String] {
    guard let shop = SampleVault.projects.first(where: { $0.name == "Loja Aurora" }) else { return ["no shop"] }
    let credentials = shop.credentials.filter { $0.matches(query) }.map(\.displayTitle)
    let variables = shop.environments.flatMap { environment in
        environment.variables.filter { $0.matches(query) }.map { "\($0.key)@\(environment.name)" }
    }
    let links = shop.links.filter { $0.matches(query) }.map(\.title)
    return credentials + variables + links
}

// MARK: Appearance

/// The appearance Settings show when the defaults hold `value` for it.
func storedAppearance(_ value: String?) -> Preferences.Appearance {
    let defaults = UserDefaults.standard
    let previous = defaults.object(forKey: Preferences.appearanceKey)
    defer { defaults.set(previous, forKey: Preferences.appearanceKey) }
    defaults.set(value, forKey: Preferences.appearanceKey)
    return Preferences.appearance
}
