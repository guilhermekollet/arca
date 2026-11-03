import Foundation

// The names and symbols the interface shows for the model's choices.

extension Project {
    /// Symbols to pick from for a project.
    static let symbols = [
        "shippingbox", "globe", "server.rack", "iphone", "desktopcomputer", "cart", "creditcard",
        "chart.bar", "bubble.left.and.bubble.right", "envelope", "bolt", "cpu", "cloud", "lock.shield",
        "person.2", "building.2", "book", "graduationcap", "gamecontroller", "wand.and.stars",
    ]
}

extension Credential.Kind {
    var label: String {
        switch self {
        case .website: localized("Site ou painel")
        case .database: localized("Banco de dados")
        case .server: localized("Servidor")
        case .apiKey: localized("Chave de API")
        case .email: localized("E-mail")
        case .other: localized("Outro")
        }
    }

    var symbol: String {
        switch self {
        case .website: "globe"
        case .database: "cylinder.split.1x2"
        case .server: "server.rack"
        case .apiKey: "key"
        case .email: "envelope"
        case .other: "lock"
        }
    }
}
