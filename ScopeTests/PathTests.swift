import Foundation
import Testing
@testable import Scope

@MainActor
struct PathTests {
    private func makeState(_ initial: StoredConfiguration = StoredConfiguration()) async -> (AppState, InMemoryConfigurationStore) {
        let store = InMemoryConfigurationStore(initial)
        let state = AppState(store: store)
        await state.load()
        return (state, store)
    }

    private func draft(_ path: String) -> PathEntryDraft {
        var draft = PathEntryDraft()
        draft.rawPath = path
        return draft
    }

    // MARK: Draft validation

    @Test func draftRejectsEmptyColonDuplicateAndDanglingBackslash() {
        #expect(draft("  ").pathIssue(existingPaths: []) != nil)
        #expect(draft("/a:/b").pathIssue(existingPaths: []) != nil)
        #expect(draft("~/bin").pathIssue(existingPaths: ["~/bin"]) != nil)
        #expect(draft("/a\\").pathIssue(existingPaths: []) != nil)
        #expect(draft(" ~/bin ").pathIssue(existingPaths: []) == nil)
    }

    @Test func draftPreviewMatchesGeneratorOutput() {
        #expect(draft("~/go/bin").generatedLine == "export PATH=\"$HOME/go/bin:$PATH\"")
        #expect(draft("a:b").generatedLine == nil)
    }

    // MARK: AppState

    @Test func newEntriesAppendAndPersist() async {
        let (state, store) = await makeState()
        #expect(state.savePathEntry(draft("/a")))
        #expect(state.savePathEntry(draft(" /b ")))
        await state.waitForPendingSaves()

        #expect(state.pathEntries().map(\.rawPath) == ["/a", "/b"])
        #expect(await store.stored.path.map(\.order) == [0, 1])
    }

    @Test func duplicatesAndInvalidDraftsChangeNothing() async {
        let (state, store) = await makeState()
        state.savePathEntry(draft("/a"))
        #expect(!state.savePathEntry(draft("/a")))
        #expect(!state.savePathEntry(draft("")))
        await state.waitForPendingSaves()

        #expect(state.configuration.path.count == 1)
        #expect(await store.saveCount == 1)
    }

    @Test func editingKeepsIdentityOrderAndScope() async throws {
        let (state, _) = await makeState()
        state.savePathEntry(draft("/a"))
        state.savePathEntry(draft("/b"))
        let original = try #require(state.pathEntries().last)

        var edited = PathEntryDraft(original)
        edited.rawPath = "/c"
        #expect(state.savePathEntry(edited, replacing: original.id))

        let updated = try #require(state.pathEntries().last)
        #expect(updated.id == original.id)
        #expect(updated.order == original.order)
        #expect(updated.rawPath == "/c")
    }

    @Test func moveRenumbersOrderAndChangesGeneratedPriority() async throws {
        let (state, _) = await makeState()
        for path in ["/a", "/b", "/c"] { state.savePathEntry(draft(path)) }

        state.movePathEntries(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(state.pathEntries().map(\.rawPath) == ["/c", "/a", "/b"])
        #expect(state.pathEntries().map(\.order) == [0, 1, 2])

        // First in the list must end up first in $PATH (the last line written).
        let effective = ConfigurationComposer.compose(state.configuration.snapshot, activeProfileID: nil, machineID: nil)
        let output = try ZshGenerator.generate(effective)
        let lines = output.split(separator: "\n").filter { $0.hasPrefix("export PATH") }
        #expect(lines.last == "export PATH=\"/c:$PATH\"")
    }

    @Test func noOpMoveDoesNotSave() async {
        let (state, store) = await makeState()
        state.savePathEntry(draft("/a"))
        state.savePathEntry(draft("/b"))
        await state.waitForPendingSaves()
        let saves = await store.saveCount

        state.movePathEntries(fromOffsets: IndexSet(integer: 0), toOffset: 0)
        await state.waitForPendingSaves()
        #expect(await store.saveCount == saves)
    }

    @Test func toggleAndDelete() async throws {
        let (state, _) = await makeState()
        state.savePathEntry(draft("/a"))
        state.savePathEntry(draft("/b"))
        let first = try #require(state.pathEntries().first)

        state.setPathEntry(first.id, enabled: false)
        #expect(state.pathEntries().first?.isEnabled == false)

        state.deletePathEntries(ids: [first.id])
        #expect(state.pathEntries().map(\.rawPath) == ["/b"])
    }

    // MARK: Inspector

    @Test func inspectorExpandsHomeAndFlagsOtherVariables() throws {
        let home = FileManager.default.temporaryDirectory.appending(path: "scope-path-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: home.appending(path: "bin"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let inspector = PathInspector(home: home)

        #expect(inspector.status(of: "~/bin") == .exists)
        #expect(inspector.status(of: "$HOME/bin") == .exists)
        #expect(inspector.status(of: "${HOME}/bin") == .exists)
        #expect(inspector.status(of: "~/nope") == .missing)
        #expect(inspector.status(of: "$HOMEBREW_PREFIX/bin") == .unresolvable)
        #expect(inspector.authoredForm(of: home.appending(path: "bin")) == "~/bin")
        #expect(inspector.authoredForm(of: URL(filePath: "/opt/homebrew/bin")) == "/opt/homebrew/bin")
    }
}
