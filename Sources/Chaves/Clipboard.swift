import AppKit

/// Copies values to the clipboard and, for secrets, clears them again after a while.
@MainActor
enum Clipboard {
    /// Marks the copy as concealed and transient, so clipboard managers and Universal Clipboard
    /// leave it out (see nspasteboard.org).
    private static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    private static var clearing: Task<Void, Never>?

    static func copy(_ text: String, secret: Bool) {
        let board = NSPasteboard.general
        board.clearContents()
        board.declareTypes(secret ? [.string, concealed, transient] : [.string], owner: nil)
        board.setString(text, forType: .string)
        if secret {
            board.setString("", forType: concealed)
            board.setString("", forType: transient)
        }
        clearing?.cancel()
        let seconds = Preferences.clipboardSeconds
        guard secret, seconds > 0 else { return }
        let copied = board.changeCount
        clearing = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            // Something else copied in the meantime: leave it alone.
            if board.changeCount == copied { board.clearContents() }
        }
    }
}
