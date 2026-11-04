import SwiftUI

/// The project's accesses in its list: logins, databases, servers and API keys, those matching
/// `query` while there's a search. Opening and deleting are the project's (see ProjectView).
struct CredentialsSection: View {
    let credentials: [Credential]
    /// The access open in the side panel, highlighted in the list.
    let selected: Credential.ID?
    let open: (Credential.ID) -> Void
    let delete: (Credential.ID) -> Void

    var body: some View {
        Card {
            VStack(spacing: 0) {
                ForEach(credentials) { credential in
                    if credential.id != credentials.first?.id { RowDivider() }
                    CredentialRow(credential: credential, selected: credential.id == selected) { open(credential.id) }
                        .contextMenu {
                            Button(localized("Abrir")) { open(credential.id) }
                            Button(localized("Apagar acesso…"), role: .destructive) { delete(credential.id) }
                        }
                }
            }
        }
    }
}

struct CredentialRow: View {
    let credential: Credential
    var selected = false
    let open: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            CredentialIcon(symbol: credential.displaySymbol, size: 28)
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
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(
            Theme.paper.opacity(selected ? 0.08 : hovering ? 0.04 : 0),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        // Back out to the card's edge, so the highlight doesn't shift the row.
        .padding(.horizontal, -8)
        .contentShape(Rectangle())
        // A click anywhere but on the buttons opens the access: theirs come first.
        .onTapGesture(perform: open)
        .onHover { hovering = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(.default, open)
    }
}

/// An access's icon on its tinted tile.
struct CredentialIcon: View {
    let symbol: String
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .medium))
            .foregroundStyle(Theme.accent)
            .frame(width: size, height: size)
            .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

/// One access in the panel floating on the project's right; the changes apply as they are typed.
struct CredentialEditor: View {
    @Binding var credential: Credential
    let close: () -> Void
    let delete: () -> Void
    @State private var revealed = false
    @State private var generator = PasswordGenerator()
    @State private var showsGenerator = false
    @State private var choosingSymbol = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding([.horizontal, .top], 18)
                .padding(.bottom, 14)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    field(localized("Tipo")) {
                        Picker(localized("Tipo"), selection: $credential.kind) {
                            ForEach(Credential.Kind.allCases) { kind in
                                Label(kind.label, systemImage: kind.symbol).tag(kind)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    field(localized("Nome")) {
                        TextField(localized("Painel da Vercel, banco de produção…"), text: $credential.title)
                            .textFieldStyle(.field)
                    }
                    field(localized("Endereço")) {
                        HStack(spacing: 6) {
                            TextField("https://", text: $credential.url)
                                .textFieldStyle(.code)
                            if let url = URL(string: credential.url), let scheme = url.scheme, ["http", "https"].contains(scheme) {
                                IconButton(symbol: "arrow.up.right", help: localized("Abrir \(url.host() ?? credential.url)")) {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
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
                            .textFieldStyle(.code(trailingRoom: 18))
                            // Inside the field, at its right end, as in macOS's own password fields.
                            .overlay(alignment: .trailing) {
                                IconButton(symbol: revealed ? "eye.slash" : "eye", help: revealed ? localized("Ocultar") : localized("Mostrar")) {
                                    revealed.toggle()
                                }
                                .padding(.trailing, 2)
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
                    field(localized("Notas")) {
                        TextEditor(text: $credential.notes)
                            .font(.system(size: 12.5))
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .frame(minHeight: 110)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.hairline))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
            .scrollBounceBehavior(.basedOnSize)

            HStack {
                IconButton(symbol: "trash", help: localized("Apagar acesso…"), color: .red.opacity(0.85), action: delete)
                Spacer()
                Button(localized("Pronto"), action: close)
                    .buttonStyle(PillButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
        }
        .foregroundStyle(Theme.paper)
        .tint(Theme.accent)
        .onChange(of: credential.password) { credential.updatedAt = Date() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                choosingSymbol.toggle()
            } label: {
                CredentialIcon(symbol: credential.displaySymbol, size: 40)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "pencil")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 15, height: 15)
                            .background(Theme.accent, in: Circle())
                            .offset(x: 4, y: 4)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(localized("Trocar o ícone"))
            .accessibilityLabel(localized("Trocar o ícone"))
            .popover(isPresented: $choosingSymbol, arrowEdge: .bottom) {
                CredentialSymbolPicker(symbol: $credential.symbol, automatic: credential.kind.symbol)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(credential.displayTitle.isEmpty ? localized("Novo acesso") : credential.displayTitle)
                    .font(Theme.display(19))
                    .lineLimit(1)
                Text(credential.kind.label)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            IconButton(symbol: "xmark", help: localized("Fechar"), action: close)
                .keyboardShortcut(.cancelAction)
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.muted)
            content()
        }
    }
}

/// The icon grid for an access. The first choice follows the access's kind.
struct CredentialSymbolPicker: View {
    @Binding var symbol: String?
    /// The kind's icon, shown while none is picked.
    let automatic: String
    @Environment(\.dismiss) private var dismiss
    private let columns = Array(repeating: GridItem(.fixed(32), spacing: 6), count: 9)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localized("Ícone"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Button(localized("Usar o do tipo")) {
                    symbol = nil
                    dismiss()
                }
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(symbol == nil ? Theme.muted : Theme.accent)
                    .disabled(symbol == nil)
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Credential.symbols, id: \.self) { option in
                    let selected = option == (symbol ?? automatic)
                    Button {
                        symbol = option == automatic ? nil : option
                        dismiss()
                    } label: {
                        Image(systemName: option)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(selected ? Theme.accent : Theme.paper.opacity(0.75))
                            .frame(width: 32, height: 32)
                            .background(selected ? Theme.accent.opacity(0.18) : Theme.paper.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.accent.opacity(selected ? 0.6 : 0), lineWidth: 1))
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .padding(16)
        .frame(width: 9 * 32 + 8 * 6 + 32)
        .keysSurface()
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
