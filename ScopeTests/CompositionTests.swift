import Foundation
import Testing
@testable import Scope

struct CompositionTests {
    let profileID = UUID()
    let otherProfileID = UUID()
    let machineID = UUID()

    private func compose(_ snapshot: ConfigurationSnapshot) -> EffectiveConfiguration {
        ConfigurationComposer.compose(snapshot, activeProfileID: profileID, machineID: machineID)
    }

    @Test func laterScopesOverrideEnvironmentByName() {
        let snapshot = ConfigurationSnapshot(environment: [
            .init(name: "EDITOR", value: "vim", scope: .global),
            .init(name: "EDITOR", value: "nvim", scope: .profile(profileID)),
            .init(name: "EDITOR", value: "code", scope: .machine(machineID)),
        ])
        let env = compose(snapshot).environment
        #expect(env.count == 1)
        #expect(env[0].item.value == "code")
        #expect(env[0].overrideCount == 2)
    }

    @Test func inactiveProfileAndOtherMachinesAreIgnored() {
        let snapshot = ConfigurationSnapshot(aliases: [
            .init(name: "ll", command: "ls -l", scope: .global),
            .init(name: "ll", command: "ls -la", scope: .profile(otherProfileID)),
            .init(name: "ll", command: "ls -lh", scope: .machine(UUID())),
        ])
        #expect(compose(snapshot).aliases.map(\.item.command) == ["ls -l"])
    }

    @Test func disabledItemsAreExcludedAndDoNotOverride() {
        let snapshot = ConfigurationSnapshot(environment: [
            .init(name: "A", value: "global", scope: .global),
            .init(name: "A", value: "machine", scope: .machine(machineID), isEnabled: false),
        ])
        #expect(compose(snapshot).environment.first?.item.value == "global")
    }

    @Test func pathPutsMostSpecificScopeFirstThenOrder() {
        let snapshot = ConfigurationSnapshot(path: [
            .init(rawPath: "/g2", order: 1, scope: .global),
            .init(rawPath: "/g1", order: 0, scope: .global),
            .init(rawPath: "/p1", order: 0, scope: .profile(profileID)),
            .init(rawPath: "/m1", order: 0, scope: .machine(machineID)),
        ])
        #expect(compose(snapshot).path.map(\.rawPath) == ["/m1", "/p1", "/g1", "/g2"])
    }

    @Test func pathDeduplicatesKeepingHighestPriority() {
        let snapshot = ConfigurationSnapshot(path: [
            .init(rawPath: "/x", order: 0, scope: .global),
            .init(rawPath: "/x", order: 0, scope: .machine(machineID)),
        ])
        let path = compose(snapshot).path
        #expect(path.count == 1)
        #expect(path[0].scope == .machine(machineID))
    }

    @Test func invalidNamesAndSecretsProduceIssues() {
        let snapshot = ConfigurationSnapshot(
            environment: [
                .init(name: "1BAD", value: "x"),
                .init(name: "TOKEN", secretReference: "keychain:token"),
                .init(name: "EMPTY"),
            ],
            aliases: [.init(name: "bad name", command: "true")]
        )
        let result = compose(snapshot)
        #expect(result.hasErrors)
        #expect(result.issues.filter { $0.severity == .error }.count == 3)
        #expect(result.issues.filter { $0.severity == .warning }.count == 1)
    }
}
