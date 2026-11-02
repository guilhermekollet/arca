import SwiftUI

/// Opens from the menu bar icon: the projects, and inside one of them its accesses and variables,
/// searchable and one click from the clipboard, without opening the main window. Searching
/// before choosing a project looks across all of them. Laid out like Mara's panel.
struct MenuBarPanel: View {
    @EnvironmentObject private var vault: Vault
    @Environment(\.openWindow) private var openWindow
    @State private var query: String
    /// The project open in the panel; the search then looks only inside it.
    @State private var projectID: Project.ID?
    @FocusState private var searchFocused: Bool

    /// `query` and `project` start the panel already searching or inside a project (used by Snapshot).
    init(query: String = "", project: Project.ID? = nil) {
        _query = State(initialValue: query)
        _projectID = State(initialValue: project)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if vault.state == .unlocked {
                if let project = vault.project(projectID) {
                    projectBar(project)
                }
                TextField(searchPrompt, text: $query)
                    .textFieldStyle(.field)
                    .focused($searchFocused)
                    .onAppear { searchFocused = true }
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        content
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: 380)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                lockedCard
            }
            Divider().overlay(Theme.paper.opacity(0.12))
            footer
        }
        .padding(14)
        .frame(width: 330)
        .arcaSurface()
        // Esc inside a project goes back to the list, like a back button.
        .onKeyPress(.escape) {
            guard projectID != nil else { return .ignored }
            leaveProject()
            return .handled
        }
        .onChange(of: vault.state) {
            if vault.state != .unlocked { leaveProject() }
        }
    }

    private var searchPrompt: String {
        if let project = vault.project(projectID) {
            return localized("Buscar em \(project.name)")
        }
        return localized("Buscar acesso ou variável")
    }

    /// Logo and name, with the lock on the right.
    private var header: some View {
        HStack(spacing: 6) {
            Image(nsImage: Theme.menuBarIcon)
                .renderingMode(.template)
            Text("Arca")
                .font(Theme.display(19))
            Spacer()
            if vault.state == .unlocked && !vault.isSample {
                IconButton(symbol: "lock", help: localized("Trancar o cofre")) { vault.lock() }
            }
        }
    }

    /// Back to the projects, the project open in the panel, and a way to open it in the app.
    private func projectBar(_ project: Project) -> some View {
        HStack(spacing: 8) {
            IconButton(symbol: "chevron.left", help: localized("Voltar aos projetos"), action: leaveProject)
            ProjectBadge(project: project, size: 22)
            Text(project.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Spacer()
            IconButton(symbol: "macwindow", help: localized("Abrir na janela da Arca")) { open(project.id, at: .context) }
        }
    }

    private var lockedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(vault.state == .new ? localized("Crie o cofre para começar.") : localized("O cofre está trancado."))
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
            if vault.state == .locked {
                Button {
                    Task { await vault.unlock() }
                } label: {
                    Label(localized("Destrancar com Touch ID"), systemImage: "touchid")
                }
                .buttonStyle(PillButtonStyle())
                .disabled(vault.isUnlocking)
            } else {
                Button(localized("Abrir a Arca")) { present(mainWindowID, using: openWindow) }
                    .buttonStyle(PillButtonStyle())
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        let searching = !Search.words(query).isEmpty
        if let project = vault.project(projectID) {
            let items = Search.items(in: project, query: query)
            if items.isEmpty {
                note(searching ? localized("Nada encontrado.") : localized("Este projeto ainda não tem acessos nem variáveis."))
            } else {
                matchList(items, showsProject: false)
            }
        } else if !searching {
            if projectList.isEmpty {
                note(localized("Nenhum projeto ainda."))
            } else {
                section(localized("Projetos"))
                projectRows(projectList)
            }
        } else {
            let projects = vault.projects.filter { $0.matches(query) }
            let matches = Search.quickMatches(in: vault.projects, query: query, limit: 12)
            if projects.isEmpty && matches.isEmpty {
                note(localized("Nada encontrado."))
            }
            if !projects.isEmpty {
                section(localized("Projetos"))
                projectRows(Array(projects.prefix(4)))
            }
            if !matches.isEmpty {
                section(localized("Acessos e variáveis"))
                    .padding(.top, projects.isEmpty ? 0 : 8)
                matchList(matches, showsProject: true)
            }
        }
    }

    /// The projects worth reaching from the menu bar: all but the archived ones (search still
    /// finds those), in the main window's order.
    private var projectList: [Project] {
        vault.projects
            .filter { $0.status != .archived }
            .sorted {
                let order = Project.Status.allCases
                if $0.status != $1.status { return order.firstIndex(of: $0.status)! < order.firstIndex(of: $1.status)! }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    private func projectRows(_ projects: [Project]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(projects) { project in
                PanelProjectRow(project: project) { enter(project.id) }
            }
        }
    }

    private func matchList(_ matches: [QuickMatch], showsProject: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(matches) { match in
                if match.id != matches.first?.id { RowDivider() }
                QuickMatchRow(match: match, showsProject: showsProject) {
                    switch match.item {
                    case .credential: open(match.projectID, at: .credentials)
                    case .variable: open(match.projectID, at: .variables)
                    }
                }
            }
        }
    }

    private func section(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.muted)
            .padding(.bottom, 4)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            link(localized("Abrir a Arca")) { present(mainWindowID, using: openWindow) }
            link(localized("Ajustes")) { present(settingsWindowID, using: openWindow) }
            Spacer(minLength: 12)
            link(localized("Sair")) { NSApp.terminate(nil) }
        }
        .font(.system(size: 11.5))
    }

    private func link(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .foregroundStyle(Theme.muted)
            .fixedSize()
    }

    private func enter(_ id: Project.ID) {
        projectID = id
        query = ""
        searchFocused = true
    }

    private func leaveProject() {
        projectID = nil
        query = ""
    }

    private func open(_ id: Project.ID, at section: ProjectSection) {
        vault.selection = id
        vault.section = section
        present(mainWindowID, using: openWindow)
    }
}

/// A project in the panel's list: what it holds, and a chevron, since clicking goes into it.
private struct PanelProjectRow: View {
    let project: Project
    let open: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: open) {
            HStack(spacing: 8) {
                ProjectBadge(project: project, size: 22)
                Text(project.name.isEmpty ? localized("Sem nome") : project.name)
                    .font(.system(size: 12.5))
                    .lineLimit(1)
                Spacer(minLength: 8)
                count(project.credentials.count, symbol: "key")
                count(project.environments.reduce(0) { $0 + $1.variables.count }, symbol: "curlybraces")
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.paper.opacity(0.35))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(Theme.paper.opacity(hovering ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(localized("Ver os acessos e as variáveis de \(project.name)"))
    }

    @ViewBuilder
    private func count(_ value: Int, symbol: String) -> some View {
        if value > 0 {
            Label("\(value)", systemImage: symbol)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 10.5).monospacedDigit())
                .foregroundStyle(Theme.muted)
        }
    }
}

struct QuickMatchRow: View {
    let match: QuickMatch
    /// Off inside a project, where its name would repeat on every row.
    var showsProject = true
    let open: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .medium, design: isVariable ? .monospaced : .default))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(localized("Abrir na janela da Arca"))
            switch match.item {
            case .credential(let credential):
                if !credential.username.isEmpty {
                    CopyButton(value: credential.username, symbol: "person", help: localized("Copiar o usuário"))
                }
                CopyButton(value: credential.password, secret: true, symbol: "key", help: localized("Copiar a senha"))
            case .variable(let variable, _):
                CopyButton(value: variable.value, secret: variable.isSecret, help: localized("Copiar o valor"))
            }
        }
        .padding(.vertical, 6)
    }

    private var isVariable: Bool {
        if case .variable = match.item { return true }
        return false
    }

    private var title: String {
        switch match.item {
        case .credential(let credential): credential.displayTitle
        case .variable(let variable, _): variable.key
        }
    }

    private var subtitle: String {
        let detail: String
        switch match.item {
        case .credential(let credential): detail = credential.username.isEmpty ? credential.kind.label : credential.username
        case .variable(_, let environment): detail = environment
        }
        return showsProject ? "\(match.projectName) · \(detail)" : detail
    }
}
