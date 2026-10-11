import Foundation
import Testing
@testable import Scope

@MainActor
struct ProfileTests {
    private let device = DeviceIdentity(identifier: "device-1", displayName: "Studio")

    private func makeState(_ initial: StoredConfiguration = StoredConfiguration(), device: DeviceIdentity? = nil) async -> (AppState, InMemoryConfigurationStore) {
        let store = InMemoryConfigurationStore(initial)
        let state = AppState(store: store, deviceIdentity: device ?? self.device)
        await state.load()
        return (state, store)
    }

    private func envDraft(_ name: String, _ value: String) -> EnvironmentVariableDraft {
        var draft = EnvironmentVariableDraft()
        draft.name = name
        draft.value = value
        return draft
    }

    @Test func loadRegistersThisMacOnce() async {
        let (state, store) = await makeState()
        await state.waitForPendingSaves()
        #expect(state.currentMachine?.stableDeviceIdentifier == "device-1")
        #expect(await store.stored.machines.count == 1)

        let (again, _) = await makeState(await store.stored)
        #expect(again.configuration.machines.count == 1)
        #expect(again.currentMachineID == state.currentMachineID)
    }

    @Test func renamedMacKeepsIdentityAndItems() async {
        let (first, store) = await makeState()
        let machineID = first.currentMachineID!
        first.saveEnvironmentVariable(envDraft("A", "1"), scope: .machine(machineID))
        await first.waitForPendingSaves()

        let (renamed, _) = await makeState(await store.stored, device: DeviceIdentity(identifier: "device-1", displayName: "New Name"))
        #expect(renamed.currentMachineID == machineID)
        #expect(renamed.currentMachine?.displayName == "New Name")
        #expect(renamed.effectiveConfiguration.environment.map(\.item.name) == ["A"])
    }

    @Test func profileNamesMustBeUniqueAndNonEmpty() async {
        let (state, _) = await makeState()
        #expect(state.saveProfile(name: "Work") != nil)
        #expect(state.saveProfile(name: " work ") == nil)
        #expect(state.saveProfile(name: "   ") == nil)
        #expect(state.configuration.profiles.count == 1)
    }

    @Test func renamingKeepsOwnNameValid() async {
        let (state, _) = await makeState()
        let id = state.saveProfile(name: "Work")!
        #expect(state.saveProfile(name: "Work", iconName: "briefcase", replacing: id) == id)
        #expect(state.configuration.profiles.first?.iconName == "briefcase")
    }

    @Test func onlyOneProfileIsActive() async {
        let (state, _) = await makeState()
        let work = state.saveProfile(name: "Work")!
        let home = state.saveProfile(name: "Home")!
        state.setActiveProfile(work)
        state.setActiveProfile(home)
        #expect(state.configuration.profiles.filter(\.isActive).map(\.id) == [home])
        state.setActiveProfile(nil)
        #expect(state.activeProfile == nil)
    }

    @Test func activeProfileOverridesGlobalInEffectiveConfiguration() async {
        let (state, _) = await makeState()
        let work = state.saveProfile(name: "Work")!
        state.saveEnvironmentVariable(envDraft("EDITOR", "vim"))
        state.saveEnvironmentVariable(envDraft("EDITOR", "code"), scope: .profile(work))
        #expect(state.effectiveConfiguration.environment.first?.item.value == "vim")
        state.setActiveProfile(work)
        #expect(state.effectiveConfiguration.environment.first?.item.value == "code")
    }

    @Test func deletingProfileRemovesItsItemsOnly() async {
        let (state, store) = await makeState()
        let work = state.saveProfile(name: "Work")!
        state.saveEnvironmentVariable(envDraft("KEEP", "1"))
        state.saveEnvironmentVariable(envDraft("GONE", "1"), scope: .profile(work))
        state.deleteProfile(work)
        await state.waitForPendingSaves()

        #expect(state.configuration.profiles.isEmpty)
        #expect(state.configuration.environment.map(\.name) == ["KEEP"])
        #expect(await store.stored.environment.map(\.name) == ["KEEP"])
    }

    @Test func thisMacCannotBeForgotten() async {
        var other = StoredConfiguration()
        let stranger = Machine(displayName: "Laptop", stableDeviceIdentifier: "device-2")
        other.machines = [stranger]
        other.aliases = [.init(name: "x", command: "y", scope: .machine(stranger.id))]
        let (state, _) = await makeState(other)

        state.forgetMachine(state.currentMachineID!)
        #expect(state.configuration.machines.count == 2)
        state.forgetMachine(stranger.id)
        #expect(state.configuration.machines.map(\.id) == [state.currentMachineID])
        #expect(state.configuration.aliases.isEmpty)
    }

    @Test func availableScopesListGlobalProfilesThenThisMac() async {
        let (state, _) = await makeState()
        let b = state.saveProfile(name: "B")!
        let a = state.saveProfile(name: "A")!
        #expect(state.availableScopes == [.global, .profile(a), .profile(b), .machine(state.currentMachineID!)])
    }

    @Test func oldFilesWithoutProfilesStillDecode() throws {
        let json = #"{"schemaVersion":1,"environment":[]}"#
        let decoded = try JSONDecoder().decode(StoredConfiguration.self, from: Data(json.utf8))
        #expect(decoded.profiles.isEmpty && decoded.machines.isEmpty)
    }
}
