import SwiftUI

/// Opens from the menu bar icon: a search across every project that copies an access or a
/// variable without opening the main window. Laid out like Mara's panel.
struct MenuBarPanel: View {
    @EnvironmentObject private var vault: Vault
    @Environment(\.openWindow) private var openWindow
    @State private var query: String
    @FocusState private var searchFocused: Bool

    /// `query` starts the search already typed (used by Snapshot).
    init(query: String = "") {
        _query = State(initialValue: query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if vault.state == .unlocked {
                TextField(localized("Buscar acesso ou variável"), text: $query)
                    .textFieldStyle(.field)
                    .focused($searchFocused)
                    .onAppear { searchFocused = true }
                results
            } else {
                lockedCard
            }
            Divider().overlay(Theme.paper.opacity(0.12))
            footer
        }
        .padding(14)
        .frame(width: 320)
        .arcaSurface()
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

    private var lockedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(vault.state == .new ? localized("Crie o cofre para começar.") : localized("O cofre está trancado."))
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
            Button {
                if vault.state == .locked {
                    Task { await vault.unlock() }
                } else {
                    present(mainWindowID, using: openWindow)
                }
            } label: {
                if vault.state == .locked {
                    Label(localized("Destrancar"), systemImage: "touchid")
                } else {
                    Text(localized("Abrir a Arca"))
                }
            }
            .buttonStyle(PillButtonStyle())
            .disabled(vault.isUnlocking)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var results: some View {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            let recent = vault.projects.filter { $0.status != .archived }.sorted { $0.updatedAt > $1.updatedAt }.prefix(6)
            if recent.isEmpty {
                Text(localized("Nenhum projeto ainda."))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(localized("Recentes"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .padding(.bottom, 4)
                    ForEach(Array(recent)) { project in
                        RecentRow(project: project) { open(project.id, at: .context) }
                    }
                }
            }
        } else {
            let matches = Search.quickMatches(in: vault.projects, query: query, limit: 12)
            if matches.isEmpty {
                Text(localized("Nada encontrado."))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(matches) { match in
                            if match.id != matches.first?.id { RowDivider() }
                            QuickMatchRow(match: match) {
                                switch match.item {
                                case .credential: open(match.projectID, at: .credentials)
                                case .variable: open(match.projectID, at: .variables)
                                }
                            }
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: 340)
            }
        }
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

    private func open(_ id: Project.ID, at section: ProjectSection) {
        vault.selection = id
        vault.section = section
        present(mainWindowID, using: openWindow)
    }
}

private struct RecentRow: View {
    let project: Project
    let open: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: open) {
            HStack(spacing: 8) {
                ProjectBadge(project: project, size: 20)
                Text(project.name)
                    .font(.system(size: 12.5))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Theme.paper.opacity(hovering ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct QuickMatchRow: View {
    let match: QuickMatch
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
            .help(localized("Abrir no projeto"))
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
        switch match.item {
        case .credential(let credential):
            credential.username.isEmpty ? match.projectName : "\(match.projectName) · \(credential.username)"
        case .variable(_, let environment):
            "\(match.projectName) · \(environment)"
        }
    }
}
