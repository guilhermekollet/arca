import Testing
@testable import Arca

@Suite("Search")
struct SearchTests {
    @Test func findsProjectsByWhatTheyHold() {
        #expect(projectsMatching("supabase") == ["Loja Aurora"])
        // A variable's name and a word of the context, in any order, ignoring case and accents.
        #expect(projectsMatching("idempotente gateway_api") == ["API de Cobranças"])
        #expect(projectsMatching("cobrancas") == ["API de Cobranças"])
        #expect(projectsMatching("").count == 4)
    }

    @Test func neverSearchesSecretValues() {
        #expect(projectsMatching("sample-password-1").isEmpty)
        #expect(projectsMatching("sample-service-role-key").isEmpty)
    }

    @Test func quickSearchCombinesProjectAndItem() {
        #expect(quickMatchTitles("aurora postgres") == ["Postgres de produção"])
        #expect(quickMatchTitles("aurora production service") == ["SUPABASE_SERVICE_ROLE_KEY@production"])
        #expect(quickMatchTitles("staging") == ["VPS de staging", "GATEWAY_API_KEY@staging"])
        #expect(quickMatchTitles("   ").isEmpty)
    }
}
