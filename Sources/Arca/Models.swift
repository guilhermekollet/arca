import Foundation

/// Everything in the vault, encoded to JSON and encrypted as a whole (see VaultFile).
struct VaultContents: Codable, Equatable {
    var projects: [Project] = []
}

/// A project and everything needed to pick it up again months later: what it is, how it runs,
/// its environment variables and the accesses that go with it.
struct Project: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var symbol = "shippingbox"
    var status = Status.active
    /// One line on what the project is.
    var summary = ""
    var tags: [String] = []
    /// Free text, in Markdown: how to run it, how it's deployed, decisions, who to ask.
    var context = ""
    /// Where the code is on this Mac.
    var localPath = ""
    var links: [ProjectLink] = []
    var environments: [EnvironmentSet] = [EnvironmentSet(name: "development")]
    var credentials: [Credential] = []
    var createdAt = Date()
    var updatedAt = Date()

    enum Status: String, Codable, CaseIterable, Identifiable {
        case active, maintenance, paused, archived
        var id: String { rawValue }
    }
}

struct ProjectLink: Codable, Identifiable, Hashable {
    var id = UUID()
    var title = ""
    var url = ""
}

/// One set of environment variables: development, staging, production…
struct EnvironmentSet: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var variables: [Variable] = []
}

struct Variable: Codable, Identifiable, Hashable {
    var id = UUID()
    var key = ""
    var value = ""
    /// Secret values are hidden on screen and copied as concealed, so clipboard managers skip them.
    var isSecret = false

    /// Whether a variable called `key` most likely holds a secret, for variables that arrive by import.
    static func looksSecret(_ key: String) -> Bool {
        let key = key.uppercased()
        return ["SECRET", "TOKEN", "PASSWORD", "PASSWD", "PASS", "KEY", "PRIVATE", "CREDENTIAL", "AUTH", "DSN", "DATABASE_URL"]
            .contains { key.contains($0) }
    }
}

/// An access: a login, a database, a server, an API key.
struct Credential: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind = Kind.website
    var title = ""
    var url = ""
    var username = ""
    var password = ""
    var notes = ""
    var updatedAt = Date()

    enum Kind: String, Codable, CaseIterable, Identifiable {
        case website, database, server, apiKey, email, other
        var id: String { rawValue }
    }

    /// The title, or the address when there is none.
    var displayTitle: String {
        if !title.isEmpty { return title }
        return URL(string: url)?.host() ?? url
    }
}

extension EnvironmentSet {
    /// Adds `entries` (from a .env file) to the set: a key it already has takes the new value, a
    /// new key is added at the end, marked secret when its name suggests one. When a file repeats
    /// a key, the last value wins, as dotenv loaders do.
    @discardableResult
    mutating func merge(_ entries: [DotEnv.Entry]) -> (added: Int, updated: Int) {
        var added = 0
        var updated = 0
        for entry in entries {
            if let index = variables.firstIndex(where: { $0.key == entry.key }) {
                if variables[index].value != entry.value {
                    variables[index].value = entry.value
                    updated += 1
                }
            } else {
                variables.append(Variable(key: entry.key, value: entry.value, isSecret: Variable.looksSecret(entry.key)))
                added += 1
            }
        }
        return (added, updated)
    }

    var dotEnv: String {
        DotEnv.format(variables.filter { !$0.key.isEmpty }.map { DotEnv.Entry(key: $0.key, value: $0.value) })
    }
}

// MARK: Search

extension Project {
    /// Whether every word of `query` appears somewhere in the project, ignoring case and accents.
    /// Secret values (passwords and variable values) are never searched.
    func matches(_ query: String) -> Bool {
        let words = Search.words(query)
        guard !words.isEmpty else { return true }
        let haystack = searchableText
        return words.allSatisfy { haystack.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    private var searchableText: String {
        var parts = [name, summary, context, localPath] + tags
        parts += links.flatMap { [$0.title, $0.url] }
        parts += environments.flatMap { [$0.name] + $0.variables.map(\.key) }
        parts += credentials.flatMap { [$0.title, $0.url, $0.username] }
        return parts.joined(separator: "\n")
    }
}

/// What the menu bar's search finds: an access or a variable, with the project it belongs to.
struct QuickMatch: Identifiable, Hashable {
    enum Item: Hashable {
        case credential(Credential)
        case variable(Variable, environment: String)
    }

    let projectID: UUID
    let projectName: String
    let item: Item

    var id: String {
        switch item {
        case .credential(let credential): "\(projectID)/c/\(credential.id)"
        case .variable(let variable, _): "\(projectID)/v/\(variable.id)"
        }
    }
}

enum Search {
    static func words(_ query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// Accesses and variables whose project and own name, together, contain every word of
    /// `query`: "fazon prod database" finds the database URL in Fazon's production set.
    /// Archived projects come last.
    static func quickMatches(in projects: [Project], query: String, limit: Int = 30) -> [QuickMatch] {
        let words = words(query)
        guard !words.isEmpty else { return [] }
        func matches(_ text: String) -> Bool {
            words.allSatisfy { text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
        var found: [QuickMatch] = []
        let ordered = projects.filter { $0.status != .archived } + projects.filter { $0.status == .archived }
        for project in ordered {
            let base = [project.name] + project.tags
            for credential in project.credentials {
                let text = (base + [credential.title, credential.url, credential.username, credential.kind.rawValue]).joined(separator: " ")
                if matches(text) { found.append(QuickMatch(projectID: project.id, projectName: project.name, item: .credential(credential))) }
            }
            for environment in project.environments {
                for variable in environment.variables where !variable.key.isEmpty {
                    let text = (base + [environment.name, variable.key]).joined(separator: " ")
                    if matches(text) {
                        found.append(QuickMatch(projectID: project.id, projectName: project.name, item: .variable(variable, environment: environment.name)))
                    }
                }
            }
        }
        return Array(found.prefix(limit))
    }
}

// MARK: Decoding

// Every field falls back to its default when missing, so a vault saved before a field existed
// still opens after an update. The initializers live in extensions to keep the memberwise ones.

extension KeyedDecodingContainer {
    fileprivate func value<T: Decodable>(_ key: Key, or fallback: @autoclosure () -> T) throws -> T {
        try decodeIfPresent(T.self, forKey: key) ?? fallback()
    }
}

extension VaultContents {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        projects = try container.value(.projects, or: [])
    }
}

extension Project {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Project(name: "")
        id = try container.value(.id, or: UUID())
        name = try container.value(.name, or: "")
        symbol = try container.value(.symbol, or: fallback.symbol)
        status = (try? container.value(.status, or: fallback.status)) ?? fallback.status
        summary = try container.value(.summary, or: "")
        tags = try container.value(.tags, or: [])
        context = try container.value(.context, or: "")
        localPath = try container.value(.localPath, or: "")
        links = try container.value(.links, or: [])
        environments = try container.value(.environments, or: [])
        credentials = try container.value(.credentials, or: [])
        createdAt = try container.value(.createdAt, or: Date())
        updatedAt = try container.value(.updatedAt, or: createdAt)
    }
}

extension ProjectLink {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.value(.id, or: UUID())
        title = try container.value(.title, or: "")
        url = try container.value(.url, or: "")
    }
}

extension EnvironmentSet {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.value(.id, or: UUID())
        name = try container.value(.name, or: "")
        variables = try container.value(.variables, or: [])
    }
}

extension Variable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.value(.id, or: UUID())
        key = try container.value(.key, or: "")
        value = try container.value(.value, or: "")
        isSecret = try container.value(.isSecret, or: false)
    }
}

extension Credential {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.value(.id, or: UUID())
        kind = (try? container.value(.kind, or: Kind.other)) ?? .other
        title = try container.value(.title, or: "")
        url = try container.value(.url, or: "")
        username = try container.value(.username, or: "")
        password = try container.value(.password, or: "")
        notes = try container.value(.notes, or: "")
        updatedAt = try container.value(.updatedAt, or: Date())
    }
}
