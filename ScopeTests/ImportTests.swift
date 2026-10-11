import Foundation
import Testing
@testable import Scope

@MainActor
struct ImportTests {
    private func parse(_ text: String) -> ImportParseResult {
        ShellImporter.parse(text, file: ".zshrc")
    }

    private func items(_ text: String) -> [ImportedItem] {
        parse(text).candidates.map(\.item)
    }

    @Test func exportsQuotedAndUnquoted() {
        let found = items("""
        export A=plain
        export B='it'\\''s'
        export C="$HOME/x"
        export D="literal" # note
        export E=~/bin
        """)
        // B is single-quoted with an escaped quote sequence, which is not one word.
        #expect(found.contains(.environment(name: "A", value: "plain", mode: .literal)))
        #expect(found.contains(.environment(name: "C", value: "$HOME/x", mode: .expression)))
        #expect(found.contains(.environment(name: "D", value: "literal", mode: .literal)))
        #expect(found.contains(.environment(name: "E", value: "$HOME/bin", mode: .expression)))
        #expect(!found.contains { if case .environment(let n, _, _) = $0 { n == "B" } else { false } })
    }

    @Test func ambiguousLinesStayDetected() {
        let result = parse("""
        export A=1; export B=2
        export C=$(date)
        export D
        [[ -f x ]] && export E=1
        eval "$(brew shellenv)"
        """)
        #expect(result.candidates.isEmpty)
        #expect(result.detected.count == 5)
    }

    @Test func conditionalBlocksAreNotImported() {
        let result = parse("""
        if [[ -d /opt ]]; then
          export A=1
          alias x='y'
        fi
        export B=2
        """)
        #expect(result.candidates.map(\.item) == [.environment(name: "B", value: "2", mode: .literal)])
        #expect(result.detected.count == 4)
    }

    @Test func secretsAreNotImported() {
        let result = parse("export GITHUB_TOKEN=abc123\nexport API_KEY='x'\nexport EDITOR=vim")
        #expect(result.candidates.count == 1)
        #expect(result.detected.count == 2)
    }

    @Test func aliasesOnlyWhenLiteral() {
        let found = items("""
        alias gs='git status'
        alias ll="ls -lah"
        alias bad="echo $HOME"
        alias home=~/x
        alias -g G='| grep'
        """)
        #expect(found == [.alias(name: "gs", command: "git status"), .alias(name: "ll", command: "ls -lah")])
    }

    @Test func pathPrependOnly() {
        let found = items("""
        export PATH="$HOME/bin:/opt/homebrew/bin:$PATH"
        export PATH=$PATH:/append
        """)
        #expect(found == [.path("$HOME/bin"), .path("/opt/homebrew/bin")])
    }

    @Test func functionsBothStyles() {
        let found = items("""
        greet() {
          echo hi
        }
        function bye {
          echo bye
        }
        """)
        #expect(found == [
            .function(name: "greet", body: "  echo hi"),
            .function(name: "bye", body: "  echo bye"),
        ])
    }

    @Test func multilineStringsDoNotLeakStatements() {
        let result = parse("alias x='line one\nexport LEAK=1\nend'\nexport OK=1")
        #expect(result.candidates.map(\.item) == [.environment(name: "OK", value: "1", mode: .literal)])
    }

    @Test func scopeHookBlockIsIgnored() {
        let result = parse("\(StartupHook.block)\nexport A=1")
        #expect(result.candidates.count == 1)
        #expect(result.detected.isEmpty)
    }

    @Test func mergeAppliesShellPrecedence() {
        let early = ShellImporter.parse("export A=1\nexport PATH=\"/a:$PATH\"", file: ".zshenv", fileOrder: 0)
        let late = ShellImporter.parse("export A=2\nexport PATH=\"/b:/a:$PATH\"", file: ".zshrc", fileOrder: 2)
        let merged = ImportScanner.merge([early, late])
        let kept = merged.candidates.map(\.item)
        #expect(kept.contains(.environment(name: "A", value: "2", mode: .literal)))
        #expect(!kept.contains(.environment(name: "A", value: "1", mode: .literal)))
        #expect(kept.filter { if case .path = $0 { true } else { false } } == [.path("/b"), .path("/a")])
        #expect(merged.detected.count == 2)
    }

    @Test func importingCreatesItemsOnceAndSkipsDuplicates() async throws {
        let store = InMemoryConfigurationStore()
        let state = AppState(store: store)
        await state.load()
        let batch: [ImportedItem] = [
            .environment(name: "A", value: "1", mode: .literal),
            .path("/x"), .path("/y"),
            .alias(name: "gs", command: "git status"),
            .function(name: "f", body: "echo"),
        ]
        #expect(state.importItems(batch, into: .global) == 5)
        #expect(state.importItems(batch, into: .global) == 0)
        #expect(state.pathEntries().map(\.rawPath) == ["/x", "/y"])
        #expect(state.isAlreadyInScope(.alias(name: "gs", command: ""), scope: .global))
        await state.waitForPendingSaves()
        #expect(await store.stored.aliases.count == 1)
    }
}
