import SwiftUI

/// The parts of a project, one tab each.
enum ProjectSection: String, CaseIterable, Identifiable {
    case context, variables, credentials, links
    var id: Self { self }

    var title: String {
        switch self {
        case .context: localized("Contexto")
        case .variables: localized("Variáveis")
        case .credentials: localized("Acessos")
        case .links: localized("Links")
        }
    }

    var symbol: String {
        switch self {
        case .context: "text.page"
        case .variables: "curlybraces"
        case .credentials: "key"
        case .links: "link"
        }
    }
}

/// One project: its name and status on top, its tabs, then the open tab.
struct ProjectView: View {
    @Binding var project: Project
    @EnvironmentObject private var vault: Vault

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProjectHeader(project: $project)
                .padding(.horizontal, 24)
                .padding(.top, 20)
            CapsuleTabs(tabs: ProjectSection.allCases, selection: $vault.section, title: title, symbol: \.symbol)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 14)
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
            switch vault.section {
            case .context: ContextTab(project: $project)
            case .variables: VariablesTab(project: $project)
            case .credentials: CredentialsTab(project: $project)
            case .links: LinksTab(project: $project)
            }
        }
        .navigationTitle(project.name)
    }

    /// The tab's name, with how many items it holds.
    private func title(_ section: ProjectSection) -> String {
        let count = switch section {
        case .context: 0
        case .variables: project.environments.reduce(0) { $0 + $1.variables.count }
        case .credentials: project.credentials.count
        case .links: project.links.count
        }
        return count == 0 ? section.title : "\(section.title) · \(count)"
    }
}

struct ProjectHeader: View {
    @Binding var project: Project
    @EnvironmentObject private var vault: Vault
    @State private var tags = ""

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Menu {
                Picker(localized("Símbolo"), selection: $project.symbol) {
                    ForEach(Project.symbols, id: \.self) { symbol in
                        Label(symbol, systemImage: symbol).labelStyle(.iconOnly).tag(symbol)
                    }
                }
                .pickerStyle(.palette)
            } label: {
                ProjectBadge(project: project, size: 46)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(localized("Trocar o símbolo"))

            VStack(alignment: .leading, spacing: 3) {
                path
                TextField(localized("Nome do projeto"), text: $project.name)
                    .font(Theme.display(26))
                    .textFieldStyle(.plain)
                TextField(localized("Uma linha sobre o projeto"), text: $project.summary)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .foregroundStyle(Theme.muted)
                TextField(localized("Etiquetas, separadas por vírgula"), text: $tags)
                    .font(.system(size: 11.5))
                    .textFieldStyle(.plain)
                    .foregroundStyle(Theme.paper.opacity(0.45))
                    .onChange(of: tags) { commitTags() }
                ScrollView(.horizontal, showsIndicators: false) {
                    subprojects
                }
                .padding(.top, 8)
            }

            Spacer(minLength: 12)

            parentMenu

            Menu {
                Picker(localized("Situação"), selection: $project.status) {
                    ForEach(Project.Status.allCases) { status in
                        Label(status.label, systemImage: status.symbol).tag(status)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Badge(text: project.status.label, symbol: project.status.symbol)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(localized("Situação do projeto"))
        }
        .onAppear { tags = project.tags.joined(separator: ", ") }
    }

    /// "Grupo Fazolli ›" above the name of a subproject, each step a way back up.
    @ViewBuilder
    private var path: some View {
        let ancestors = ProjectTree.ancestors(of: project, in: vault.projects)
        if !ancestors.isEmpty {
            HStack(spacing: 4) {
                ForEach(ancestors) { ancestor in
                    Button(ancestor.name) { vault.selection = ancestor.id }
                        .buttonStyle(.plain)
                        .help(localized("Abrir \(ancestor.name)"))
                    Text("›")
                }
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(Theme.muted)
        }
    }

    /// The projects inside this one, as chips that open them, and a way to add another.
    private var subprojects: some View {
        HStack(spacing: 6) {
            ForEach(ProjectTree.children(of: project.id, in: vault.projects)) { child in
                Button {
                    vault.selection = child.id
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: child.symbol)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.accent)
                        Text(child.name.isEmpty ? localized("Sem nome") : child.name)
                            .font(.system(size: 11.5, weight: .medium))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Theme.paper.opacity(0.08), in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(localized("Abrir \(child.name)"))
            }
            Button {
                vault.addProject(inside: project.id)
            } label: {
                Label(localized("Subprojeto"), systemImage: "plus")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .overlay(Capsule().strokeBorder(Theme.paper.opacity(0.15)))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help(localized("Criar um projeto dentro deste"))
        }
    }

    /// Moves the project inside another one, or back to the top level.
    private var parentMenu: some View {
        Menu {
            Picker(localized("Dentro de"), selection: $project.parentID) {
                Text(localized("Nenhum: projeto principal")).tag(Project.ID?.none)
                Divider()
                ForEach(ProjectTree.possibleParents(for: project.id, in: vault.projects)) { candidate in
                    Text(ProjectTree.path(of: candidate, in: vault.projects)).tag(Optional(candidate.id))
                }
            }
            .pickerStyle(.inline)
        } label: {
            let parent = vault.project(project.parentID)
            Badge(text: parent.map { localized("Em \($0.name)") } ?? localized("Projeto principal"), symbol: "folder")
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(localized("Mover para dentro de outro projeto"))
    }

    private func commitTags() {
        let list = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if list != project.tags { project.tags = list }
    }
}

/// Where the code is and the free text that explains the project.
struct ContextTab: View {
    @Binding var project: Project

    /// Headings that cover what is usually missing when a project is picked up again.
    static var outline: String {
        [localized("Como rodar"), localized("Deploy"), localized("Onde está o quê"), localized("Decisões"), localized("Armadilhas"), localized("Contatos")]
            .map { "## \($0)\n\n" }
            .joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .foregroundStyle(Theme.muted)
                    .frame(width: 18)
                TextField(localized("Pasta do projeto neste Mac"), text: $project.localPath)
                    .textFieldStyle(.code)
                Button(localized("Escolher…"), action: chooseFolder)
                    .buttonStyle(PillButtonStyle(prominent: false))
                IconButton(symbol: "folder.badge.gearshape", help: localized("Abrir no Finder")) {
                    if let folderURL { NSWorkspace.shared.open(folderURL) }
                }
                .disabled(!folderExists)
                IconButton(symbol: "terminal", help: localized("Abrir no Terminal"), action: openInTerminal)
                    .disabled(!folderExists)
            }

            TextEditor(text: $project.context)
                .font(.system(size: 13, design: .monospaced))
                .lineSpacing(2)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // An overlay, not a sibling in a stack: the hint must never decide how tall the
                // editor is. Measured as part of the layout, its wrapped text made the whole window
                // taller than the screen for a new, empty project.
                .overlay(alignment: .topLeading) {
                    if project.context.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(localized("Tudo o que você vai querer saber quando voltar a este projeto: como rodar, como publicar, onde está cada coisa, por que foi feito assim e com quem falar."))
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.muted)
                            Button(localized("Começar com um roteiro")) { project.context = Self.outline }
                                .buttonStyle(PillButtonStyle())
                        }
                        .padding(16)
                        .frame(maxWidth: 460, alignment: .leading)
                    }
                }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(20)
    }

    private var folderURL: URL? {
        let path = (project.localPath as NSString).expandingTildeInPath
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
    }

    private var folderExists: Bool {
        guard let folderURL else { return false }
        return FileManager.default.fileExists(atPath: folderURL.path)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = localized("Escolher")
        if let folderURL { panel.directoryURL = folderURL }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // Kept with "~" so the path still reads well (and works) on a Mac with another user name.
        project.localPath = (url.path as NSString).abbreviatingWithTildeInPath
    }

    private func openInTerminal() {
        guard let folderURL, let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else { return }
        NSWorkspace.shared.open([folderURL], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
    }
}

/// Addresses that go with the project: repository, production, dashboards, docs.
struct LinksTab: View {
    @Binding var project: Project

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if project.links.isEmpty {
                    EmptyTab(symbol: "link", title: localized("Nenhum link"), text: localized("Repositório, produção, painéis, documentação."))
                } else {
                    Card {
                        VStack(spacing: 0) {
                            ForEach($project.links) { $link in
                                if link.id != project.links.first?.id { RowDivider() }
                                LinkRow(link: $link) {
                                    project.links.removeAll { $0.id == link.id }
                                }
                            }
                        }
                    }
                }
                Button {
                    project.links.append(ProjectLink())
                } label: {
                    Label(localized("Adicionar link"), systemImage: "plus")
                }
                .buttonStyle(PillButtonStyle(prominent: project.links.isEmpty))
            }
            .padding(20)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct LinkRow: View {
    @Binding var link: ProjectLink
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField(localized("Nome"), text: $link.title)
                .textFieldStyle(.field)
                .frame(width: 170)
            TextField("https://", text: $link.url)
                .textFieldStyle(.code)
            CopyButton(value: link.url, help: localized("Copiar o endereço"))
            IconButton(symbol: "arrow.up.right", help: localized("Abrir")) {
                if let url = URL(string: link.url) { NSWorkspace.shared.open(url) }
            }
            .disabled(URL(string: link.url)?.scheme == nil)
            IconButton(symbol: "trash", help: localized("Remover"), action: remove)
        }
        .padding(.vertical, 6)
    }
}

/// A hairline between the rows of a card.
struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
    }
}

/// What an empty tab shows: what goes there.
struct EmptyTab: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(text)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 6)
    }
}
