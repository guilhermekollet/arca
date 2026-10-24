import SwiftUI

let settingsWindowID = "settings"

/// Settings, laid out like Mara's: a title, then a card per subject.
struct SettingsView: View {
    @EnvironmentObject private var vault: Vault
    @AppStorage(Preferences.lockMinutesKey) private var lockMinutes = 15
    @AppStorage(Preferences.lockOnSleepKey) private var lockOnSleep = true
    @AppStorage(Preferences.clipboardSecondsKey) private var clipboardSeconds = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localized("Ajustes"))
                .font(Theme.display(26))
                .padding(.bottom, 4)

            Card(localized("Segurança"), hint: localized("O cofre também tranca quando você fecha a Arca. Senhas e valores secretos copiados não entram no histórico de gerenciadores de área de transferência.")) {
                VStack(spacing: 8) {
                    row(localized("Trancar sem uso do Mac após")) {
                        Picker(localized("Trancar sem uso do Mac após"), selection: $lockMinutes) {
                            ForEach(Preferences.lockMinuteChoices, id: \.self) { minutes in
                                Text(minutes == 0 ? localized("Nunca") : localized("\(minutes) min")).tag(minutes)
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
                        .controlSize(.small)
                        .font(.system(size: 12.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Card(localized("Cofre"), hint: localized("O arquivo e as cópias são criptografados e só abrem neste Mac, com a chave do Secure Enclave. A Arca guarda as \(Vault.backupCount) cópias mais recentes, uma por sessão.")) {
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

            HStack(spacing: 6) {
                Text("Arca \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                Text("·")
                Link(localized("Código-fonte no GitHub"), destination: URL(string: "https://github.com/guilhermekollet/arca")!)
                    .foregroundStyle(Theme.accent)
            }
            .font(.system(size: 11.5))
            .foregroundStyle(Theme.muted)
        }
        .padding(22)
        .frame(width: 460, alignment: .topLeading)
        .arcaSurface()
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
