import Testing
@testable import Arca

@Suite("Dotenv")
struct DotEnvTests {
    private func pairs(_ text: String) -> [String] {
        DotEnv.parse(text).map { "\($0.key)=\($0.value)" }
    }

    @Test func readsPlainLinesAndSkipsTheRest() {
        let text = """
        # Database
        DATABASE_URL=postgres://localhost:5432/app

        export PORT=3000
        not a variable
        1BAD=x
        EMPTY=
        """
        #expect(pairs(text) == ["DATABASE_URL=postgres://localhost:5432/app", "PORT=3000", "EMPTY="])
    }

    @Test func dropsCommentsAfterUnquotedValues() {
        #expect(pairs("MODE=fast # or slow\nCOLOR=#fff") == ["MODE=fast", "COLOR=#fff"])
    }

    @Test func trimsSpacesAroundTheEqualsSign() {
        #expect(pairs("  NAME =  Arca  ") == ["NAME=Arca"])
    }

    @Test func understandsQuotes() {
        let text = #"""
        SINGLE='a $literal # kept'
        DOUBLE="line one\nline two \"quoted\""
        BACKTICK=`it's fine`
        TRAILING="value" # comment
        """#
        let entries = DotEnv.parse(text)
        #expect(entries.map(\.key) == ["SINGLE", "DOUBLE", "BACKTICK", "TRAILING"])
        #expect(entries[0].value == "a $literal # kept")
        #expect(entries[1].value == "line one\nline two \"quoted\"")
        #expect(entries[2].value == "it's fine")
        #expect(entries[3].value == "value")
    }

    @Test func quotedValuesMaySpanLines() {
        let text = "KEY=\"-----BEGIN KEY-----\nabc\n-----END KEY-----\"\nNEXT=1"
        #expect(pairs(text) == ["KEY=-----BEGIN KEY-----\nabc\n-----END KEY-----", "NEXT=1"])
    }

    @Test func anUnclosedQuoteIsPartOfThePlainValue() {
        #expect(pairs("A=\"oops\nB=2") == ["A=\"oops", "B=2"])
    }

    @Test func windowsLineEndings() {
        #expect(pairs("A=1\r\nB=2\r\n") == ["A=1", "B=2"])
    }

    @Test func formatsWhatParseReadsBack() {
        let entries = [
            DotEnv.Entry(key: "PLAIN", value: "postgres://user@host:5432/db"),
            DotEnv.Entry(key: "SPACES", value: "two words"),
            DotEnv.Entry(key: "DOLLAR", value: "pa$$word"),
            DotEnv.Entry(key: "QUOTE", value: "it's \"both\""),
            DotEnv.Entry(key: "MULTILINE", value: "one\ntwo"),
            DotEnv.Entry(key: "BACKSLASH", value: #"C:\path\n"#),
            DotEnv.Entry(key: "HASH", value: "#hashtag"),
            DotEnv.Entry(key: "EMPTY", value: ""),
        ]
        #expect(DotEnv.parse(DotEnv.format(entries)) == entries)
    }

    @Test func quotesOnlyWhenNeeded() {
        #expect(DotEnv.quoted("abc-123") == "abc-123")
        #expect(DotEnv.quoted("a b") == "'a b'")
        #expect(DotEnv.quoted("it's") == #""it's""#)
    }

    @Test func mergingUpdatesAndAdds() {
        let result = merge("API_TOKEN=new\nPORT=3000\nPORT=4000\nHOST=localhost", into: [("PORT", "80"), ("HOST", "localhost")])
        #expect(result.added == 1)
        #expect(result.updated == 2)
        #expect(result.lines == ["PORT=4000", "HOST=localhost", "API_TOKEN=new (secret)"])
    }

    @Test(arguments: ["STRIPE_SECRET_KEY", "GITHUB_TOKEN", "DB_PASSWORD", "DATABASE_URL", "jwt_private"])
    func secretLookingNames(_ key: String) {
        #expect(Variable.looksSecret(key))
    }

    @Test(arguments: ["PORT", "NODE_ENV", "NEXT_PUBLIC_SITE_NAME", "LOG_LEVEL"])
    func plainNames(_ key: String) {
        #expect(!Variable.looksSecret(key))
    }
}
