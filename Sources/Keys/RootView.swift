import SwiftUI

/// The main window: the lock screen until the vault opens, then the projects.
struct RootView: View {
    @EnvironmentObject private var vault: Vault

    var body: some View {
        Group {
            if vault.state == .unlocked {
                MainView()
            } else {
                LockScreen()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vault.state)
        .keysSurface()
    }
}

/// Creates the vault on first launch, unlocks it afterwards, and explains when it can't open.
/// Laid out like Mara's introduction: the dotted mark, a title, then what matters.
struct LockScreen: View {
    @EnvironmentObject private var vault: Vault
    @State private var shown = false
    @State private var confirmingNewVault = false
    @State private var importing: BackupFile?

    private let features: [(symbol: String, title: String, text: String)] = [
        ("text.page", localized("O contexto de cada projeto"), localized("Como rodar, como publicar, onde está cada coisa e por que foi feito assim, para retomar meses depois.")),
        ("curlybraces", localized("Variáveis e acessos juntos"), localized("Os .env de cada ambiente, os painéis, os bancos e as chaves de API, a um clique de copiar.")),
        ("lock.laptopcomputer", localized("Só neste Mac"), localized("A chave fica no Secure Enclave e só abre com Touch ID ou a senha do Mac. Nada vai para a internet.")),
    ]

    var body: some View {
        VStack(spacing: 0) {
            DotMark(shown: shown)
                .frame(height: 64)
            Text(title)
                .font(Theme.display(32))
                .multilineTextAlignment(.center)
                .padding(.top, 22)
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 6)
                .animation(.easeOut(duration: 0.5).delay(0.35), value: shown)
            content
                .opacity(shown ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.5), value: shown)
            if let problem = vault.problem {
                Text(problem)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
            }
        }
        .frame(maxWidth: 440)
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            shown = true
            if vault.state == .locked && !vault.askedOnLaunch {
                vault.askedOnLaunch = true
                Task { await vault.unlock() }
            }
        }
        .sheet(item: $importing) { file in ImportBackupSheet(file: file) }
        .confirmationDialog(localized("Começar um cofre novo?"), isPresented: $confirmingNewVault) {
            Button(localized("Começar de novo"), role: .destructive) { vault.setAsideUnreadable() }
        } message: {
            Text(localized("O cofre atual não é apagado: ele é renomeado e fica na mesma pasta, caso você recupere a chave."))
        }
    }

    private var title: String {
        switch vault.state {
        case .new: localized("Boas-vindas ao Chaves")
        case .unreadable: localized("O cofre não abre aqui")
        default: appName
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vault.state {
        case .new:
            VStack(alignment: .leading, spacing: 20) {
                ForEach(features, id: \.title) { feature in
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: feature.symbol)
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Theme.accent)
                            .frame(width: 34)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(feature.title)
                                .font(.system(size: 14, weight: .semibold))
                            Text(feature.text)
                                .font(.system(size: 12.5))
                                .lineSpacing(1.5)
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.top, 34)
            Button(localized("Criar cofre")) { vault.create() }
                .buttonStyle(PillButtonStyle(large: true))
                .keyboardShortcut(.defaultAction)
                .disabled(!DeviceKey.isAvailable)
                .padding(.top, 34)
            // Moving from another Mac: the vault comes from a backup instead of starting empty.
            Button(localized("Tenho um backup de outro Mac")) { importing = chooseBackupFile() }
                .buttonStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.accent)
                .disabled(!DeviceKey.isAvailable)
                .padding(.top, 14)
            if !DeviceKey.isAvailable {
                Text(VaultError.noSecureEnclave.localizedDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .padding(.top, 10)
            }
        case .locked:
            Text(localized("O cofre está trancado."))
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .padding(.top, 8)
            Button {
                Task { await vault.unlock() }
            } label: {
                Label(localized("Destrancar com Touch ID"), systemImage: "touchid")
            }
            .buttonStyle(PillButtonStyle(large: true))
            .keyboardShortcut(.defaultAction)
            .disabled(vault.isUnlocking)
            .padding(.top, 28)
        case .unreadable(let reason):
            Text(reason)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
            // The way back for a vault copied from another Mac: its backup, made there.
            Button(localized("Importar backup…")) { importing = chooseBackupFile() }
                .buttonStyle(PillButtonStyle(large: true))
                .padding(.top, 28)
            HStack(spacing: 10) {
                Button(localized("Mostrar no Finder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([Vault.fileURL])
                }
                Button(localized("Começar um cofre novo…")) { confirmingNewVault = true }
            }
            .buttonStyle(PillButtonStyle(prominent: false))
            .padding(.top, 12)
        case .unlocked:
            EmptyView()
        }
    }
}

/// The projects in a sidebar and the selected one beside it.
struct MainView: View {
    @EnvironmentObject private var vault: Vault
    @State private var query = ""
    @State private var deleting: Project.ID?
    /// Projects whose subprojects are folded away in the sidebar; everything starts unfolded.
    @State private var collapsed: Set<Project.ID> = []
    /// The list starts with the keyboard, as in Mail and Notes; otherwise the project's name
    /// field would, with its text selected, one keystroke away from being replaced.
    @FocusState private var listFocused: Bool
    /// Followed, not driven: the sidebar button folds it with AppKit (see toggleSidebar).
    @State private var columns = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 340)
        } detail: {
            Group {
                if let id = vault.selection, let project = vault.binding(for: id) {
                    ProjectView(project: project)
                        .id(id)
                } else {
                    emptyDetail
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.ink)
        }
        .searchable(text: $query, placement: .sidebar, prompt: localized("Buscar em tudo"))
        // When the list folds away with the keyboard, AppKit hands the keyboard to the next field,
        // the project's name, with its text selected: one stray key would replace the name. So
        // nothing takes it then, and it goes back to the list when the sidebar returns.
        .onChange(of: columns) {
            if columns == .detailOnly {
                DispatchQueue.main.async {
                    NSApp.windows.first { $0.identifier?.rawValue == mainWindowID }?.makeFirstResponder(nil)
                }
            } else {
                DispatchQueue.main.async { listFocused = true }
            }
        }
        .toolbar {
            ToolbarItem {
                Button { vault.addProject() } label: {
                    Label(localized("Novo projeto"), systemImage: "plus")
                }
                .help(localized("Novo projeto (⌘N)"))
            }
            ToolbarItem {
                Button { vault.lock() } label: {
                    Label(localized("Trancar"), systemImage: "lock")
                }
                .help(vault.isSample ? localized("O cofre de exemplo não tranca") : localized("Trancar o cofre (⇧⌘L)"))
                .disabled(vault.isSample)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let problem = vault.problem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(.red.opacity(0.2))
            }
        }
        .confirmationDialog(
            localized("Apagar \(vault.project(deleting)?.name ?? "")?"),
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
        ) {
            Button(localized("Apagar projeto"), role: .destructive) {
                if let deleting { vault.deleteProject(deleting) }
            }
        } message: {
            if let deleting, !ProjectTree.children(of: deleting, in: vault.projects).isEmpty {
                Text(localized("O contexto, as variáveis e os acessos do projeto saem do cofre. Os subprojetos ficam, um nível acima."))
            } else {
                Text(localized("O contexto, as variáveis e os acessos do projeto saem do cofre. A cópia de segurança de antes desta sessão continua em Backups."))
            }
        }
    }

    private var filtered: [Project] {
        vault.projects.filter { $0.matches(query) }
    }

    /// The projects in the order the sidebar shows them, for moving with the arrow keys.
    private var visibleOrder: [Project.ID] {
        guard Search.words(query).isEmpty else { return searchResults.map(\.id) }
        var order: [Project.ID] = []
        func walk(_ project: Project) {
            order.append(project.id)
            guard !collapsed.contains(project.id) else { return }
            ProjectTree.children(of: project.id, in: vault.projects).forEach(walk)
        }
        let roots = ProjectTree.children(of: nil, in: vault.projects)
        for status in Project.Status.allCases {
            roots.filter { $0.status == status }.forEach(walk)
        }
        return order
    }

    private var searchResults: [Project] {
        filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Unfolds the projects above `id`, so the open project is never hidden in a folded group.
    private func reveal(_ id: Project.ID?) {
        guard let project = vault.project(id) else { return }
        for ancestor in ProjectTree.ancestors(of: project, in: vault.projects) {
            collapsed.remove(ancestor.id)
        }
    }

    private func moveSelection(by step: Int) -> KeyPress.Result {
        let order = visibleOrder
        guard !order.isEmpty else { return .ignored }
        // A selection hidden in a folded group counts from the nearest group that shows.
        var anchor = vault.selection
        if let project = vault.project(anchor), !order.contains(project.id) {
            anchor = ProjectTree.ancestors(of: project, in: vault.projects).last { order.contains($0.id) }?.id
        }
        let current = order.firstIndex { $0 == anchor }
        let next = current.map { min(max($0 + step, 0), order.count - 1) } ?? (step > 0 ? 0 : order.count - 1)
        vault.selection = order[next]
        return .handled
    }

    /// Folds or unfolds the sidebar with AppKit's own toggle, so it moves with the system's
    /// animation (the one the system button runs), not a SwiftUI animation layered over the split
    /// view's. It goes up the main window's own responder chain: `NSApp.sendAction(to: nil)` only
    /// reaches the window that is active, which isn't always this one.
    private func toggleSidebar() {
        let action = #selector(NSSplitViewController.toggleSidebar(_:))
        guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == mainWindowID }) else { return }
        let start: NSResponder? = window.firstResponder ?? window.contentView
        if start?.tryToPerform(action, with: nil) != true {
            NSApp.sendAction(action, to: nil, from: nil)
        }
    }

    /// Shows or hides the sidebar, with the app's own icon (the system's button can't take one).
    private var sidebarButton: some View {
        Button {
            toggleSidebar()
        } label: {
            SidebarButtonLabel()
        }
        .buttonStyle(.plain)
        .keyboardShortcut("s", modifiers: [.control, .command])
        .help(localized("Mostrar ou ocultar a barra lateral (⌃⌘S)"))
        .accessibilityLabel(localized("Mostrar ou ocultar a barra lateral"))
    }

    private var sidebar: some View {
        // The list draws no selection of its own: the system's would be a strong accent color.
        // Each row shows its own quiet highlight (see ProjectRow), and the arrow keys and Delete
        // still work while the list has the keyboard.
        List {
            if Search.words(query).isEmpty {
                // The tree: top-level projects grouped by status, each with what's inside it.
                ForEach(Project.Status.allCases) { status in
                    let roots = ProjectTree.children(of: nil, in: vault.projects).filter { $0.status == status }
                    if !roots.isEmpty {
                        Section(status.label) {
                            ForEach(roots) { project in
                                ProjectTreeRow(project: project, collapsed: $collapsed, actions: rowActions)
                            }
                        }
                    }
                }
            } else {
                // A search shows what matched as a flat list, each with the path to it.
                ForEach(searchResults) { project in
                    SelectableProjectRow(project: project, path: ProjectTree.ancestors(of: project, in: vault.projects).map(\.name))
                        .contextMenu { rowActions(project) }
                }
            }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($listFocused)
        // The keyboard starts on the list, never in a text field: a project's name field with
        // the focus has its text selected, so the first keystroke would replace the name.
        .defaultFocus($listFocused, true)
        .onAppear { DispatchQueue.main.async { listFocused = true } }
        // The sidebar's own button, where the system's would be, in place of it. macOS keeps it
        // in the title bar while the sidebar is hidden, so it also brings the sidebar back.
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .automatic) { sidebarButton }
                // No glass capsule behind it: macOS 26 gives every toolbar item one, which made
                // this button look like a circle. It highlights on its own instead.
                .sharedBackgroundVisibility(.hidden)
        }
        .onChange(of: vault.selection, initial: true) { reveal(vault.selection) }
        .onKeyPress(.upArrow) { moveSelection(by: -1) }
        .onKeyPress(.downArrow) { moveSelection(by: 1) }
        // The Delete key asks before removing the selected project, as in Finder and Mail.
        .onDeleteCommand { deleting = vault.selection }
        .overlay {
            if vault.projects.isEmpty {
                ContentUnavailableView {
                    Label(localized("Nenhum projeto ainda"), systemImage: "shippingbox")
                } actions: {
                    Button(localized("Novo projeto")) { vault.addProject() }
                        .buttonStyle(PillButtonStyle())
                }
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    @ViewBuilder
    private func rowActions(_ project: Project) -> some View {
        Button(localized("Novo subprojeto")) { vault.addProject(inside: project.id) }
        Divider()
        Button(localized("Apagar projeto…"), role: .destructive) { deleting = project.id }
    }

    private var emptyDetail: some View {
        VStack(spacing: 14) {
            DotMark(shown: true, dot: 6, spacing: 3.5)
                .opacity(0.5)
            Text(localized("Escolha um projeto"))
                .font(Theme.display(22))
            Text(localized("Cada projeto guarda o contexto para retomá-lo, as variáveis de ambiente e os acessos."))
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
    }
}

/// A project in the sidebar and, under a disclosure triangle, the projects inside it.
struct ProjectTreeRow<Actions: View>: View {
    let project: Project
    @Binding var collapsed: Set<Project.ID>
    let actions: (Project) -> Actions
    @EnvironmentObject private var vault: Vault

    var body: some View {
        let children = ProjectTree.children(of: project.id, in: vault.projects)
        if children.isEmpty {
            row
        } else {
            DisclosureGroup(isExpanded: Binding(
                get: { !collapsed.contains(project.id) },
                set: { expanded in
                    if expanded { collapsed.remove(project.id) } else { collapsed.insert(project.id) }
                }
            )) {
                // Type-erased: the row contains rows of its own type.
                ForEach(children) { child in
                    AnyView(ProjectTreeRow(project: child, collapsed: $collapsed, actions: actions))
                }
            } label: {
                row
            }
        }
    }

    private var row: some View {
        SelectableProjectRow(project: project)
            .contextMenu { actions(project) }
    }
}

/// A project row that opens the project when clicked and shows whether it's the open one.
struct SelectableProjectRow: View {
    let project: Project
    var path: [String] = []
    @EnvironmentObject private var vault: Vault

    var body: some View {
        let selected = vault.selection == project.id
        // A button rather than a tap gesture, so VoiceOver and other assistive tools can open it too.
        Button {
            vault.selection = project.id
        } label: {
            ProjectRow(project: project, path: path, selected: selected)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ProjectRow: View {
    let project: Project
    /// The names of the projects above it, shown when the tree isn't (in a search).
    var path: [String] = []
    /// The open project: a quiet surface behind it and its name in semibold, in the app's own
    /// colors rather than the system's accent.
    var selected = false
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            ProjectBadge(project: project, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(project.name.isEmpty ? localized("Sem nome") : project.name)
                    .fontWeight(selected ? .semibold : .regular)
                    .foregroundStyle(selected ? Theme.paper : Theme.paper.opacity(0.85))
                    .lineLimit(1)
                if !path.isEmpty {
                    Text(path.joined(separator: " › "))
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                } else if !project.summary.isEmpty {
                    Text(project.summary)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            Theme.paper.opacity(selected ? 0.09 : hovering ? 0.04 : 0),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .onHover { hovering = $0 }
    }
}
