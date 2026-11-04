import SwiftUI

/// One environment in the project's list: its name and menu (import, export, rename, duplicate,
/// delete), then its variables, those matching `query` while there's a search.
struct EnvironmentSection: View {
    @Binding var project: Project
    let environmentID: EnvironmentSet.ID
    var query = ""
    @State private var renaming = false
    @State private var newName = ""
    @State private var confirmingDelete = false
    @State private var notice: String?

    var body: some View {
        if let environment {
            let searching = !Search.words(query).isEmpty
            let visible = environment.variables.filter { $0.matches(query) }
            VStack(alignment: .leading, spacing: 8) {
                header(environment)
                if !visible.isEmpty {
                    Card {
                        VStack(spacing: 0) {
                            ForEach(visible) { variable in
                                if variable.id != visible.first?.id { RowDivider() }
                                if let binding = binding(for: variable.id) {
                                    VariableRow(variable: binding) {
                                        update { $0.variables.removeAll { $0.id == variable.id } }
                                    }
                                }
                            }
                        }
                    }
                } else if !searching {
                    Text(localized("Nenhuma variável. Adicione uma a uma ou importe um arquivo .env."))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .padding(.vertical, 4)
                }
                if !searching {
                    Button {
                        update { $0.variables.append(Variable()) }
                    } label: {
                        Label(localized("Adicionar variável"), systemImage: "plus")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Theme.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .alert(localized("Nome do ambiente"), isPresented: $renaming) {
                TextField("production", text: $newName)
                Button(localized("Salvar")) {
                    if !newName.isEmpty { update { $0.name = newName } }
                }
                Button(localized("Cancelar"), role: .cancel) {}
            }
            .confirmationDialog(localized("Apagar o ambiente \(environment.name)?"), isPresented: $confirmingDelete) {
                Button(localized("Apagar ambiente"), role: .destructive) {
                    project.environments.removeAll { $0.id == environmentID }
                }
            } message: {
                Text(localized("As variáveis dele saem do cofre."))
            }
        }
    }

    private var environment: EnvironmentSet? {
        project.environments.first { $0.id == environmentID }
    }

    private func header(_ environment: EnvironmentSet) -> some View {
        HStack(spacing: 8) {
            Text(environment.name.isEmpty ? localized("Sem nome") : environment.name)
                .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
            Text("\(environment.variables.count)")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(Theme.muted)
            Spacer()
            if let notice {
                Text(notice)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.muted)
                    .transition(.opacity)
            }
            Menu {
                Button(localized("Importar de um arquivo .env…"), action: importFile)
                Button(localized("Colar da área de transferência"), action: importClipboard)
                Divider()
                Button(localized("Copiar como .env")) {
                    Clipboard.copy(environment.dotEnv, secret: true)
                    show(localized("Copiado como .env"))
                }
                .disabled(environment.variables.isEmpty)
                Button(localized("Salvar arquivo .env…"), action: exportFile)
                    .disabled(environment.variables.isEmpty)
                Divider()
                Button(localized("Renomear…")) {
                    newName = environment.name
                    renaming = true
                }
                Button(localized("Duplicar")) { duplicate(environment) }
                Button(localized("Apagar…"), role: .destructive) { confirmingDelete = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(localized("Importar, exportar e organizar o ambiente"))
        }
    }

    /// Changes this environment in place, found by id rather than by position.
    private func update(_ change: (inout EnvironmentSet) -> Void) {
        guard let index = project.environments.firstIndex(where: { $0.id == environmentID }) else { return }
        change(&project.environments[index])
    }

    /// The variable with `id`, looked up on every read and write, so removing one while it's on
    /// screen can't reach past the end of the list.
    private func binding(for id: Variable.ID) -> Binding<Variable>? {
        guard let current = environment?.variables.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { environment?.variables.first { $0.id == id } ?? current },
            set: { new in
                update { environment in
                    if let index = environment.variables.firstIndex(where: { $0.id == id }) { environment.variables[index] = new }
                }
            }
        )
    }

    private func duplicate(_ environment: EnvironmentSet) {
        var copy = environment
        copy.id = UUID()
        copy.name = localized("\(environment.name) (cópia)")
        copy.variables = environment.variables.map { variable in
            var variable = variable
            variable.id = UUID()
            return variable
        }
        project.environments.append(copy)
    }

    private func merge(_ text: String) {
        let entries = DotEnv.parse(text)
        guard !entries.isEmpty else {
            show(localized("Nenhuma variável encontrada"))
            return
        }
        var result = (added: 0, updated: 0)
        update { result = $0.merge(entries) }
        show(localized("\(result.added) novas, \(result.updated) atualizadas"))
    }

    private func importFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.showsHiddenFiles = true
        panel.message = localized("Escolha um arquivo .env")
        if let folder = projectFolder { panel.directoryURL = folder }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            merge(try String(contentsOf: url, encoding: .utf8))
        } catch {
            show(error.localizedDescription)
        }
    }

    private func importClipboard() {
        merge(NSPasteboard.general.string(forType: .string) ?? "")
    }

    /// Writes the set to a file the person picks. The file is plain text, as tools expect it to be.
    private func exportFile() {
        guard let environment else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = environment.name == "development" ? ".env" : ".env.\(environment.name)"
        panel.showsHiddenFiles = true
        panel.message = localized("O arquivo fica sem criptografia, como as ferramentas esperam. Não o coloque no Git.")
        if let folder = projectFolder { panel.directoryURL = folder }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try environment.dotEnv.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            show(localized("Salvo em \(url.lastPathComponent)"))
        } catch {
            show(error.localizedDescription)
        }
    }

    private var projectFolder: URL? {
        let path = (project.localPath as NSString).expandingTildeInPath
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
    }

    private func show(_ text: String) {
        withAnimation { notice = text }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { if notice == text { notice = nil } }
        }
    }
}

struct VariableRow: View {
    @Binding var variable: Variable
    let remove: () -> Void
    @State private var revealed = false

    var body: some View {
        HStack(spacing: 8) {
            TextField("NAME", text: $variable.key)
                .textFieldStyle(.code)
                .frame(width: 230)
            Group {
                if variable.isSecret && !revealed {
                    SecureField(localized("valor"), text: $variable.value)
                } else {
                    TextField(localized("valor"), text: $variable.value)
                }
            }
            .textFieldStyle(.code)
            IconButton(symbol: revealed ? "eye.slash" : "eye", help: revealed ? localized("Ocultar") : localized("Mostrar")) {
                revealed.toggle()
            }
            .opacity(variable.isSecret ? 1 : 0)
            .disabled(!variable.isSecret)
            CopyButton(value: variable.value, secret: variable.isSecret, help: localized("Copiar o valor"))
            IconButton(
                symbol: variable.isSecret ? "lock.fill" : "lock.open",
                help: variable.isSecret ? localized("Secreta: oculta na tela") : localized("Marcar como secreta"),
                color: variable.isSecret ? Theme.accent : Theme.paper.opacity(0.7)
            ) {
                variable.isSecret.toggle()
            }
            IconButton(symbol: "trash", help: localized("Remover"), action: remove)
        }
        .padding(.vertical, 6)
    }
}
