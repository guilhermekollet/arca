import SwiftUI
import UniformTypeIdentifiers

/// A backup file the person picked, as an item a sheet can be presented for.
struct BackupFile: Identifiable {
    let url: URL
    var id: URL { url }
}

/// Asks for a backup file to import.
@MainActor
func chooseBackupFile() -> BackupFile? {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowedContentTypes = [UTType(filenameExtension: VaultBackup.fileExtension) ?? .data]
    panel.message = localized("Escolha o arquivo de backup")
    guard panel.runModal() == .OK, let url = panel.url else { return nil }
    return BackupFile(url: url)
}

/// Settings' card for taking the vault to another Mac: export a backup, import one.
struct BackupCard: View {
    @EnvironmentObject private var vault: Vault
    @AppStorage(Preferences.lastBackupKey) private var lastBackup: Double = 0
    @State private var exporting = false
    @State private var importing: BackupFile?

    var body: some View {
        Card(localized("Backup e migração"), hint: localized("Para levar o cofre a outro Mac, ou guardar uma cópia fora deste caso ele se perca. O backup é protegido por uma senha que você escolhe e que não fica guardada.")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button(localized("Exportar backup…")) { exporting = true }
                    Button(localized("Importar backup…")) { importing = chooseBackupFile() }
                }
                .buttonStyle(PillButtonStyle(prominent: false))
                .disabled(vault.state != .unlocked)
                Text(status)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.muted)
            }
        }
        .sheet(isPresented: $exporting) { ExportBackupSheet() }
        .sheet(item: $importing) { file in ImportBackupSheet(file: file) }
    }

    private var status: String {
        if vault.state != .unlocked { return localized("Destranque o cofre para exportar ou importar.") }
        guard lastBackup > 0 else { return localized("Nenhum backup exportado ainda.") }
        let date = Date(timeIntervalSinceReferenceDate: lastBackup).formatted(date: .abbreviated, time: .omitted)
        return localized("Último backup: \(date)")
    }
}

/// Chooses a password and writes the backup where the person picks.
struct ExportBackupSheet: View {
    @EnvironmentObject private var vault: Vault
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmation = ""
    @State private var working = false
    @State private var problem: String?
    @State private var saved: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localized("Exportar backup"))
                .font(Theme.display(22))
            if let saved {
                Label(localized("Backup salvo em \(saved.lastPathComponent)."), systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.accent)
                Text(localized("Guarde o arquivo e a senha em lugares diferentes. Para usar em outro Mac, abra o app lá e escolha “Tenho um backup de outro Mac”."))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(localized("Mostrar no Finder")) { NSWorkspace.shared.activateFileViewerSelecting([saved]) }
                        .buttonStyle(PillButtonStyle(prominent: false))
                    Spacer()
                    Button(localized("Pronto")) { dismiss() }
                        .buttonStyle(PillButtonStyle())
                        .keyboardShortcut(.defaultAction)
                }
            } else {
                Text(localized("Um arquivo com todo o cofre, protegido por uma senha que você escolhe agora. Serve para levar o cofre a outro Mac ou para guardar fora deste. A senha não fica guardada em lugar nenhum: sem ela, ninguém abre o backup, nem você."))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Card(hint: localized("Pelo menos \(VaultBackup.minimumPasswordLength) caracteres. Uma frase longa é mais forte e mais fácil de lembrar.")) {
                    VStack(spacing: 8) {
                        SecureField(localized("Senha do backup"), text: $password)
                            .textFieldStyle(.field)
                        SecureField(localized("Repita a senha"), text: $confirmation)
                            .textFieldStyle(.field)
                            .onSubmit(export)
                    }
                }
                if let problem {
                    Text(problem)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    if working {
                        ProgressView().controlSize(.small)
                        Text(localized("Protegendo o backup…"))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button(localized("Cancelar")) { dismiss() }
                        .buttonStyle(PillButtonStyle(prominent: false))
                        .keyboardShortcut(.cancelAction)
                    Button(localized("Exportar…"), action: export)
                        .buttonStyle(PillButtonStyle())
                        .keyboardShortcut(.defaultAction)
                        .disabled(working || password.isEmpty)
                }
            }
        }
        .padding(22)
        .frame(width: 460)
        .keysSurface()
    }

    private func export() {
        problem = nil
        guard password.count >= VaultBackup.minimumPasswordLength else { return problem = BackupError.weakPassword.localizedDescription }
        guard password == confirmation else { return problem = BackupError.passwordsDiffer.localizedDescription }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = VaultBackup.suggestedFileName()
        panel.allowedContentTypes = [UTType(filenameExtension: VaultBackup.fileExtension) ?? .data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        working = true
        Task {
            defer { working = false }
            do {
                try await vault.exportBackup(password: password, to: url)
                password = ""
                confirmation = ""
                saved = url
            } catch {
                problem = error.localizedDescription
            }
        }
    }
}

/// Asks for the password of `file` and brings it in: merged into an open vault, or as the vault
/// of a Mac that has none (or one it can't open).
struct ImportBackupSheet: View {
    let file: BackupFile
    @EnvironmentObject private var vault: Vault
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var working = false
    @State private var problem: String?
    @State private var result: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localized("Importar backup"))
                .font(Theme.display(22))
            if let result {
                Label(result, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.accent)
                HStack {
                    Spacer()
                    Button(localized("Pronto")) { dismiss() }
                        .buttonStyle(PillButtonStyle())
                        .keyboardShortcut(.defaultAction)
                }
            } else {
                Label(file.url.lastPathComponent, systemImage: "doc.badge.arrow.up")
                    .font(.system(size: 12.5, weight: .medium))
                Text(explanation)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                SecureField(localized("Senha do backup"), text: $password)
                    .textFieldStyle(.field)
                    .onSubmit(bringIn)
                if let problem {
                    Text(problem)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    if working {
                        ProgressView().controlSize(.small)
                        Text(localized("Abrindo o backup…"))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button(localized("Cancelar")) { dismiss() }
                        .buttonStyle(PillButtonStyle(prominent: false))
                        .keyboardShortcut(.cancelAction)
                    Button(localized("Importar"), action: bringIn)
                        .buttonStyle(PillButtonStyle())
                        .keyboardShortcut(.defaultAction)
                        .disabled(working || password.isEmpty)
                }
            }
        }
        .padding(22)
        .frame(width: 460)
        .keysSurface()
    }

    private var explanation: String {
        switch vault.state {
        case .unlocked:
            localized("Os projetos do backup entram no cofre. Um projeto que já existe fica com a versão alterada por último; nada é apagado.")
        case .unreadable:
            localized("O backup vira o cofre deste Mac. O cofre que não abre aqui não é apagado: ele é renomeado e fica na mesma pasta.")
        default:
            localized("O backup vira o cofre deste Mac, que passa a abrir com o Touch ID daqui.")
        }
    }

    private func bringIn() {
        guard !password.isEmpty, !working else { return }
        problem = nil
        let merging = vault.state == .unlocked
        working = true
        Task {
            defer { working = false }
            do {
                let counts = try await vault.importBackup(from: file.url, password: password)
                password = ""
                result = merging
                    ? localized("Projetos novos: \(counts.added) · atualizados: \(counts.updated)")
                    : localized("Projetos importados: \(counts.added)")
            } catch {
                problem = error.localizedDescription
            }
        }
    }
}
