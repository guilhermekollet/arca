import Foundation

/// Reads and writes `.env` files the way the common loaders (dotenv for Node, python-dotenv,
/// Docker Compose) understand them.
enum DotEnv {
    struct Entry: Equatable {
        var key: String
        var value: String
    }

    /// The entries in `text`, in order, repeats included. Lines that aren't `KEY=value` are skipped.
    ///
    /// - `export KEY=value` is accepted.
    /// - Unquoted values end at a ` #` comment and are trimmed.
    /// - 'Single' and `backtick` quotes are literal; "double" quotes understand \n, \r, \t, \" and \\.
    ///   Any quoted value may span several lines, as private keys often do.
    static func parse(_ text: String) -> [Entry] {
        let characters = Array(text.replacingOccurrences(of: "\r\n", with: "\n"))
        var entries: [Entry] = []
        var index = 0

        func restOfLine() -> String {
            var line = ""
            while index < characters.count, characters[index] != "\n" {
                line.append(characters[index])
                index += 1
            }
            return line
        }

        while index < characters.count {
            // The key, up to the first "=" on the line.
            var head = ""
            while index < characters.count, characters[index] != "=", characters[index] != "\n" {
                head.append(characters[index])
                index += 1
            }
            guard index < characters.count, characters[index] == "=" else {
                index += 1
                continue
            }
            index += 1
            var key = head.trimmingCharacters(in: .whitespaces)
            if key.hasPrefix("export ") {
                key = String(key.dropFirst("export ".count)).trimmingCharacters(in: .whitespaces)
            }
            guard isValidKey(key) else {
                _ = restOfLine()
                continue
            }

            while index < characters.count, characters[index] == " " || characters[index] == "\t" {
                index += 1
            }
            var value = ""
            let start = index
            if index < characters.count, let quote = ["\"", "'", "`"].first(where: { $0 == characters[index] }) {
                index += 1
                var closed = false
                while index < characters.count {
                    let character = characters[index]
                    if character == quote {
                        closed = true
                        index += 1
                        break
                    }
                    if quote == "\"", character == "\\", index + 1 < characters.count {
                        let next = characters[index + 1]
                        switch next {
                        case "n": value.append("\n")
                        case "r": value.append("\r")
                        case "t": value.append("\t")
                        case "\"", "\\": value.append(next)
                        default: value.append(character); value.append(next)
                        }
                        index += 2
                        continue
                    }
                    value.append(character)
                    index += 1
                }
                if closed {
                    // Whatever follows the closing quote (usually a comment) is ignored.
                    _ = restOfLine()
                } else {
                    // A quote that never closes is just part of a plain value.
                    index = start
                    value = restOfLine().trimmingCharacters(in: .whitespaces)
                }
            } else {
                value = restOfLine()
                if let comment = value.range(of: " #") ?? value.range(of: "\t#") {
                    value = String(value[..<comment.lowerBound])
                }
                value = value.trimmingCharacters(in: .whitespaces)
            }
            entries.append(Entry(key: key, value: value))
        }
        return entries
    }

    /// `entries` as a `.env` file that `parse` (and the usual loaders) read back unchanged.
    static func format(_ entries: [Entry]) -> String {
        entries.map { "\($0.key)=\(quoted($0.value))" }.joined(separator: "\n") + (entries.isEmpty ? "" : "\n")
    }

    /// Plain when that is safe, in single quotes when the value has no single quote or line break
    /// (they keep `$` from being expanded by loaders that do), double quotes with escapes otherwise.
    static func quoted(_ value: String) -> String {
        let plain = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-./:@,+=%")
        if value.unicodeScalars.allSatisfy(plain.contains) { return value }
        if !value.contains("'"), !value.contains("\n"), !value.contains("\r") { return "'\(value)'" }
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        return "\"\(escaped)\""
    }

    static func isValidKey(_ key: String) -> Bool {
        guard let first = key.unicodeScalars.first, first == "_" || CharacterSet.letters.contains(first), first.isASCII else { return false }
        return key.unicodeScalars.allSatisfy { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || "_.-".unicodeScalars.contains($0)) }
    }

    /// Writes `text` to `url` readable only by the user from the first byte: the file is created
    /// with mode 600 rather than made private after it is written, so its plaintext is never
    /// readable by others, not even for a moment. An existing file is made private before it is
    /// emptied, and a symbolic link in its place is refused rather than followed.
    static func write(_ text: String, to url: URL) throws {
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        guard fchmod(descriptor, 0o600) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        try handle.write(contentsOf: Data(text.utf8))
        try handle.close()
    }
}
