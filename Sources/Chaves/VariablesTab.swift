import SwiftUI

/// The project's environment variables, one set per environment, imported from and exported to
/// `.env` files.
struct VariablesTab: View {
    @Binding var project: Project
    @State private var environmentID: EnvironmentSet.ID?
    @State private var renaming = false
    @State private var newName = ""
    @State private var confirmingDelete = false
    @State private var notice: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
                .padding(.horizontal, 20)
                .padding(.top, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let environment = selectedBinding {
                        EnvironmentEditor(environment: environment)
                    } else {
                        EmptyTab(symbol: "curlybraces", title: localized("Nenhum ambiente"), text: localized("Crie um ambiente, como development ou production, para guardar as variáveis dele."))
                        Button(localized("Novo ambiente")) { addEnvironment() }
                            .buttonStyle(PillButtonStyle())
                    }
                }
                .padding(20)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear {
            if selected == nil { environmentID = project.environments.first?.id }
        }
        .alert(localized("Nome do ambiente"), isPresented: $renaming) {
            TextField("production", text: $newName)
            Button(localized("Salvar")) {
                if let index = selectedIndex, !newName.isEmpty { project.environments[index].name = newName }
            }
            Button(localized("Cancelar"), role: .cancel) {}
        }
        .confirmationDialog(localized("Apagar o ambiente \(selected?.name ?? "")?"), isPresented: $confirmingDelete) {
            Button(localized("Apagar ambiente"), role: .destructive) {
                project.environments.removeAll { $0.id == environmentID }
                environmentID = project.environments.first?.id
            }
        } message: {
            Text(localized("As variáveis dele saem do cofre."))
        }
    }

    private var selectedIndex: Int? {
        project.environments.firstIndex { $0.id == environmentID }
    }

    private var selected: EnvironmentSet? {
        selectedIndex.map { project.environments[$0] }
    }

    /// The selected environment, looked up by id on every read and write, so removing one while
    /// its editor is on screen can't reach past the end of the list.
    private var selectedBinding: Binding<EnvironmentSet>? {
        guard let id = environmentID, let current = selected else { return nil }
        return Binding(
            get: { project.environments.first { $0.id == id } ?? current },
            set: { new in
                if let index = project.environments.firstIndex(where: { $0.id == id }) { project.environments[index] = new }
            }
        )
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            if !project.environments.isEmpty {
                HStack(spacing: 2) {
                    ForEach(project.environments) { environment in
                        let active = environment.id == environmentID
                        Button {
                            environmentID = environment.id
                        } label: {
                            Text(environment.name.isEmpty ? localized("Sem nome") : environment.name)
                                .font(.system(size: 12, weight: active ? .semibold : .medium, design: .monospaced))
                                .foregroundStyle(active ? Theme.ink : Theme.paper.opacity(0.75))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5)
                                .background(active ? Theme.accent : .clear, in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(active ? .isSelected : [])
                    }
                }
                .padding(3)
                .background(Theme.paper.opacity(0.07), in: Capsule())
            }
            Menu {
                Button(localized("Novo ambiente")) { addEnvironment() }
                if let selected {
                    Button(localized("Renomear \(selected.name)…")) {
                        newName = selected.name
                        renaming = true
                    }
                    Button(localized("Duplicar \(selected.name)")) { duplicate(selected) }
                    Divider()
                    Button(localized("Apagar \(selected.name)…"), role: .destructive) { confirmingDelete = true }
                }
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
            .help(localized("Ambientes"))

            Spacer()

            if let notice {
                Text(notice)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.muted)
                    .transition(.opacity)
            }

            Menu {
                Button(localized("De um arquivo .env…"), action: importFile)
                Button(localized("Colar da área de transferência"), action: importClipboard)
            } label: {
                Label(localized("Importar"), systemImage: "square.and.arrow.down")
            }
            .menuStyle(.button)
            .buttonStyle(PillButtonStyle(prominent: false))
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(selected == nil)

            Menu {
                Button(localized("Copiar como .env")) {
                    if let selected { Clipboard.copy(selected.dotEnv, secret: true) }
                    show(localized("Copiado como .env"))
                }
                Button(localized("Salvar arquivo .env…"), action: exportFile)
            } label: {
                Label(localized("Exportar"), systemImage: "square.and.arrow.up")
            }
            .menuStyle(.button)
            .buttonStyle(PillButtonStyle(prominent: false))
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(selected?.variables.isEmpty ?? true)
        }
    }

    private func addEnvironment() {
        let names = ["development", "staging", "production"]
        let name = names.first { name in !project.environments.contains { $0.name == name } } ?? "environment"
        let environment = EnvironmentSet(name: name)
        project.environments.append(environment)
        environmentID = environment.id
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
        environmentID = copy.id
    }

    private func merge(_ text: String) {
        guard let index = selectedIndex else { return }
        let entries = DotEnv.parse(text)
        guard !entries.isEmpty else {
            show(localized("Nenhuma variável encontrada"))
            return
        }
        let result = project.environments[index].merge(entries)
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
        guard let selected else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = selected.name == "development" ? ".env" : ".env.\(selected.name)"
        panel.showsHiddenFiles = true
        panel.message = localized("O arquivo fica sem criptografia, como as ferramentas esperam. Não o coloque no Git.")
        if let folder = projectFolder { panel.directoryURL = folder }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try selected.dotEnv.write(to: url, atomically: true, encoding: .utf8)
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

/// The variables of one environment, editable in place.
struct EnvironmentEditor: View {
    @Binding var environment: EnvironmentSet

    var body: some View {
        if environment.variables.isEmpty {
            EmptyTab(symbol: "curlybraces", title: localized("Nenhuma variável"), text: localized("Adicione uma a uma ou importe um arquivo .env."))
        } else {
            Card(hint: localized("Os valores secretos ficam ocultos e são copiados sem passar pelo histórico da área de transferência.")) {
                VStack(spacing: 0) {
                    ForEach($environment.variables) { $variable in
                        if variable.id != environment.variables.first?.id { RowDivider() }
                        VariableRow(variable: $variable) {
                            environment.variables.removeAll { $0.id == variable.id }
                        }
                    }
                }
            }
        }
        Button {
            environment.variables.append(Variable())
        } label: {
            Label(localized("Adicionar variável"), systemImage: "plus")
        }
        .buttonStyle(PillButtonStyle(prominent: environment.variables.isEmpty))
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
