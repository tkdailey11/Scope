import Foundation
import Testing
@testable import Scope

@MainActor
struct SyncTests {
    private func makeMac(_ transport: InMemorySyncTransport, id: String) async -> (AppState, SyncCoordinator) {
        let state = AppState(
            store: InMemoryConfigurationStore(),
            deviceIdentity: DeviceIdentity(identifier: id, displayName: id)
        )
        await state.load()
        let sync = SyncCoordinator(appState: state, transport: transport, stateStore: InMemorySyncStateStore())
        await sync.setEnabled(true)
        return (state, sync)
    }

    private func alias(_ name: String, _ command: String = "x") -> AliasDraft {
        var draft = AliasDraft()
        draft.name = name
        draft.command = command
        return draft
    }

    @Test func digestIgnoresTimestampsActivationAndSecretValues() {
        let a = ShellAlias(name: "gs", command: "git status", createdAt: .distantPast, modifiedAt: .distantPast)
        let b = ShellAlias(id: a.id, name: "gs", command: "git status", createdAt: .now, modifiedAt: .now)
        #expect(SyncItem.alias(a).digest == SyncItem.alias(b).digest)
        let p = Profile(name: "Work", isActive: true)
        var q = p
        q.isActive = false
        #expect(SyncItem.profile(p).digest == SyncItem.profile(q).digest)
        let secret = EnvironmentVariable(name: "K", value: "plaintext", secretReference: "ref")
        #expect(SyncItem.environment(secret).portable == .environment(EnvironmentVariable(id: secret.id, name: "K", value: nil, secretReference: "ref", createdAt: secret.createdAt, modifiedAt: secret.modifiedAt)))
    }

    @Test func machineScopedItemsNeverLeave() async throws {
        let transport = InMemorySyncTransport()
        let (a, syncA) = await makeMac(transport, id: "A")
        let machine = try #require(a.currentMachineID)
        var draft = alias("local")
        draft.name = "local"
        a.saveAlias(draft, scope: .machine(machine))
        a.saveAlias(alias("shared"))
        await syncA.syncNow()
        let names = await transport.records.values.compactMap { $0.item?.title }
        #expect(names == ["shared"])
    }

    @Test func changesFlowBetweenMacsIncludingDeletes() async {
        let transport = InMemorySyncTransport()
        let (a, syncA) = await makeMac(transport, id: "A")
        let (b, syncB) = await makeMac(transport, id: "B")

        a.saveAlias(alias("gs", "git status"))
        await syncA.syncNow()
        await syncB.syncNow()
        #expect(b.configuration.aliases.map(\.name) == ["gs"])

        let id = b.configuration.aliases[0].id
        b.deleteAliases(ids: [id])
        await syncB.syncNow()
        await syncA.syncNow()
        #expect(a.configuration.aliases.isEmpty)
    }

    @Test func activeProfileStaysPerMac() async {
        let transport = InMemorySyncTransport()
        let (a, syncA) = await makeMac(transport, id: "A")
        let (b, syncB) = await makeMac(transport, id: "B")
        let id = a.saveProfile(name: "Work")
        a.setActiveProfile(id)
        await syncA.syncNow()
        await syncB.syncNow()
        #expect(b.configuration.profiles.map(\.name) == ["Work"])
        #expect(b.activeProfile == nil)
        #expect(a.activeProfile?.name == "Work")
    }

    @Test func concurrentEditsBecomeConflictAndResolve() async throws {
        let transport = InMemorySyncTransport()
        let (a, syncA) = await makeMac(transport, id: "A")
        let (b, syncB) = await makeMac(transport, id: "B")
        a.saveAlias(alias("gs", "git status"))
        await syncA.syncNow()
        await syncB.syncNow()

        let idA = a.configuration.aliases[0].id
        a.saveAlias(alias("gs", "git status -sb"), replacing: idA)
        b.saveAlias(alias("gs", "git status --short"), replacing: b.configuration.aliases[0].id)
        await syncA.syncNow()
        await syncB.syncNow()

        #expect(syncB.conflicts.count == 1)
        // Nothing was overwritten.
        #expect(b.configuration.aliases[0].command == "git status --short")

        await syncB.resolve(idA, keepLocal: true)
        await syncA.syncNow()
        #expect(syncB.conflicts.isEmpty)
        #expect(a.configuration.aliases[0].command == "git status --short")
    }

    @Test func keepRemoteAppliesTheOtherVersion() async {
        let transport = InMemorySyncTransport()
        let (a, syncA) = await makeMac(transport, id: "A")
        let (b, syncB) = await makeMac(transport, id: "B")
        a.saveAlias(alias("gs", "one"))
        await syncA.syncNow()
        await syncB.syncNow()
        a.saveAlias(alias("gs", "from-a"), replacing: a.configuration.aliases[0].id)
        b.saveAlias(alias("gs", "from-b"), replacing: b.configuration.aliases[0].id)
        await syncA.syncNow()
        await syncB.syncNow()
        await syncB.resolve(b.configuration.aliases[0].id, keepLocal: false)
        #expect(b.configuration.aliases[0].command == "from-a")
    }

    @Test func offlineFailureKeepsLocalEditsAndRetries() async {
        let transport = InMemorySyncTransport()
        let (a, syncA) = await makeMac(transport, id: "A")
        a.saveAlias(alias("gs"))
        await transport.setFailNextPush(true)
        await syncA.syncNow()
        #expect(syncA.lastError != nil)
        #expect(a.configuration.aliases.count == 1)
        await syncA.syncNow()
        #expect(syncA.lastError == nil)
        #expect(await transport.records.count == 1)
    }

    @Test func unavailableAccountDoesNotEnableSync() async {
        let transport = InMemorySyncTransport()
        await transport.setStatus(.noAccount)
        let (_, sync) = await makeMac(transport, id: "A")
        #expect(!sync.isEnabled)
        #expect(sync.lastError != nil)
    }
}
