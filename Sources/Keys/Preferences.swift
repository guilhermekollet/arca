import AppKit

/// The app's settings, in UserDefaults. None of them is secret.
enum Preferences {
    static let unlockMinutesKey = "unlockMinutes"
    static let lockMinutesKey = "lockAfterMinutes"
    static let lockOnSleepKey = "lockOnSleep"
    static let clipboardSecondsKey = "clipboardSeconds"
    /// When the last backup was exported, to remind the person how old it is.
    static let lastBackupKey = "lastBackupAt"
    static let appearanceKey = "appearance"

    /// Light or dark, or whichever the Mac is in.
    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: Self { self }

        var title: String {
            switch self {
            case .system: localized("Igual ao sistema")
            case .light: localized("Claro")
            case .dark: localized("Escuro")
            }
        }
    }

    static let unlockMinuteChoices = [15, 60, 120, 240, 480]
    static let lockMinuteChoices = [0, 5, 15, 30, 60]
    static let clipboardSecondChoices = [15, 30, 60, 120, 0]

    static func register() {
        UserDefaults.standard.register(defaults: [
            unlockMinutesKey: 120,
            lockMinutesKey: 0,
            lockOnSleepKey: true,
            clipboardSecondsKey: 30,
            appearanceKey: Appearance.system.rawValue,
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

    static var appearance: Appearance {
        Appearance(rawValue: UserDefaults.standard.string(forKey: appearanceKey) ?? "") ?? .system
    }

    /// Puts every window, the menu bar panel and Settings in the chosen appearance. With the
    /// system's, they follow the Mac as it switches between light and dark.
    @MainActor
    static func applyAppearance() {
        NSApp.appearance = switch appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    /// "15 min", "2 h": a duration of `minutes`, as the settings and the Touch ID prompt say it.
    static func duration(_ minutes: Int) -> String {
        minutes < 60 || minutes % 60 != 0 ? localized("\(minutes) min") : localized("\(minutes / 60) h")
    }
}
