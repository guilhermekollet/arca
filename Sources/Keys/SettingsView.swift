import SwiftUI

let settingsWindowID = "settings"

/// Settings, laid out like Mara's: a title with icon tabs, then a card per subject.
struct SettingsView: View {
    @State private var tab: Tab

    /// `tab` opens Settings on another tab (used by Snapshot).
    init(tab: Tab = .general) {
        _tab = State(initialValue: tab)
    }

    enum Tab: CaseIterable, Identifiable {
        case general, archived
        var id: Self { self }

        var title: String {
            switch self {
            case .general: localized("Geral")
            case .archived: localized("Arquivados")
            }
        }

        var symbol: String {
            switch self {
            case .general: "gearshape"
            case .archived: "archivebox"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(localized("Ajustes"))
                    .font(Theme.display(26))
                Spacer()
                CapsuleTabs(tabs: Tab.allCases, selection: $tab, title: \.title, symbol: \.symbol)
            }
            .padding([.horizontal, .top], 22)
            .padding(.bottom, 14)

            // The window keeps one size and the content scrolls, as in Mara: resizing a window on
            // every tab switch has crashed AppKit on macOS 26.
            ScrollView {
                Group {
                    switch tab {
                    case .general: GeneralSettings()
                    case .archived: ArchivedSettings()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
            }
            .scrollBounceBehavior(.basedOnSize)
            // Each tab starts at the top.
            .id(tab)
        }
        .frame(width: 480, height: 640, alignment: .topLeading)
        .keysSurface()
    }
}

/// Security, the vault's file, backups and the app's version.
private struct GeneralSettings: View {
    @EnvironmentObject private var vault: Vault
    @AppStorage(Preferences.unlockMinutesKey) private var unlockMinutes = 120
    @AppStorage(Preferences.lockMinutesKey) private var lockMinutes = 0
    @AppStorage(Preferences.lockOnSleepKey) private var lockOnSleep = true
    @AppStorage(Preferences.clipboardSecondsKey) private var clipboardSeconds = 30
    @AppStorage(Preferences.appearanceKey) private var appearance = Preferences.Appearance.system

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Card(localized("Aparência")) {
                row(localized("Tema")) {
                    Picker(localized("Tema"), selection: $appearance) {
                        ForEach(Preferences.Appearance.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }
            }
            .onChange(of: appearance) { Preferences.applyAppearance() }

            Card(localized("Segurança"), hint: localized("Touch ID destranca o cofre pelo tempo escolhido; depois ele tranca e pede de novo. Também tranca quando você fecha o Chaves. Senhas e valores secretos copiados não entram no histórico de gerenciadores de área de transferência.")) {
                VStack(spacing: 8) {
                    row(localized("Ficar destrancado por")) {
                        Picker(localized("Ficar destrancado por"), selection: $unlockMinutes) {
                            ForEach(Preferences.unlockMinuteChoices, id: \.self) { minutes in
                                Text(Preferences.duration(minutes)).tag(minutes)
                            }
                        }
                    }
                    row(localized("Trancar antes, sem uso do Mac após")) {
                        Picker(localized("Trancar antes, sem uso do Mac após"), selection: $lockMinutes) {
                            ForEach(Preferences.lockMinuteChoices, id: \.self) { minutes in
                                Text(minutes == 0 ? localized("Nunca") : Preferences.duration(minutes)).tag(minutes)
                            }
                        }
                    }
                    row(localized("Limpar senhas copiadas após")) {
                        Picker(localized("Limpar senhas copiadas após"), selection: $clipboardSeconds) {
                            ForEach(Preferences.clipboardSecondChoices, id: \.self) { seconds in
                                Text(seconds == 0 ? localized("Nunca") : localized("\(seconds) s")).tag(seconds)
                            }
                        }
                    }
                    Toggle(localized("Trancar quando o Mac dormir ou a tela bloquear"), isOn: $lockOnSleep)
                        .toggleStyle(.switch)
                        // A step softer than the contrast color, so the white knob still shows on
                        // the dark look.
                        .tint(Theme.paper.opacity(0.55))
                        .controlSize(.small)
                        .font(.system(size: 12.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Card(localized("Cofre"), hint: localized("O arquivo e as cópias são criptografados e só abrem neste Mac, com a chave do Secure Enclave. O Chaves guarda as \(Vault.backupCount) cópias mais recentes, uma por sessão.")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text((Vault.fileURL.path as NSString).abbreviatingWithTildeInPath)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                        .textSelection(.enabled)
                    HStack(spacing: 8) {
                        Button(localized("Mostrar no Finder")) {
                            NSWorkspace.shared.activateFileViewerSelecting([Vault.fileURL])
                        }
                        .disabled(vault.isSample)
                        Button(localized("Cópias de segurança")) {
                            NSWorkspace.shared.open(Vault.backupsURL)
                        }
                        .disabled(!FileManager.default.fileExists(atPath: Vault.backupsURL.path))
                    }
                    .buttonStyle(PillButtonStyle(prominent: false))
                }
            }

            BackupCard()

            HStack(spacing: 6) {
                Text("\(appName) \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                Text("·")
                Link(localized("Código-fonte no GitHub"), destination: URL(string: "https://github.com/guilhermekollet/keys")!)
                    .foregroundStyle(Theme.accent)
            }
            .font(.system(size: 11.5))
            .foregroundStyle(Theme.muted)
        }
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12.5))
            Spacer()
            content()
                .labelsHidden()
                .fixedSize()
        }
    }
}

/// The archived projects, the only place they show: bring one back, or delete it for good.
private struct ArchivedSettings: View {
    @EnvironmentObject private var vault: Vault
    @State private var deleting: Project.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if vault.state != .unlocked {
                EmptyTab(symbol: "lock", title: localized("O cofre está trancado."), text: localized("Destranque o cofre para ver os projetos arquivados."))
            } else if archived.isEmpty {
                EmptyTab(symbol: "archivebox", title: localized("Nenhum projeto arquivado"), text: localized("Arquive pelo cabeçalho do projeto ou pelo clique direito na barra lateral. O projeto sai da barra lateral, das buscas e da barra de menus, e fica aqui."))
            } else {
                Card(hint: localized("Desarquivar devolve o projeto, com os subprojetos, ao lugar de antes. Apagar não tem volta aqui; a cópia de segurança de antes desta sessão continua em Backups.")) {
                    VStack(spacing: 0) {
                        ForEach(archived) { project in
                            if project.id != archived.first?.id { RowDivider() }
                            ArchivedRow(project: project) { deleting = project.id }
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            localized("Apagar \(vault.project(deleting)?.name ?? "") de vez?"),
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
        ) {
            Button(localized("Apagar de vez"), role: .destructive) {
                if let deleting { vault.deleteWithSubprojects(deleting) }
            }
        } message: {
            let inside = deleting.map { ProjectTree.descendantIDs(of: $0, in: vault.projects).count } ?? 0
            if inside > 0 {
                Text(localized("O contexto, as variáveis e os acessos saem do cofre, junto com os subprojetos arquivados com ele (\(inside)). A cópia de segurança de antes desta sessão continua em Backups."))
            } else {
                Text(localized("O contexto, as variáveis e os acessos saem do cofre. A cópia de segurança de antes desta sessão continua em Backups."))
            }
        }
    }

    /// The archived projects at the top of their tree; their archived subprojects go with them.
    private var archived: [Project] {
        ProjectTree.roots(archived: true, in: vault.projects)
    }
}

private struct ArchivedRow: View {
    let project: Project
    let delete: () -> Void
    @EnvironmentObject private var vault: Vault

    var body: some View {
        let inside = ProjectTree.descendantIDs(of: project.id, in: vault.projects).count
        let parent = ProjectTree.ancestors(of: project, in: vault.projects).last
        HStack(spacing: 10) {
            ProjectBadge(project: project, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name.isEmpty ? localized("Sem nome") : project.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let archivedAt = project.archivedAt {
                        Text(localized("Arquivado em \(archivedAt.formatted(date: .numeric, time: .omitted))"))
                    }
                    if let parent {
                        Text("·")
                        Text(localized("Em \(parent.name)"))
                    }
                    if inside > 0 {
                        Label("\(inside)", systemImage: "folder")
                            .labelStyle(.titleAndIcon)
                            .help(localized("Subprojetos arquivados com ele"))
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button(localized("Desarquivar")) { vault.setArchived(project.id, false) }
                .buttonStyle(PillButtonStyle(prominent: false))
                .fixedSize()
            IconButton(symbol: "trash", help: localized("Apagar de vez…"), color: .red.opacity(0.85), action: delete)
        }
        .padding(.vertical, 7)
    }
}
