import Testing
@testable import Chaves

@Suite("Menu bar")
struct MenuBarTests {
    @Test func aProjectListsEverythingUntilSearched() {
        #expect(projectItemTitles("Loja Aurora", query: "") == [
            "Vercel", "Postgres de produção",
            "NEXT_PUBLIC_SUPABASE_URL@development", "SUPABASE_SERVICE_ROLE_KEY@development", "PIX_WEBHOOK_SECRET@development",
            "NEXT_PUBLIC_SUPABASE_URL@production", "SUPABASE_SERVICE_ROLE_KEY@production", "PIX_WEBHOOK_SECRET@production",
        ])
    }

    @Test func searchingInsideAProjectNarrowsIt() {
        #expect(projectItemTitles("Loja Aurora", query: "postgres") == ["Postgres de produção"])
        #expect(projectItemTitles("Loja Aurora", query: "webhook prod") == ["PIX_WEBHOOK_SECRET@production"])
        #expect(projectItemTitles("Loja Aurora", query: "gateway").isEmpty)
    }

    @Test func anEmptyProjectListsNothing() {
        #expect(projectItemTitles("Site institucional", query: "").isEmpty)
    }

    @Test func aGroupListsItsOwnItemsButSearchesItsSubprojects() {
        #expect(projectItemTitles("Grupo Aurora", query: "") == ["Google Workspace"])
        #expect(projectItemTitles("Grupo Aurora", query: "produção") == ["Postgres de produção"])
        #expect(projectItemTitles("Grupo Aurora", query: "staging") == ["VPS de staging", "GATEWAY_API_KEY@staging"])
    }
}

@Suite("Auto-lock")
struct AutoLockTests {
    @Test func touchIDLastsTheChosenTime() {
        #expect(!locks(minutesSinceUnlock: 119, unlockMinutes: 120))
        #expect(locks(minutesSinceUnlock: 120, unlockMinutes: 120))
        #expect(locks(minutesSinceUnlock: 16, unlockMinutes: 15))
    }

    @Test func beingIdleLocksSoonerOnlyWhenAskedTo() {
        #expect(!locks(minutesSinceUnlock: 60, unlockMinutes: 120, idleMinutes: 50))
        #expect(locks(minutesSinceUnlock: 60, unlockMinutes: 120, idleMinutes: 50, idleLock: 30))
        #expect(!locks(minutesSinceUnlock: 60, unlockMinutes: 120, idleMinutes: 10, idleLock: 30))
    }
}
