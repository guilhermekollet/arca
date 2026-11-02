import Foundation

/// The app's settings, in UserDefaults. None of them is secret.
enum Preferences {
    static let unlockMinutesKey = "unlockMinutes"
    static let lockMinutesKey = "lockAfterMinutes"
    static let lockOnSleepKey = "lockOnSleep"
    static let clipboardSecondsKey = "clipboardSeconds"

    static let unlockMinuteChoices = [15, 60, 120, 240, 480]
    static let lockMinuteChoices = [0, 5, 15, 30, 60]
    static let clipboardSecondChoices = [15, 30, 60, 120, 0]

    static func register() {
        UserDefaults.standard.register(defaults: [
            unlockMinutesKey: 120,
            lockMinutesKey: 0,
            lockOnSleepKey: true,
            clipboardSecondsKey: 30,
            // Where the menu bar icon goes the first time, in points from the right edge of the
            // menu bar: close enough to the clock that a notch doesn't hide it on a full menu bar.
            // Once the person ⌘-drags the icon, macOS keeps their place instead.
            "NSStatusItem Preferred Position Item-0": 290,
        ])
    }

    /// Minutes a Touch ID unlock lasts: after that the vault locks and asks again.
    static var unlockMinutes: Int { UserDefaults.standard.integer(forKey: unlockMinutesKey) }
    /// Minutes without using the Mac before the vault locks itself sooner; 0 never does.
    static var lockMinutes: Int { UserDefaults.standard.integer(forKey: lockMinutesKey) }
    static var lockOnSleep: Bool { UserDefaults.standard.bool(forKey: lockOnSleepKey) }
    /// Seconds before a copied secret is cleared from the clipboard; 0 leaves it there.
    static var clipboardSeconds: Int { UserDefaults.standard.integer(forKey: clipboardSecondsKey) }

    /// "15 min", "2 h": a duration of `minutes`, as the settings and the Touch ID prompt say it.
    static func duration(_ minutes: Int) -> String {
        minutes < 60 || minutes % 60 != 0 ? localized("\(minutes) min") : localized("\(minutes / 60) h")
    }
}
