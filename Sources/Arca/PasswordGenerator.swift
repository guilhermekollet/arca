import Foundation

/// Random passwords from the system's cryptographically secure generator.
struct PasswordGenerator: Equatable {
    var length = 24
    var uppercase = true
    var lowercase = true
    var digits = true
    var symbols = true

    // Look-alike characters (0/O, 1/l/I) are left out, so a password read aloud or retyped is
    // still right. Symbols avoid quotes, backslashes and spaces, which break .env files and shells.
    static let uppercaseSet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ")
    static let lowercaseSet = Array("abcdefghijkmnopqrstuvwxyz")
    static let digitSet = Array("23456789")
    static let symbolSet = Array("!#%&()*+,-./:;<=>?@[]^_{|}~")

    static let lengths = 8...64

    private var sets: [[Character]] {
        var sets: [[Character]] = []
        if uppercase { sets.append(Self.uppercaseSet) }
        if lowercase { sets.append(Self.lowercaseSet) }
        if digits { sets.append(Self.digitSet) }
        if symbols { sets.append(Self.symbolSet) }
        return sets.isEmpty ? [Self.lowercaseSet] : sets
    }

    /// A password with at least one character of every chosen kind, at `length` characters.
    func generate<Generator: RandomNumberGenerator>(using generator: inout Generator) -> String {
        let sets = sets
        let length = max(length, sets.count)
        let all = sets.flatMap { $0 }
        var characters = sets.map { $0.randomElement(using: &generator)! }
        while characters.count < length {
            characters.append(all.randomElement(using: &generator)!)
        }
        characters.shuffle(using: &generator)
        return String(characters)
    }

    func generate() -> String {
        var generator = SystemRandomNumberGenerator()
        return generate(using: &generator)
    }
}
