import Testing
@testable import Arca

@Suite("Password generator")
struct PasswordGeneratorTests {
    @Test(arguments: [8, 24, 64])
    func hasTheChosenLength(_ length: Int) {
        #expect(PasswordGenerator(length: length).generate().count == length)
    }

    @Test func includesEveryChosenKind() {
        for _ in 0..<200 {
            let password = Array(PasswordGenerator(length: 8).generate())
            #expect(password.contains { PasswordGenerator.uppercaseSet.contains($0) })
            #expect(password.contains { PasswordGenerator.lowercaseSet.contains($0) })
            #expect(password.contains { PasswordGenerator.digitSet.contains($0) })
            #expect(password.contains { PasswordGenerator.symbolSet.contains($0) })
        }
    }

    @Test func leavesOutWhatWasTurnedOff() {
        let generator = PasswordGenerator(length: 40, uppercase: false, lowercase: true, digits: true, symbols: false)
        let allowed = Set(PasswordGenerator.lowercaseSet + PasswordGenerator.digitSet)
        #expect(generator.generate().allSatisfy { allowed.contains($0) })
    }

    @Test func neverUsesLookAlikesOrQuotes() {
        let password = PasswordGenerator(length: 64).generate()
        #expect(!password.contains { "0O1lI'\"`\\ ".contains($0) })
    }

    @Test func withNothingChosenStillMakesAPassword() {
        let generator = PasswordGenerator(length: 12, uppercase: false, lowercase: false, digits: false, symbols: false)
        #expect(generator.generate().count == 12)
    }

    @Test func passwordsDiffer() {
        let passwords = Set((0..<50).map { _ in PasswordGenerator().generate() })
        #expect(passwords.count == 50)
    }
}
