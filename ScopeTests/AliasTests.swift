import Foundation
import Testing
@testable import Scope

@MainActor
struct AliasTests {
    private func makeState() async -> (AppState, InMemoryConfigurationStore) {
        let store = InMemoryConfigurationStore()
        let state = AppState(store: store)
        await state.load()
        return (state, store)
    }

    private func draft(_ name: String, _ command: String = "echo hi") -> AliasDraft {
        var draft = AliasDraft()
        draft.name = name
        draft.command = command
        return draft
    }

    @Test func draftValidation() {
        #expect(draft("").nameIssue(existingNames: []) != nil)
        #expect(draft("-x").nameIssue(existingNames: []) != nil)
        #expect(draft("a b").nameIssue(existingNames: []) != nil)
        #expect(draft("gs").nameIssue(existingNames: ["gs"]) != nil)
        #expect(draft("g-s.1").nameIssue(existingNames: []) == nil)
        #expect(draft("gs", "  \n").commandIssue() != nil)
        #expect(draft("gs", "a\0b").commandIssue() != nil)
    }

    @Test func previewMatchesGeneratorAndEscapesQuotes() {
        #expect(draft("gs", "git status").generatedLine == "alias gs='git status'")
        #expect(draft("say", "echo 'hi'").generatedLine == "alias say='echo '\\''hi'\\'''")
        #expect(draft("", "x").generatedLine == nil)
    }

    @Test func addEditToggleDeletePersist() async throws {
        let (state, store) = await makeState()
        #expect(state.saveAlias(draft("gs", "git status")))
        #expect(!state.saveAlias(draft("gs")))
        #expect(!state.saveAlias(draft("bad name")))
        let original = try #require(state.configuration.aliases.first)

        var edited = AliasDraft(original)
        edited.command = "git status -sb"
        #expect(state.saveAlias(edited, replacing: original.id))
        let updated = try #require(state.configuration.aliases.first)
        #expect(updated.id == original.id && updated.createdAt == original.createdAt)
        #expect(updated.command == "git status -sb")

        state.setAlias(original.id, enabled: false)
        #expect(state.configuration.aliases.first?.isEnabled == false)
        await state.waitForPendingSaves()
        #expect(await store.stored.aliases.first?.isEnabled == false)

        state.deleteAliases(ids: [original.id])
        #expect(state.configuration.aliases.isEmpty)
    }

    @Test func searchMatchesNameAndCommandSorted() async {
        let (state, _) = await makeState()
        state.saveAlias(draft("zz", "git log"))
        state.saveAlias(draft("gs", "git status"))
        state.saveAlias(draft("ll", "ls -l"))
        #expect(state.aliases(matching: "").map(\.name) == ["gs", "ll", "zz"])
        #expect(state.aliases(matching: "git").map(\.name) == ["gs", "zz"])
    }
}
