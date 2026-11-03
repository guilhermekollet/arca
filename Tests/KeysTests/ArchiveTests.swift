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

    @Test func searchStillFindsArchivedProjectsLast() {
        // "Postgres de produção" is the shop's; with the shop archived it still turns up.
        #expect(quickMatchTitlesWithShopArchived("loja postgres") == ["Postgres de produção"])
        #expect(quickMatchTitlesWithShopArchived("grupo produção") == ["Postgres de produção"])
    }
}
