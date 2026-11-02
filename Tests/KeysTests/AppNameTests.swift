import Testing
@testable import Keys

@Suite("App name")
struct AppNameTests {
    @Test(arguments: [["pt-BR"], ["pt-PT"], ["pt-BR", "en-US"]])
    func portugueseSaysChaves(_ preferences: [String]) {
        #expect(appName(onMacIn: preferences) == "Chaves")
    }

    @Test(arguments: [["en-US"], ["en-GB"], ["es-MX"], ["fr-FR"], ["ja-JP"], ["de-DE", "it-IT"]])
    func everyOtherLanguageSaysKeys(_ preferences: [String]) {
        #expect(appName(onMacIn: preferences) == "Keys")
    }

    @Test func aLanguageTheAppDoesNotSpeakFallsBackToEnglish() {
        #expect(interfaceLanguage(for: ["fr-FR"]) == "en")
        #expect(interfaceLanguage(for: ["fr-FR", "es-ES"]) == "es")
    }

    @Test func finderAndTheDockFollow() {
        #expect(finderName(in: "pt-BR") == "Chaves/Chaves")
        #expect(finderName(in: "en") == "Keys/Keys")
        #expect(finderName(in: "es") == "Keys/Keys")
    }
}
