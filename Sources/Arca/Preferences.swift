import Foundation

/// The app's settings, in UserDefaults. None of them is secret.
enum Preferences {
    static let lockMinutesKey = "lockAfterMinutes"
    static let lockOnSleepKey = "lockOnSleep"
    static let clipboardSecondsKey = "clipboardSeconds"

    static let lockMinuteChoices = [1, 5, 15, 30, 60, 0]
    static let clipboardSecondChoices = [15, 30, 60, 120, 0]

    static func register() {
        UserDefaults.standard.register(defaults: [lockMinutesKey: 15, lockOnSleepKey: true, clipboardSecondsKey: 30])
    }

    /// Minutes without using the Mac before the vault locks itself; 0 never locks it.
    static var lockMinutes: Int { UserDefaults.standard.integer(forKey: lockMinutesKey) }
    static var lockOnSleep: Bool { UserDefaults.standard.bool(forKey: lockOnSleepKey) }
    /// Seconds before a copied secret is cleared from the clipboard; 0 leaves it there.
    static var clipboardSeconds: Int { UserDefaults.standard.integer(forKey: clipboardSecondsKey) }
}
