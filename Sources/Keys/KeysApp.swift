import SwiftUI

@main
struct KeysApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var vault = Vault.shared

    init() {
        Preferences.register()
    }

    var body: some Scene {
        Window(appName, id: mainWindowID) {
            RootView()
                .environmentObject(vault)
                .frame(minWidth: 860, minHeight: 540)
        }
        .defaultSize(width: 1080, height: 680)
        .commands { KeysCommands(vault: vault) }

        // A window rather than a Settings scene, as in Mara: it opens the same way from the menu
        // bar panel and from ⌘, (see KeysCommands).
        Window(localized("Ajustes do Chaves"), id: settingsWindowID) {
            SettingsView().environmentObject(vault)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarPanel().environmentObject(vault)
        } label: {
            Image(nsImage: Theme.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }
}

let mainWindowID = "main"

/// The menu bar's commands, where a Mac app keeps them: Settings under the app menu with ⌘,,
/// a new project in File with ⌘N, and locking the vault with ⇧⌘L.
struct KeysCommands: Commands {
    @ObservedObject var vault: Vault
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(localized("Ajustes…")) { present(settingsWindowID, using: openWindow) }
                .keyboardShortcut(",")
        }
        CommandGroup(replacing: .newItem) {
            Button(localized("Novo projeto")) { vault.addProject() }
                .keyboardShortcut("n")
                .disabled(vault.state != .unlocked)
        }
        CommandGroup(after: .newItem) {
            Button(localized("Trancar o cofre")) { vault.lock() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(vault.state != .unlocked || vault.isSample)
        }
    }
}

/// Keeps the app in the menu bar after its window closes, and saves before quitting.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.applyAppearance()
        // Development tool: `Keys --snapshot folder` draws every screen with the sample vault and
        // quits, so the interface can be checked without Touch ID or a real vault.
        if let flag = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.count > flag + 1 {
            let folder = URL(fileURLWithPath: CommandLine.arguments[flag + 1])
            Task { await Snapshot.run(into: folder) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        Vault.shared.lock()
    }
}

/// Opens one of the app's windows in front of everything, on the screen the pointer is on.
/// SwiftUI puts a window back where it was last closed, which can be another monitor the person
/// isn't looking at, and activating the app alone doesn't raise it on recent macOS versions.
@MainActor
func present(_ id: String, using openWindow: OpenWindowAction) {
    openWindow(id: id)
    NSApp.activate()
    // SwiftUI creates the window in this pass of the run loop; it exists by the next one.
    DispatchQueue.main.async {
        guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == id }) else { return }
        let pointer = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) }),
           window.screen?.frame != screen.frame {
            // Moves without resizing: resizing windows during layout has crashed AppKit on macOS 26.
            let area = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: area.midX - window.frame.width / 2, y: area.midY - window.frame.height / 2))
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}
