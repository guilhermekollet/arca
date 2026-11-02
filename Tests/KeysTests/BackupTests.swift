import Testing
@testable import Keys

@Suite("Backups")
struct BackupTests {
    @Test func opensWithItsPassword() {
        #expect(openBackup(sealedWith: "correct horse battery", openedWith: "correct horse battery") == "opened")
    }

    @Test func anotherPasswordDoesNotOpenIt() {
        #expect(openBackup(sealedWith: "correct horse battery", openedWith: "correct horse batterY") == "wrongPassword")
    }

    @Test(arguments: [BackupTampering.sealedByte, .fewerIterations, .otherSalt, .otherDate])
    func tamperingIsRefused(_ tampering: BackupTampering) {
        #expect(openBackup(sealedWith: "correct horse battery", openedWith: "correct horse battery", after: tampering) == "wrongPassword")
    }

    @Test func otherFilesAndNewerVersionsAreRecognized() {
        #expect(openBackup(sealedWith: "correct horse battery", openedWith: "correct horse battery", after: .otherFormat) == "notABackup")
        #expect(openBackup(sealedWith: "correct horse battery", openedWith: "correct horse battery", after: .newerVersion) == "newerVersion")
    }

    @Test func aShortPasswordIsRefused() {
        #expect(openBackup(sealedWith: "curta", openedWith: "curta") == "weakPassword")
    }

    @Test func accentsTypedEitherWayGiveTheSamePassword() {
        // "é" as one character, then as "e" and a combining accent: the same on any keyboard.
        #expect(openBackup(sealedWith: "caf\u{E9} com p\u{E3}o de queijo", openedWith: "cafe\u{301} com pa\u{303}o de queijo") == "opened")
    }

    @Test func theFileIsPrivateAndEncrypted() {
        let result = backupOnDisk()
        #expect(result.sameProjects)
        #expect(result.permissions == "600")
        #expect(!result.plaintextVisible)
    }

    @Test func mergingAddsAndKeepsTheNewestCopy() {
        let result = merge(backup: [("Loja", 50), ("API", 10), ("Novo", 5)], into: [("Loja", 20), ("API", 30), ("Site", 1)])
        #expect(result.added == 1)
        #expect(result.updated == 1)
        #expect(result.result == ["Loja@50", "API@30", "Site@1", "Novo@5"])
    }

    @Test func theSuggestedNameCarriesTheDate() {
        #expect(suggestedBackupName() == "Keys-backup-2026-11-02.keys-backup")
    }
}
