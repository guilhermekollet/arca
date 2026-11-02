import Testing
@testable import Keys

@Suite("Projects inside projects")
struct ProjectTreeTests {
    @Test func theTopLevelAndWhatIsInside() {
        #expect(childrenNames(of: "") == ["Grupo", "Site"])
        #expect(childrenNames(of: "Grupo") == ["API", "Loja"])
        #expect(childrenNames(of: "Loja") == ["Checkout"])
        #expect(childrenNames(of: "Site").isEmpty)
    }

    @Test func aLoopShowsAtTheTopLevelOnly() {
        // Walking down the tree must end, and neither project may disappear.
        #expect(childrenNames(of: "", loop: true) == ["A", "B", "Grupo", "Site"])
        #expect(childrenNames(of: "A", loop: true).isEmpty)
    }

    @Test func thePathAndWhereAProjectCanMove() {
        let checkout = treeFacts("Checkout")
        #expect(checkout.path == "Grupo › Loja › Checkout")
        #expect(checkout.parents == ["Grupo", "Grupo › API", "Grupo › Loja", "Site"].map { $0.components(separatedBy: " › ").last! })
        // A project can't move inside itself or inside what it holds.
        #expect(treeFacts("Grupo").parents == ["Site"])
    }

    @Test func deletingAProjectKeepsWhatWasInsideIt() {
        #expect(parentsAfterDeleting("Loja") == ["API<Grupo", "Checkout<Grupo", "Grupo<-", "Site<-"])
        #expect(parentsAfterDeleting("Grupo") == ["API<-", "Checkout<Loja", "Loja<-", "Site<-"])
    }

    @Test func oldVaultsOpenAtTheTopLevel() {
        #expect(oldProjectHasNoParent())
    }
}
