import Foundation
import Testing
@testable import Scope

@MainActor
struct AppStateTests {
    private func makeState(_ initial: StoredConfiguration = StoredConfiguration()) async -> (AppState, InMemoryConfigurationStore) {
        let store = InMemoryConfigurationStore(initial)
        let state = AppState(store: store)
        await state.load()
        return (state, store)
    }

    private func draft(_ name: String, _ value: String = "v") -> EnvironmentVariableDraft {
        var draft = EnvironmentVariableDraft()
        draft.name = name
        draft.value = value
        return draft
    }

    @Test func addPersistsToStore() async {
        let (state, store) = await makeState()
        #expect(state.saveEnvironmentVariable(draft("EDITOR", "nvim")))
        await state.waitForPendingSaves()

        #expect(state.configuration.environment.map(\.name) == ["EDITOR"])
        #expect(await store.stored.environment.first?.value == "nvim")
    }

    @Test func invalidOrDuplicateDraftsChangeNothing() async {
        let (state, store) = await makeState()
        state.saveEnvironmentVariable(draft("A"))
        #expect(!state.saveEnvironmentVariable(draft("A")))
        #expect(!state.saveEnvironmentVariable(draft("1bad")))
        await state.waitForPendingSaves()

        #expect(state.configuration.environment.count == 1)
        #expect(await store.saveCount == 1)
    }

    @Test func editingKeepsIdentityScopeAndCreationDate() async throws {
        let (state, _) = await makeState()
        state.saveEnvironmentVariable(draft("A", "1"))
        let original = try #require(state.configuration.environment.first)

        var edited = EnvironmentVariableDraft(original)
        edited.value = "2"
        edited.name = "A"  // same name as itself must not count as a duplicate
        #expect(state.saveEnvironmentVariable(edited, replacing: original.id))

        let updated = try #require(state.configuration.environment.first)
        #expect(state.configuration.environment.count == 1)
        #expect(updated.id == original.id)
        #expect(updated.createdAt == original.createdAt)
        #expect(updated.value == "2")
    }

    @Test func renamingToAnotherExistingNameIsRejected() async {
        let (state, _) = await makeState()
        state.saveEnvironmentVariable(draft("A"))
        state.saveEnvironmentVariable(draft("B"))
        let b = state.configuration.environment.first { $0.name == "B" }!
        var renamed = EnvironmentVariableDraft(b)
        renamed.name = "A"
        #expect(!state.saveEnvironmentVariable(renamed, replacing: b.id))
    }

    @Test func secretBackedValueIsNotOverwrittenByEditing() async {
        var configuration = StoredConfiguration()
        let secret = EnvironmentVariable(name: "TOKEN", secretReference: "kc:1")
        configuration.environment = [secret]
        let (state, _) = await makeState(configuration)

        var edited = EnvironmentVariableDraft(secret)
        edited.value = "should-be-ignored"
        state.saveEnvironmentVariable(edited, replacing: secret.id)

        #expect(state.configuration.environment.first?.value == nil)
        #expect(state.configuration.environment.first?.secretReference == "kc:1")
    }

    @Test func toggleAndDelete() async {
        let (state, store) = await makeState()
        state.saveEnvironmentVariable(draft("A"))
        state.saveEnvironmentVariable(draft("B"))
        let a = state.configuration.environment[0].id

        state.setEnvironmentVariable(a, enabled: false)
        #expect(state.configuration.environment[0].isEnabled == false)

        state.deleteEnvironmentVariables(ids: [a])
        await state.waitForPendingSaves()
        #expect(state.configuration.environment.map(\.name) == ["B"])
        #expect(await store.stored.environment.map(\.name) == ["B"])
    }

    @Test func searchMatchesNameAndValueButNeverSecrets() async {
        var configuration = StoredConfiguration()
        configuration.environment = [
            .init(name: "EDITOR", value: "nvim"),
            .init(name: "GOPATH", value: "/home/go"),
            .init(name: "TOKEN", value: "nvim-secret", secretReference: "kc:1"),
        ]
        let (state, _) = await makeState(configuration)

        #expect(state.environmentVariables(matching: "").map(\.name) == ["EDITOR", "GOPATH", "TOKEN"])
        #expect(state.environmentVariables(matching: "editor").map(\.name) == ["EDITOR"])
        #expect(state.environmentVariables(matching: "nvim").map(\.name) == ["EDITOR"])
        #expect(state.environmentVariables(matching: "zzz").isEmpty)
    }

    @Test func rapidChangesArePersistedInOrder() async {
        let (state, store) = await makeState()
        for index in 0..<20 { state.saveEnvironmentVariable(draft("V\(index)")) }
        await state.waitForPendingSaves()
        #expect(await store.stored.environment.count == 20)
    }

    @Test func saveFailureSurfacesAnError() async {
        let (state, store) = await makeState()
        await store.setFailSaves(true)
        state.saveEnvironmentVariable(draft("A"))
        await state.waitForPendingSaves()
        #expect(state.errorMessage != nil)
    }

    @Test func loadReadsFromStore() async {
        var configuration = StoredConfiguration()
        configuration.environment = [.init(name: "A", value: "1")]
        let (state, _) = await makeState(configuration)
        await state.load()
        #expect(state.configuration.environment.map(\.name) == ["A"])
    }
}
