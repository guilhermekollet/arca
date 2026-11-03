import Testing
@testable import Keys

@Suite("Archiving")
struct ArchiveTests {
    @Test func archivingAProjectArchivesWhatIsInsideIt() {
        let result = archiving("Loja")
        #expect(result.archived == ["Checkout", "Loja"])
        #expect(result.activeRoots == ["Grupo", "Site"])
        // Loja heads the archived list, its parent still being in use.
        #expect(result.archivedRoots == ["Loja"])
    }

    @Test func archivingAGroupArchivesTheWholeGroup() {
        let result = archiving("Grupo")
        #expect(result.archived == ["API", "Checkout", "Grupo", "Loja"])
        #expect(result.activeRoots == ["Site"])
        #expect(result.archivedRoots == ["Grupo"])
    }

    @Test func unarchivingBringsTheSubprojectsBack() {
        let result = archiving("Grupo", archived: false, startingArchived: ["Grupo", "Loja", "API", "Checkout"])
        #expect(result.archived.isEmpty)
        #expect(result.archivedRoots.isEmpty)
    }

    @Test func aProjectBroughtBackFromAnArchivedGroupHeadsTheActiveList() {
        let result = archiving("Loja", archived: false, startingArchived: ["Grupo", "Loja", "API", "Checkout"])
        #expect(result.archived == ["API", "Grupo"])
        #expect(result.activeRoots == ["Loja", "Site"])
        #expect(result.archivedRoots == ["Grupo"])
    }

    @Test func searchLeavesArchivedProjectsOut() {
        // "Postgres de produção" is the shop's: archived, nothing of it turns up.
        #expect(quickMatchTitlesWithShopArchived("loja postgres").isEmpty)
        #expect(quickMatchTitlesWithShopArchived("grupo produção").isEmpty)
        // What's still in use is found as before.
        #expect(quickMatchTitlesWithShopArchived("staging") == ["VPS de staging", "GATEWAY_API_KEY@staging"])
    }

    @Test func deletingForGoodTakesTheSubprojectsAlong() {
        #expect(remainingAfterDeletingForGood("Loja") == ["API", "Grupo", "Site"])
        #expect(remainingAfterDeletingForGood("Grupo") == ["Site"])
    }
}
