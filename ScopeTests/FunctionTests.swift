import Foundation
import Testing
@testable import Scope

@MainActor
struct FunctionTests {
    private func makeState() async -> (AppState, InMemoryConfigurationStore) {
        let store = InMemoryConfigurationStore()
        let state = AppState(store: store)
        await state.load()
        return (state, store)
    }

    private func draft(_ name: String, _ body: String = "  echo hi") -> FunctionDraft {
        var draft = FunctionDraft()
        draft.name = name
        draft.body = body
        return draft
    }

    @Test func draftValidation() {
        #expect(draft("").nameIssue(existingNames: []) != nil)
        #expect(draft("1x").nameIssue(existingNames: []) != nil)
        #expect(draft("a b").nameIssue(existingNames: []) != nil)
        #expect(draft("mkcd").nameIssue(existingNames: ["mkcd"]) != nil)
        #expect(draft("my-fn.2").nameIssue(existingNames: []) == nil)
        #expect(draft("f", " \n ").bodyIssue() != nil)
        #expect(draft("f", "a\0b").bodyIssue() != nil)
    }

    @Test func aliasNameClashIsAWarningNotAnError() {
        let d = draft("gs")
        #expect(d.nameWarning(aliasNames: ["gs"]) != nil)
        #expect(d.nameWarning(aliasNames: ["ll"]) == nil)
        #expect(d.isValid(existingNames: []))
    }

    @Test func previewMatchesGenerator() {
        #expect(draft("mkcd", "\n  mkdir -p \"$1\"\n").generatedText == "mkcd() {\n  mkdir -p \"$1\"\n}")
        #expect(draft("", "x").generatedText == nil)
    }

    @Test func bodyLineMappingSkipsWrapperAndLeadingBlankLines() {
        let d = draft("f", "\n\n  one\n  two")  // generated: f() {\n  one\n  two\n}
        #expect(d.bodyLine(forGeneratedLine: 1) == nil)
        #expect(d.bodyLine(forGeneratedLine: 2) == 3)
        #expect(d.bodyLine(forGeneratedLine: 3) == 4)
        #expect(d.bodyLine(forGeneratedLine: 4) == nil)
    }

    @Test func addEditToggleDeletePersist() async throws {
        let (state, store) = await makeState()
        let id = try #require(state.saveFunction(draft("mkcd")))
        #expect(state.saveFunction(draft("mkcd")) == nil)
        #expect(state.saveFunction(draft("bad name")) == nil)

        var edited = FunctionDraft(try #require(state.configuration.functions.first))
        edited.body = "  echo changed"
        #expect(state.saveFunction(edited, replacing: id) == id)
        #expect(state.configuration.functions.count == 1)
        #expect(state.configuration.functions.first?.body == "  echo changed")

        state.setFunction(id, enabled: false)
        await state.waitForPendingSaves()
        #expect(await store.stored.functions.first?.isEnabled == false)

        state.deleteFunctions(ids: [id])
        #expect(state.configuration.functions.isEmpty)
    }

    @Test func searchMatchesNameAndBodySorted() async {
        let (state, _) = await makeState()
        state.saveFunction(draft("zz", "git log"))
        state.saveFunction(draft("gco", "git checkout"))
        state.saveFunction(draft("mkcd", "mkdir"))
        #expect(state.functions(matching: "").map(\.name) == ["gco", "mkcd", "zz"])
        #expect(state.functions(matching: "git").map(\.name) == ["gco", "zz"])
    }

    @Test func enabledAliasNamesIgnoresDisabled() async {
        var configuration = StoredConfiguration()
        configuration.aliases = [.init(name: "on", command: "x"), .init(name: "off", command: "x", isEnabled: false)]
        let state = AppState(store: InMemoryConfigurationStore(configuration))
        await state.load()
        #expect(state.enabledAliasNames() == ["on"])
    }

    @Test func syntaxCheckUsesRealZsh() async {
        let (state, _) = await makeState()
        #expect(await state.checkSyntax(of: draft("ok", "  echo \"$1\"")) == .valid)
        #expect(await state.checkSyntax(of: draft("bad", "  if true; then"))?.isValid == false)
        #expect(await state.checkSyntax(of: draft("", "x")) == nil)
    }
}
