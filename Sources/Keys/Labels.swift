import Foundation

// The names and symbols the interface shows for the model's choices.

extension Project {
    /// Symbols to pick from for a project, nine to a row by theme: technology, commerce and
    /// business, communication, tools, creative work, learning and play, life, and the rest.
    static let symbols = [
        "shippingbox", "globe", "server.rack", "desktopcomputer", "laptopcomputer", "iphone", "ipad", "applewatch", "cpu",
        "memorychip", "cloud", "externaldrive", "cylinder.split.1x2", "network", "terminal", "chevron.left.forwardslash.chevron.right", "ladybug", "app.badge",
        "cart", "bag", "basket", "storefront", "creditcard", "banknote", "dollarsign.circle", "chart.bar", "chart.pie",
        "chart.line.uptrend.xyaxis", "briefcase", "building.2", "building.columns", "house", "person.2", "person.3", "megaphone", "newspaper",
        "bubble.left.and.bubble.right", "text.bubble", "envelope", "phone", "bell", "calendar", "link", "qrcode", "antenna.radiowaves.left.and.right",
        "lock.shield", "key", "shield", "gearshape", "wrench.and.screwdriver", "hammer", "puzzlepiece", "target", "lightbulb",
        "paintbrush", "paintpalette", "camera", "photo", "film", "play.rectangle", "music.note", "mic", "headphones",
        "book", "graduationcap", "gamecontroller", "wand.and.stars", "sparkles", "brain", "flask", "atom", "cube",
        "leaf", "tree", "heart", "cross.case", "fork.knife", "cup.and.saucer", "airplane", "car", "truck.box",
        "ticket", "gift", "trophy", "flag", "star", "flame", "crown", "pawprint", "dumbbell",
    ]
}

extension Project.Tint {
    var label: String {
        switch self {
        case .lavender: localized("Lavanda")
        case .sky: localized("Céu")
        case .mint: localized("Menta")
        case .lime: localized("Lima")
        case .amber: localized("Âmbar")
        case .coral: localized("Coral")
        case .rose: localized("Rosa")
        case .slate: localized("Ardósia")
        }
    }
}

extension Credential {
    /// Icons to pick from for an access, nine to a row: keys and locks, places it opens,
    /// services and the rest.
    static let symbols = [
        "key", "key.horizontal", "lock", "lock.shield", "shield", "person.badge.key", "person.crop.circle", "touchid", "faceid",
        "globe", "server.rack", "cylinder.split.1x2", "terminal", "cloud", "network", "externaldrive", "cpu", "desktopcomputer",
        "envelope", "phone", "bubble.left", "creditcard", "banknote", "building.columns", "cart", "bag", "storefront",
        "chart.bar", "megaphone", "camera", "play.rectangle", "music.note", "gamecontroller", "wifi", "gearshape", "star",
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
