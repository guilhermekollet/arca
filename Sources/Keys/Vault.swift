import AppKit
import CryptoKit
import SwiftUI

/// The vault while the app runs: locked, or open with its projects in memory. Every change is
/// sealed and written back to disk shortly after it is made.
@MainActor
final class Vault: ObservableObject {
    static let shared = Vault()

    enum State: Equatable {
        /// There is no vault on this Mac yet.
        case new
        case locked
        case unlocked
        /// There is a vault, but it can't be opened here; the text says why.
        case unreadable(String)
    }

    @Published private(set) var state: State
    @Published var projects: [Project] = [] {
        didSet {
            if state == .unlocked, projects != oldValue { scheduleSave() }
        }
    }
    /// The project open in the main window, and the part of it on screen; the menu bar panel
    /// sets them too, to open an access or a variable where it is.
    @Published var selection: Project.ID?
    @Published var section = ProjectSection.context
    @Published private(set) var isUnlocking = false
    /// When Touch ID last opened the vault; it locks again `Preferences.unlockMinutes` later.
    @Published private(set) var unlockedAt: Date?
    /// The last thing that went wrong, shown until the next attempt.
    @Published var problem: String?
    /// The lock screen asks for Touch ID by itself once per launch; after a lock it waits for a click.
    var askedOnLaunch = false
    /// `--sample` (and `--snapshot`) open a made-up vault in memory, for screenshots and UI work.
    /// Nothing is saved and it never locks.
    let isSample: Bool

    private var key: SymmetricKey?
    private var file: VaultFile?
    private var pendingSave: Task<Void, Never>?
    private var backedUp = false
    private let autoLock = AutoLock()

    /// `KEYS_VAULT_DIR` points the app at another folder, to try things without touching your vault.
    static var directory: URL {
        if let custom = ProcessInfo.processInfo.environment["KEYS_VAULT_DIR"], !custom.isEmpty {
            return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Keys")
    }

    static var fileURL: URL { directory.appendingPathComponent("vault.keys") }
    static var backupsURL: URL { directory.appendingPathComponent("Backups") }
    /// How many earlier copies of the vault are kept.
    static let backupCount = 20

    init(sample: Bool = CommandLine.arguments.contains("--sample") || CommandLine.arguments.contains("--snapshot")) {
        isSample = sample
        if sample {
            state = .unlocked
            unlockedAt = Date()
            projects = SampleVault.projects
            selection = projects.first { !$0.credentials.isEmpty && $0.parentID != nil }?.id
        } else {
            state = FileManager.default.fileExists(atPath: Self.fileURL.path) ? .locked : .new
        }
    }

    /// A vault in memory that only shows `state`, for drawing the lock screen (see Snapshot).
    init(previewing state: State) {
        isSample = true
        askedOnLaunch = true
        self.state = state
    }

    // MARK: Locking

    /// Creates the device key and an empty vault for it.
    func create() {
        guard !isSample else { return }
        problem = nil
        do {
            let deviceKey = try DeviceKey.create()
            let (file, key) = try VaultFile.create(Self.encode(VaultContents()), for: deviceKey)
            try file.write(to: Self.fileURL)
            self.file = file
            self.key = key
            backedUp = true
            unlockedAt = Date()
            state = .unlocked
            projects = []
            startAutoLock()
        } catch {
            problem = error.localizedDescription
        }
    }

    func unlock() async {
        guard state == .locked, !isUnlocking, !isSample else { return }
        isUnlocking = true
        defer { isUnlocking = false }
        problem = nil
        do {
            let file = try VaultFile.read(from: Self.fileURL)
            // Checked before asking for Touch ID: a vault for another key can't open whatever the person does.
            guard let publicKey = DeviceKey.publicKey() else { throw VaultError.missingDeviceKey }
            guard publicKey == file.recipient else { throw VaultError.otherDeviceKey }
            let deviceKey = try await DeviceKey.unlock(reason: localized("destrancar o cofre"))
            let key = try file.unwrapKey(with: deviceKey)
            let contents = try Self.decode(file.open(with: key))
            self.file = file
            self.key = key
            backedUp = false
            unlockedAt = Date()
            state = .unlocked
            projects = contents.projects
            if let selection, !projects.contains(where: { $0.id == selection }) { self.selection = nil }
            startAutoLock()
        } catch let error as VaultError where error != .newerVersion {
            state = .unreadable(error.localizedDescription)
        } catch where DeviceKey.isCancellation(error) {
            // Dismissing the prompt is not a problem worth reporting.
        } catch {
            problem = error.localizedDescription
        }
    }

    /// Saves, forgets the key and the contents, and locks.
    func lock() {
        guard state == .unlocked, !isSample else { return }
        saveNow()
        autoLock.stop()
        key = nil
        file = nil
        unlockedAt = nil
        // Locked first, so clearing the projects isn't saved.
        state = .locked
        projects = []
    }

    /// Moves an unreadable vault aside (it is kept, renamed, next to where it was) so a new one
    /// can be created.
    func setAsideUnreadable() {
        let stamp = Self.stamp(Date())
        let destination = Self.directory.appendingPathComponent("vault-unreadable-\(stamp).keys")
        do {
            try FileManager.default.moveItem(at: Self.fileURL, to: destination)
            state = .new
            problem = nil
        } catch {
            problem = error.localizedDescription
        }
    }

    /// When the vault will lock by itself, read with the current setting so a change applies at once.
    var locksAt: Date? {
        unlockedAt.map { $0.addingTimeInterval(TimeInterval(Preferences.unlockMinutes * 60)) }
    }

    private func startAutoLock() {
        guard !isSample else { return }
        autoLock.start(locksAt: { [weak self] in self?.locksAt }) { [weak self] in self?.lock() }
    }

    // MARK: Saving

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        guard state == .unlocked, !isSample, let key, let file else { return }
        do {
            backUpOnce()
            let updated = try file.resealing(Self.encode(VaultContents(projects: projects)), with: key)
            try updated.write(to: Self.fileURL)
            self.file = updated
        } catch {
            problem = localized("Não foi possível salvar o cofre: \(error.localizedDescription)")
        }
    }

    /// Before the first save after unlocking, the vault as it was is copied to Backups, so a
    /// project deleted by mistake can still be recovered. The copies are encrypted like the vault.
    private func backUpOnce() {
        guard !backedUp else { return }
        backedUp = true
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: Self.backupsURL, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let copy = Self.backupsURL.appendingPathComponent("vault-\(Self.stamp(Date())).keys")
            if !manager.fileExists(atPath: copy.path) {
                try manager.copyItem(at: Self.fileURL, to: copy)
            }
            let copies = try manager.contentsOfDirectory(at: Self.backupsURL, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "keys" }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
            for old in copies.dropFirst(Self.backupCount) {
                try? manager.removeItem(at: old)
            }
        } catch {
            // A missing backup must not stop the save itself.
        }
    }

    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    nonisolated static func encode(_ contents: VaultContents) throws -> Data {
        // Dates stay in the default numeric form: exact to the fraction of a second, and nobody
        // reads this JSON without decrypting it first.
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(contents)
    }

    nonisolated static func decode(_ data: Data) throws -> VaultContents {
        do {
            return try JSONDecoder().decode(VaultContents.self, from: data)
        } catch {
            throw VaultError.damaged
        }
    }

    // MARK: Projects

    /// A new project, at the top level or inside `parent`, opened on its context.
    @discardableResult
    func addProject(inside parent: Project.ID? = nil) -> Project.ID {
        var project = Project(name: parent == nil ? localized("Novo projeto") : localized("Novo subprojeto"))
        project.parentID = parent
        projects.append(project)
        selection = project.id
        section = .context
        return project.id
    }

    /// Deletes the project; its subprojects move up one level instead of going with it.
    func deleteProject(_ id: Project.ID) {
        projects = ProjectTree.removing(id, from: projects)
        if selection == id { selection = nil }
    }

    func project(_ id: Project.ID?) -> Project? {
        projects.first { $0.id == id }
    }

    /// A binding to the project with `id` that also stamps when it was last changed.
    func binding(for id: Project.ID) -> Binding<Project>? {
        guard let current = project(id) else { return nil }
        return Binding(
            get: { [weak self] in self?.project(id) ?? current },
            set: { [weak self] new in
                guard let self, let index = projects.firstIndex(where: { $0.id == id }), projects[index] != new else { return }
                var new = new
                new.updatedAt = Date()
                projects[index] = new
            }
        )
    }
}

/// Locks the vault when its unlock runs out, after a while without using the Mac (if the person
/// asked for that), and when the Mac sleeps or its screen locks.
@MainActor
final class AutoLock {
    private var timer: Timer?
    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []

    /// Whether to lock `now`: the unlock ran out at `locksAt`, or the Mac has been idle for
    /// `idleSeconds`, longer than `idleMinutes` (0 never locks for being idle).
    nonisolated static func shouldLock(now: Date, locksAt: Date?, idleSeconds: Double, idleMinutes: Int) -> Bool {
        if let locksAt, now >= locksAt { return true }
        return idleMinutes > 0 && idleSeconds >= Double(idleMinutes * 60)
    }

    func start(locksAt: @escaping @MainActor @Sendable () -> Date?, lock: @escaping @MainActor @Sendable () -> Void) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
            Task { @MainActor in
                // Seconds since the last keyboard, mouse or trackpad event anywhere on the Mac.
                let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
                if Self.shouldLock(now: Date(), locksAt: locksAt(), idleSeconds: idle, idleMinutes: Preferences.lockMinutes) { lock() }
            }
        }
        let onSleep: @Sendable (Notification) -> Void = { _ in
            Task { @MainActor in
                if Preferences.lockOnSleep { lock() }
            }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append((workspace, workspace.addObserver(forName: name, object: nil, queue: .main, using: onSleep)))
        }
        let distributed = DistributedNotificationCenter.default()
        observers.append((distributed, distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main, using: onSleep)))
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        for observer in observers {
            observer.center.removeObserver(observer.token)
        }
        observers = []
    }
}
