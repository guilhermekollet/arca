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
            Group {
                switch vault.section {
                case .context: ContextTab(project: $project)
                case .variables: VariablesTab(project: $project)
                case .credentials: CredentialsTab(project: $project)
                case .links: LinksTab(project: $project)
                }
            }
            // Whatever a tab holds, it fits the room left under the header and never makes the
            // window's content taller than the window (which pushed the sidebar and the header
            // off screen once). Content that doesn't fit scrolls in its tab or is clipped.
            .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
            .clipped()
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
    @FocusState private var nameFocused: Bool
    @State private var choosingLook = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            identity
            // Under the header, across the whole width (not squeezed beside the badges), lined up
            // with the name. It scrolls sideways only when there are more chips than fit.
            ScrollView(.horizontal, showsIndicators: false) {
                subprojects
            }
            // As tall as the chips: a horizontal scroll view would otherwise take any height
            // it's offered.
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 46 + 14)
        }
        .onAppear {
            tags = project.tags.joined(separator: ", ")
            // A project just created opens with its name selected, ready to be typed over.
            if Date().timeIntervalSince(project.createdAt) < 2 {
                DispatchQueue.main.async { nameFocused = true }
            }
        }
    }

    /// Symbol, name, summary and tags, with where the project sits and its status on the right.
    private var identity: some View {
        HStack(alignment: .top, spacing: 14) {
            Button {
                choosingLook = true
            } label: {
                ProjectBadge(project: project, size: 46)
            }
            .buttonStyle(.plain)
            .help(localized("Trocar o ícone e a cor"))
            .accessibilityLabel(localized("Trocar o ícone e a cor"))
            .popover(isPresented: $choosingLook, arrowEdge: .bottom) {
                ProjectLookPicker(symbol: $project.symbol, tint: $project.tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                path
                TextField(localized("Nome do projeto"), text: $project.name)
                    .font(Theme.display(26))
                    .textFieldStyle(.plain)
                    .focused($nameFocused)
                TextField(localized("Uma linha sobre o projeto"), text: $project.summary)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .foregroundStyle(Theme.muted)
                TextField(localized("Etiquetas, separadas por vírgula"), text: $tags)
                    .font(.system(size: 11.5))
                    .textFieldStyle(.plain)
                    .foregroundStyle(Theme.paper.opacity(0.45))
                    .onChange(of: tags) { commitTags() }
            }

            Spacer(minLength: 12)

            parentMenu

            archiveControl
        }
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
            ForEach(ProjectTree.children(of: project.id, in: vault.projects).filter { $0.isArchived == project.isArchived }) { child in
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

    /// Archives the project (with its subprojects) or brings it back. An archived project says
    /// since when, and that's the only way it looks different here.
    @ViewBuilder
    private var archiveControl: some View {
        let hasSubprojects = !ProjectTree.children(of: project.id, in: vault.projects).isEmpty
        if let archivedAt = project.archivedAt {
            HStack(spacing: 6) {
                Badge(text: localized("Arquivado"), symbol: "archivebox")
                    .help(localized("Arquivado em \(archivedAt.formatted(date: .abbreviated, time: .omitted))"))
                Button(localized("Desarquivar")) { vault.setArchived(project.id, false) }
                    .buttonStyle(PillButtonStyle(prominent: false))
                    .help(hasSubprojects ? localized("Volta a usar o projeto e os subprojetos dele") : localized("Volta a usar o projeto"))
            }
            .fixedSize()
        } else {
            Button {
                vault.setArchived(project.id, true)
            } label: {
                Label(localized("Arquivar"), systemImage: "archivebox")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Theme.paper.opacity(0.07), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help(hasSubprojects
                ? localized("Guarda o projeto e os subprojetos dele em Arquivados, fora da barra de menus. Nada é apagado.")
                : localized("Guarda o projeto em Arquivados, fora da barra de menus. Nada é apagado."))
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

/// The project's color, on a row of swatches, and its icon, on a grid, each choice applied as it's
/// made and shown in the project's color.
struct ProjectLookPicker: View {
    @Binding var symbol: String
    @Binding var tint: Project.Tint
    private let columns = Array(repeating: GridItem(.fixed(32), spacing: 6), count: 9)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localized("Cor"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.muted)
            HStack(spacing: 8) {
                ForEach(Project.Tint.allCases) { option in
                    let selected = option == tint
                    Button {
                        tint = option
                    } label: {
                        Circle()
                            .fill(Theme.color(option))
                            .frame(width: 20, height: 20)
                            .padding(3)
                            .overlay(Circle().strokeBorder(Theme.paper.opacity(selected ? 0.9 : 0), lineWidth: 1.5))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(option.label)
                    .accessibilityLabel(option.label)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }

            Text(localized("Ícone"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.muted)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Project.symbols, id: \.self) { option in
                        let selected = option == symbol
                        let color = Theme.color(tint)
                        Button {
                            symbol = option
                        } label: {
                            Image(systemName: option)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(selected ? color : Theme.paper.opacity(0.75))
                                .frame(width: 32, height: 32)
                                .background(selected ? color.opacity(0.18) : Theme.paper.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(color.opacity(selected ? 0.6 : 0), lineWidth: 1))
                                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
            .frame(height: 6 * 38)
            .scrollIndicators(.never)
        }
        .padding(16)
        .frame(width: 9 * 32 + 8 * 6 + 32)
        .keysSurface()
    }
}
