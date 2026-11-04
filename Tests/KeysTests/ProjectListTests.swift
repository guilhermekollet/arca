import Testing
@testable import Keys

@Suite("Project list search")
struct ProjectListTests {
    @Test func anEmptySearchKeepsEverything() {
        #expect(projectListMatches("").count == 2 + 6 + 3)
    }

    @Test func searchesNamesUsernamesAndAddresses() {
        #expect(projectListMatches("vercel") == ["Vercel"])
        #expect(projectListMatches("postgres") == ["Postgres de produção"])
        #expect(projectListMatches("dev@example") == ["Vercel"])
        #expect(projectListMatches("webhook") == ["PIX_WEBHOOK_SECRET@development", "PIX_WEBHOOK_SECRET@production"])
        #expect(projectListMatches("github") == ["Repositório"])
    }

    @Test func neverSearchesValuesOrPasswords() {
        #expect(projectListMatches("sample-password-1").isEmpty)
        #expect(projectListMatches("sample-webhook-secret").isEmpty)
    }
}
