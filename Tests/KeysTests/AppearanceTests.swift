import Testing
@testable import Keys

@Suite("Appearance")
struct AppearanceTests {
    @Test func theChoicesAreSystemLightAndDark() {
        #expect(Preferences.Appearance.allCases.map(\.rawValue) == ["system", "light", "dark"])
    }

    @Test func anUnknownChoiceFollowsTheSystem() {
        #expect(storedAppearance(nil) == .system)
        #expect(storedAppearance("sepia") == .system)
        #expect(storedAppearance("light") == .light)
        #expect(storedAppearance("dark") == .dark)
    }
}
