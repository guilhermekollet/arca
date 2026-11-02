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
    /// The project this one belongs to, such as a company and its products; nil at the top level.
    var parentID: Project.ID?

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

// MARK: Tree

/// Projects inside projects: a company and its products, a product and its services. Every
/// question about the tree goes through here, so a parent that no longer exists, or a loop the
/// vault somehow ended up with, never hides a project: it is simply shown at the top level.
enum ProjectTree {
    /// The projects directly inside `parent`, by name; `nil` gives the top level.
    static func children(of parent: Project.ID?, in projects: [Project]) -> [Project] {
        projects
            // A project in a loop is shown at the top level only, so walking down the tree always ends.
            .filter { parent == nil ? isTopLevel($0, in: projects) : $0.parentID == parent && !isTopLevel($0, in: projects) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Whether `project` is shown at the top level: it has no parent, its parent is gone, or
    /// following the parents goes round in a loop.
    static func isTopLevel(_ project: Project, in projects: [Project]) -> Bool {
        guard let parentID = project.parentID, projects.contains(where: { $0.id == parentID }) else { return true }
        return ancestors(of: project, in: projects).isEmpty
    }

    /// The projects above `project`, from the top level down to its parent. Empty for a project
    /// at the top level, and when its parents go round in a loop.
    static func ancestors(of project: Project, in projects: [Project]) -> [Project] {
        var chain: [Project] = []
        var seen: Set<Project.ID> = [project.id]
        var next = project.parentID
        while let id = next {
            guard let parent = projects.first(where: { $0.id == id }) else { break }
            guard seen.insert(parent.id).inserted else { return [] }
            chain.insert(parent, at: 0)
            next = parent.parentID
        }
        return chain
    }

    /// Every project inside `id`, at any depth.
    static func descendantIDs(of id: Project.ID, in projects: [Project]) -> Set<Project.ID> {
        var found: Set<Project.ID> = []
        var queue = [id]
        while let current = queue.popLast() {
            for child in projects where child.parentID == current && !found.contains(child.id) && child.id != id {
                found.insert(child.id)
                queue.append(child.id)
            }
        }
        return found
    }

    /// Where `id` can be moved: any project but itself and those inside it, which would make a loop.
    static func possibleParents(for id: Project.ID, in projects: [Project]) -> [Project] {
        let excluded = descendantIDs(of: id, in: projects).union([id])
        return projects
            .filter { !excluded.contains($0.id) }
            .sorted { path(of: $0, in: projects).localizedStandardCompare(path(of: $1, in: projects)) == .orderedAscending }
    }

    /// "Grupo Fazolli › Reallead": the project's name after those above it.
    static func path(of project: Project, in projects: [Project]) -> String {
        (ancestors(of: project, in: projects) + [project]).map(\.name).joined(separator: " › ")
    }

    /// `projects` without `id`. What was inside it moves up one level, so deleting a company
    /// never deletes its products along with it.
    static func removing(_ id: Project.ID, from projects: [Project]) -> [Project] {
        let parent = projects.first { $0.id == id }?.parentID
        return projects.compactMap { project in
            guard project.id != id else { return nil }
            var project = project
            if project.parentID == id { project.parentID = parent }
            return project
        }
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
        let ordered = projects.filter { $0.status != .archived } + projects.filter { $0.status == .archived }
        return Array(ordered.lazy.flatMap { matches(in: $0, among: projects, words: words) }.prefix(limit))
    }

    /// What the menu bar lists inside one project. While `query` is empty, the project's own
    /// accesses and then its variables environment by environment (its subprojects are listed
    /// apart). A search also looks inside its subprojects, at any depth: searching a company
    /// finds the database of one of its products.
    static func items(in project: Project, among projects: [Project], query: String) -> [QuickMatch] {
        let words = words(query)
        guard !words.isEmpty else { return matches(in: project, among: projects, words: []) }
        let inside = ProjectTree.descendantIDs(of: project.id, in: projects)
        let scope = [project] + projects.filter { inside.contains($0.id) }
        return scope.flatMap { matches(in: $0, among: projects, words: words) }
    }

    /// The project's accesses and variables that contain every word, counting the names of the
    /// projects above it as part of each one ("fazolli reallead banco").
    private static func matches(in project: Project, among projects: [Project], words: [String]) -> [QuickMatch] {
        func matches(_ text: String) -> Bool {
            words.allSatisfy { text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
        var found: [QuickMatch] = []
        let base = ProjectTree.ancestors(of: project, in: projects).map(\.name) + [project.name] + project.tags
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
        return found
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
        parentID = try container.decodeIfPresent(UUID.self, forKey: .parentID)
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
