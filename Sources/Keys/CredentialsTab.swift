import SwiftUI

/// The project's accesses in its list: logins, databases, servers and API keys, those matching
/// `query` while there's a search. Editing and deleting are the list's (see ProjectItemsView).
struct CredentialsSection: View {
    let credentials: [Credential]
    let edit: (Credential.ID) -> Void
    let delete: (Credential.ID) -> Void

    var body: some View {
        Card {
            VStack(spacing: 0) {
                ForEach(credentials) { credential in
                    if credential.id != credentials.first?.id { RowDivider() }
                    CredentialRow(credential: credential) { edit(credential.id) }
                        .contextMenu {
                            Button(localized("Editar…")) { edit(credential.id) }
                            Button(localized("Apagar acesso…"), role: .destructive) { delete(credential.id) }
                        }
                }
            }
        }
    }
}

struct CredentialRow: View {
    let credential: Credential
    let edit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: credential.kind.symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 28, height: 28)
                .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(credential.displayTitle.isEmpty ? localized("Sem nome") : credential.displayTitle)
                    .font(.system(size: 13, weight: .medium))
                Text(credential.username.isEmpty ? credential.kind.label : credential.username)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if !credential.username.isEmpty {
                CopyButton(value: credential.username, symbol: "person", help: localized("Copiar o usuário"))
            }
            CopyButton(value: credential.password, secret: true, symbol: "key", help: localized("Copiar a senha"))
            if let url = URL(string: credential.url), let scheme = url.scheme, ["http", "https"].contains(scheme) {
                IconButton(symbol: "arrow.up.right", help: localized("Abrir \(url.host() ?? credential.url)")) {
                    NSWorkspace.shared.open(url)
                }
            }
            IconButton(symbol: "pencil", help: localized("Editar"), action: edit)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: edit)
    }
}

/// Edits one access in a sheet; the changes apply as they are typed.
struct CredentialEditor: View {
    @Binding var credential: Credential
    let delete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var revealed = false
    @State private var generator = PasswordGenerator()
    @State private var showsGenerator = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: credential.kind.symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 34, height: 34)
                    .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(credential.displayTitle.isEmpty ? localized("Novo acesso") : credential.displayTitle)
                    .font(Theme.display(22))
                    .lineLimit(1)
                Spacer()
                Picker(localized("Tipo"), selection: $credential.kind) {
                    ForEach(Credential.Kind.allCases) { kind in
                        Label(kind.label, systemImage: kind.symbol).tag(kind)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    field(localized("Nome")) {
                        TextField(localized("Painel da Vercel, banco de produção…"), text: $credential.title)
                            .textFieldStyle(.field)
                    }
                    field(localized("Endereço")) {
                        TextField("https://", text: $credential.url)
                            .textFieldStyle(.code)
                    }
                    field(localized("Usuário")) {
                        HStack(spacing: 6) {
                            TextField(localized("Usuário"), text: $credential.username)
                                .textFieldStyle(.code)
                            CopyButton(value: credential.username, symbol: "person", help: localized("Copiar o usuário"))
                        }
                    }
                    field(localized("Senha")) {
                        HStack(spacing: 6) {
                            Group {
                                if revealed {
                                    TextField(localized("Senha"), text: $credential.password)
                                } else {
                                    SecureField(localized("Senha"), text: $credential.password)
                                }
                            }
                            .textFieldStyle(.code)
                            IconButton(symbol: revealed ? "eye.slash" : "eye", help: revealed ? localized("Ocultar") : localized("Mostrar")) {
                                revealed.toggle()
                            }
                            CopyButton(value: credential.password, secret: true, symbol: "key", help: localized("Copiar a senha"))
                            IconButton(symbol: "wand.and.stars", help: localized("Gerar senha"), color: Theme.accent) {
                                showsGenerator.toggle()
                            }
                            .popover(isPresented: $showsGenerator, arrowEdge: .bottom) {
                                GeneratorPopover(generator: $generator) { password in
                                    credential.password = password
                                    revealed = true
                                    showsGenerator = false
                                }
                            }
                        }
                    }
                }
            }

            Card(localized("Notas")) {
                TextEditor(text: $credential.notes)
                    .font(.system(size: 12.5))
                    .scrollContentBackground(.hidden)
                    .frame(height: 80)
            }

            HStack {
                Button(localized("Apagar acesso…"), action: delete)
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.red.opacity(0.85))
                Spacer()
                Button(localized("Pronto")) { dismiss() }
                    .buttonStyle(PillButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 520)
        .keysSurface()
        .onChange(of: credential.password) { credential.updatedAt = Date() }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .frame(width: 70, alignment: .trailing)
            content()
        }
    }
}

struct GeneratorPopover: View {
    @Binding var generator: PasswordGenerator
    let use: (String) -> Void
    @State private var preview = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(preview)
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(3)
                .frame(width: 300, alignment: .leading)
                .padding(10)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            HStack(spacing: 10) {
                Text(localized("\(generator.length) caracteres"))
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .frame(width: 92, alignment: .leading)
                Slider(
                    value: Binding(get: { Double(generator.length) }, set: { generator.length = Int($0) }),
                    in: Double(PasswordGenerator.lengths.lowerBound)...Double(PasswordGenerator.lengths.upperBound),
                    step: 1
                )
            }
            HStack(spacing: 14) {
                Toggle("A–Z", isOn: $generator.uppercase)
                Toggle("a–z", isOn: $generator.lowercase)
                Toggle("0–9", isOn: $generator.digits)
                Toggle("!#%", isOn: $generator.symbols)
            }
            .toggleStyle(.checkbox)
            .font(.system(size: 12))
            HStack {
                Button(localized("Outra")) { preview = generator.generate() }
                    .buttonStyle(PillButtonStyle(prominent: false))
                Spacer()
                Button(localized("Usar esta senha")) { use(preview) }
                    .buttonStyle(PillButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .keysSurface()
        .onAppear { preview = generator.generate() }
        .onChange(of: generator) { preview = generator.generate() }
    }
}
