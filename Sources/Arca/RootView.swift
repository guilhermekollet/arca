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
        .arcaSurface()
    }
}

/// Creates the vault on first launch, unlocks it afterwards, and explains when it can't open.
/// Laid out like Mara's introduction: the dotted mark, a title, then what matters.
struct LockScreen: View {
    @EnvironmentObject private var vault: Vault
    @State private var shown = false
    @State private var confirmingNewVault = false

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
        .confirmationDialog(localized("Começar um cofre novo?"), isPresented: $confirmingNewVault) {
            Button(localized("Começar de novo"), role: .destructive) { vault.setAsideUnreadable() }
        } message: {
            Text(localized("O cofre atual não é apagado: ele é renomeado e fica na mesma pasta, caso você recupere a chave."))
        }
    }

    private var title: String {
        switch vault.state {
        case .new: localized("Boas-vindas à Arca")
        case .unreadable: localized("O cofre não abre aqui")
        default: "Arca"
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
            Text(localized("Fica destrancado por \(Preferences.duration(Preferences.unlockMinutes))."))
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .padding(.top, 12)
        case .unreadable(let reason):
            Text(reason)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
            HStack(spacing: 10) {
                Button(localized("Mostrar no Finder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([Vault.fileURL])
                }
                .buttonStyle(PillButtonStyle(prominent: false, large: true))
                Button(localized("Começar um cofre novo…")) { confirmingNewVault = true }
                    .buttonStyle(PillButtonStyle(large: true))
            }
            .padding(.top, 28)
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
    /// The list starts with the keyboard, as in Mail and Notes; otherwise the project's name
    /// field would, with its text selected, one keystroke away from being replaced.
    @FocusState private var listFocused: Bool

    var body: some View {
        NavigationSplitView {
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
            Text(localized("O contexto, as variáveis e os acessos do projeto saem do cofre. A cópia de segurança de antes desta sessão continua em Backups."))
        }
    }

    private var filtered: [Project] {
        vault.projects.filter { $0.matches(query) }
    }

    private var sidebar: some View {
        List(selection: $vault.selection) {
            ForEach(Project.Status.allCases) { status in
                let projects = filtered.filter { $0.status == status }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                if !projects.isEmpty {
                    Section(status.label) {
                        ForEach(projects) { project in
                            ProjectRow(project: project)
                                .tag(project.id)
                                .contextMenu {
                                    Button(localized("Apagar projeto…"), role: .destructive) { deleting = project.id }
                                }
                        }
                    }
                }
            }
        }
        .focused($listFocused)
        .onAppear { listFocused = true }
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

struct ProjectRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: 10) {
            ProjectBadge(project: project, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(project.name.isEmpty ? localized("Sem nome") : project.name)
                    .lineLimit(1)
                if !project.summary.isEmpty {
                    Text(project.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
