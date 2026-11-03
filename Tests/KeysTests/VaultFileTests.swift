import Testing
@testable import Keys

@Suite("Vault file")
struct VaultFileTests {
    @Test func opensWithItsDeviceKey() {
        #expect(openVault(after: .none) == "opened")
    }

    @Test(arguments: [Tampering.contentsByte, .wrappedKeyByte, .ephemeralFromAnotherVault, .contentsFromAnotherVault])
    func tamperingIsDetected(_ tampering: Tampering) {
        #expect(openVault(after: tampering) == "damaged")
    }

    @Test func anotherDeviceKeyIsRecognized() {
        #expect(openVault(after: .otherDeviceKey) == "otherDeviceKey")
    }

    @Test func aNewerVersionIsNotOpened() {
        #expect(openVault(after: .newerVersion) == "newerVersion")
    }

    @Test func anotherFormatIsNotOpened() {
        #expect(openVault(after: .otherFormat) == "notAVault")
        #expect(readingGarbage() == "notAVault")
    }

    @Test func savingKeepsTheWrappedKey() {
        #expect(resealingKeepsTheKey())
    }

    @Test func everySealUsesAFreshNonce() {
        #expect(sealsDiffer())
    }

    @Test func theFileIsPrivateAndEncrypted() {
        let result = vaultOnDisk()
        #expect(result.sameAfterReading)
        #expect(result.permissions == "600")
        #expect(!result.plaintextVisible)
    }
}

@Suite("Vault contents")
struct VaultContentsTests {
    @Test func theSampleRoundTrips() {
        #expect(sampleRoundTrips())
    }

    @Test func missingFieldsTakeTheirDefaults() {
        // A vault saved by an older version, before most fields existed.
        #expect(firstProjectDecoded(from: #"{"projects":[{"name":"Old"}]}"#) == "Old|active|shippingbox|0|0")
    }

    @Test func unknownChoicesFallBack() {
        let json = #"{"projects":[{"name":"New","status":"someday","color":"ultraviolet","credentials":[{"kind":"passkey","title":"x"}]}]}"#
        #expect(firstProjectDecoded(from: json) == "New|active|shippingbox|0|1")
    }

    @Test func onlyTheOldArchivedStatusCarriesOver() {
        // Vaults from before archiving had a status: "archived" stays archived, the rest is in use.
        #expect(firstProjectDecoded(from: #"{"projects":[{"name":"Old","status":"archived"}]}"#) == "Old|archived|shippingbox|0|0")
        #expect(firstProjectDecoded(from: #"{"projects":[{"name":"Old","status":"paused"}]}"#) == "Old|active|shippingbox|0|0")
    }

    @Test func garbageIsReportedAsDamaged() {
        #expect(firstProjectDecoded(from: "{") == "failed")
    }
}
