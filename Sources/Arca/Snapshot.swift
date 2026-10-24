import AppKit
import SwiftUI

/// Development tool behind `Arca --snapshot folder`: draws every screen with the sample vault into
/// PNG files and quits, so the interface can be checked (and shown in a pull request) without
/// Touch ID, a real vault or permission to record the screen.
@MainActor
enum Snapshot {
    static func run(into folder: URL) async {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let vault = Vault.shared
        // The main window SwiftUI opened on launch, drawn with its toolbar, once per tab.
        try? await Task.sleep(for: .seconds(1.5))
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == mainWindowID }) {
            window.setContentSize(NSSize(width: 1080, height: 680))
            for section in ProjectSection.allCases {
                vault.section = section
                try? await Task.sleep(for: .milliseconds(600))
                write(window, to: folder.appendingPathComponent("main-\(section.rawValue).png"))
            }
            vault.section = .context
        }

        await draw(RootView().environmentObject(Vault(previewing: .new)), size: CGSize(width: 860, height: 620), to: folder, name: "lock-new")
        await draw(RootView().environmentObject(Vault(previewing: .locked)), size: CGSize(width: 860, height: 620), to: folder, name: "lock-locked")
        await draw(
            RootView().environmentObject(Vault(previewing: .unreadable(VaultError.otherDeviceKey.localizedDescription))),
            size: CGSize(width: 860, height: 620), to: folder, name: "lock-unreadable"
        )
        await draw(SettingsView().environmentObject(vault), size: nil, to: folder, name: "settings")
        await draw(MenuBarPanel().environmentObject(vault), size: nil, to: folder, name: "panel")
        await draw(MenuBarPanel(query: "aurora prod").environmentObject(vault), size: nil, to: folder, name: "panel-search")
        if let credential = vault.projects.first?.credentials.last {
            await draw(CredentialEditor(credential: .constant(credential)) {}, size: nil, to: folder, name: "credential-editor")
        }
        await draw(GeneratorPopover(generator: .constant(PasswordGenerator())) { _ in }, size: nil, to: folder, name: "generator")
        print("Snapshots in \(folder.path)")
        NSApp.terminate(nil)
    }

    /// Hosts `view` in a window off screen, lets it lay out, and writes what it drew.
    private static func draw<Content: View>(_ view: Content, size: CGSize?, to folder: URL, name: String) async {
        let host = NSHostingView(rootView: view)
        // A fixed size stays fixed: by default the hosting view resizes its window to fit.
        if size != nil { host.sizingOptions = [] }
        let fitting = size ?? host.fittingSize
        let window = NSWindow(
            contentRect: NSRect(origin: NSPoint(x: -20_000, y: -20_000), size: fitting),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        window.setContentSize(fitting)
        window.orderFrontRegardless()
        try? await Task.sleep(for: .milliseconds(800))
        write(window, to: folder.appendingPathComponent("\(name).png"))
        window.orderOut(nil)
    }

    /// The window's whole frame (title bar and toolbar included) as a PNG.
    private static func write(_ window: NSWindow, to url: URL) {
        guard let view = window.contentView?.superview ?? window.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try? bitmap.representation(using: .png, properties: [:])?.write(to: url)
    }
}
