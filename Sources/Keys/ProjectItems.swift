import SwiftUI

/// A project's accesses, variables (by environment) and links in a single list: chips to show
/// one kind, a search over names, usernames and addresses (never values), and a button to add
/// any of them.
struct ProjectItemsView: View {
    @Binding var project: Project
    @EnvironmentObject private var vault: Vault
    @State private var query = ""
    @State private var editing: Credential.ID?
    @State private var deletingCredential: Credential.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            controls
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 20)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        // A new access closed without anything typed in it isn't kept.
        .sheet(item: Binding(get: { editing.map(EditingID.init) }, set: { editing = $0?.id }), onDismiss: {
            project.credentials.removeAll { $0.title.isEmpty && $0.url.isEmpty && $0.username.isEmpty && $0.password.isEmpty && $0.notes.isEmpty }
        }) { item in
            if let credential = credentialBinding(item.id) {
                CredentialEditor(credential: credential) {
                    editing = nil
                    deletingCredential = item.id
                }
            }
        }
        .confirmationDialog(
            localized("Apagar o acesso \(project.credentials.first { $0.id == deletingCredential }?.displayTitle ?? "")?"),
            isPresented: Binding(get: { deletingCredential != nil }, set: { if !$0 { deletingCredential = nil } })
        ) {
            Button(localized("Apagar acesso"), role: .destructive) {
                project.credentials.removeAll { $0.id == deletingCredential }
            }
        }
    }

    // MARK: Controls

    private var filter: ProjectSection { vault.section }

    private var controls: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                ForEach(ProjectSection.allCases) { section in
                    chip(section)
                }
            }
            .padding(3)
            .background(Theme.paper.opacity(0.07), in: Capsule())

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                TextField(localized("Buscar no projeto"), text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                if !query.isEmpty {
                    IconButton(symbol: "xmark.circle.fill", help: localized("Limpar a busca")) { query = "" }
                        .frame(width: 18, height: 18)
                }
            }
            .padding(.horizontal, 9)
            .frame(width: 200, height: 28)
            .background(Theme.paper.opacity(0.06), in: Capsule())

            Menu {
                Button(localized("Novo acesso"), systemImage: "key", action: newCredential)
                Button(localized("Nova variável"), systemImage: "curlybraces", action: newVariable)
                Button(localized("Novo ambiente"), systemImage: "square.stack.3d.up", action: newEnvironment)
                Button(localized("Novo link"), systemImage: "link", action: newLink)
            } label: {
                Label(localized("Adicionar"), systemImage: "plus")
            }
            .menuStyle(.button)
            .buttonStyle(PillButtonStyle())
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private func chip(_ section: ProjectSection) -> some View {
        let active = filter == section
        let count = count(section)
        return Button {
            vault.section = section
        } label: {
            HStack(spacing: 5) {
                Text(section.title)
                    .font(.system(size: 12, weight: active ? .semibold : .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11).monospacedDigit())
                        .opacity(0.65)
                }
            }
            .foregroundStyle(active ? Theme.ink : Theme.paper.opacity(0.75))
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(active ? Theme.accent : .clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var variableCount: Int {
        project.environments.reduce(0) { $0 + $1.variables.count }
    }

    private func count(_ section: ProjectSection) -> Int {
        switch section {
        case .all: project.credentials.count + variableCount + project.links.count
        case .credentials: project.credentials.count
        case .variables: variableCount
        case .links: project.links.count
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        let searching = !Search.words(query).isEmpty
        let credentials = project.credentials.filter { $0.matches(query) }
        let environments = project.environments.filter { environment in
            !searching || environment.variables.contains { $0.matches(query) }
        }
        let links = project.links.filter { $0.matches(query) }
        let showsCredentials = filter == .all || filter == .credentials
        let showsVariables = filter == .all || filter == .variables
        let showsLinks = filter == .all || filter == .links

        if filter == .all && !searching && count(.all) == 0 {
            EmptyTab(symbol: "tray", title: localized("Nada por aqui ainda"), text: localized("Os acessos, as variáveis de ambiente e os links do projeto aparecem aqui. Use Adicionar para começar."))
        } else {
            if showsCredentials && (!credentials.isEmpty || (filter == .credentials && !searching)) {
                section(localized("Acessos"), count: credentials.count) {
                    if credentials.isEmpty {
                        EmptyTab(symbol: "key", title: localized("Nenhum acesso"), text: localized("Painéis, bancos de dados, servidores e chaves de API do projeto."))
                    } else {
                        CredentialsSection(credentials: credentials, edit: { editing = $0 }, delete: { deletingCredential = $0 })
                    }
                }
            }
            if showsVariables && (!environments.isEmpty && (searching || filter == .variables || variableCount > 0) || (filter == .variables && !searching)) {
                section(localized("Variáveis"), count: searching ? environments.reduce(0) { $0 + $1.variables.filter { $0.matches(query) }.count } : variableCount) {
                    if project.environments.isEmpty {
                        EmptyTab(symbol: "curlybraces", title: localized("Nenhum ambiente"), text: localized("Crie um ambiente, como development ou production, para guardar as variáveis dele."))
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(environments) { environment in
                                EnvironmentSection(project: $project, environmentID: environment.id, query: query)
                            }
                        }
                    }
                }
            }
            if showsLinks && (!links.isEmpty || (filter == .links && !searching)) {
                section(localized("Links"), count: links.count) {
                    if links.isEmpty {
                        EmptyTab(symbol: "link", title: localized("Nenhum link"), text: localized("Repositório, produção, painéis, documentação."))
                    } else {
                        Card {
                            VStack(spacing: 0) {
                                ForEach(links) { link in
                                    if link.id != links.first?.id { RowDivider() }
                                    if let binding = linkBinding(link.id) {
                                        LinkRow(link: binding) { project.links.removeAll { $0.id == link.id } }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if searching && (showsCredentials ? credentials.isEmpty : true) && (showsVariables ? environments.isEmpty : true) && (showsLinks ? links.isEmpty : true) {
                Text(localized("Nada encontrado."))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private func section<Content: View>(_ title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11.5).monospacedDigit())
                        .foregroundStyle(Theme.muted)
                }
            }
            content()
        }
    }

    // MARK: Adding

    /// After adding something the list may be filtered away from it: it then shows that kind.
    private func reveal(_ section: ProjectSection) {
        query = ""
        if filter != .all && filter != section { vault.section = section }
    }

    private func newCredential() {
        let credential = Credential()
        project.credentials.append(credential)
        reveal(.credentials)
        editing = credential.id
    }

    private func newVariable() {
        if project.environments.isEmpty { project.environments.append(EnvironmentSet(name: "development")) }
        project.environments[0].variables.append(Variable())
        reveal(.variables)
    }

    private func newEnvironment() {
        let names = ["development", "staging", "production"]
        let name = names.first { name in !project.environments.contains { $0.name == name } } ?? "environment"
        project.environments.append(EnvironmentSet(name: name))
        reveal(.variables)
    }

    private func newLink() {
        project.links.append(ProjectLink())
        reveal(.links)
    }

    // MARK: Bindings

    /// The access with `id`, looked up on every read and write rather than by position.
    private func credentialBinding(_ id: Credential.ID) -> Binding<Credential>? {
        guard let current = project.credentials.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { project.credentials.first { $0.id == id } ?? current },
            set: { new in
                if let index = project.credentials.firstIndex(where: { $0.id == id }) { project.credentials[index] = new }
            }
        )
    }

    private func linkBinding(_ id: ProjectLink.ID) -> Binding<ProjectLink>? {
        guard let current = project.links.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { project.links.first { $0.id == id } ?? current },
            set: { new in
                if let index = project.links.firstIndex(where: { $0.id == id }) { project.links[index] = new }
            }
        )
    }

    private struct EditingID: Identifiable {
        let id: Credential.ID
    }
}
