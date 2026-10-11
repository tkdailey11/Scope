import Foundation
import Testing
@testable import Scope

struct JSONConfigurationStoreTests {
    private let home = FileManager.default.temporaryDirectory
        .appending(path: "scope-store-\(UUID().uuidString)", directoryHint: .isDirectory)

    private var paths: ScopePaths { ScopePaths(home: home) }
    private var store: JSONConfigurationStore { JSONConfigurationStore(fileSystem: LocalFileSystem(), paths: paths) }
    private func cleanUp() { try? FileManager.default.removeItem(at: home) }

    @Test func missingFileLoadsEmpty() async throws {
        defer { cleanUp() }
        #expect(try await store.load() == StoredConfiguration())
    }

    @Test func roundTrips() async throws {
        defer { cleanUp() }
        var configuration = StoredConfiguration()
        configuration.environment = [
            .init(name: "A", value: "it's", valueMode: .expression, createdAt: Date(timeIntervalSince1970: 1000), modifiedAt: Date(timeIntervalSince1970: 2000)),
            .init(name: "T", secretReference: "kc:1", scope: .machine(UUID())),
        ]
        configuration.path = [.init(rawPath: "~/bin", order: 3)]
        try await store.save(configuration)
        #expect(try await store.load() == configuration)
    }

    @Test func outputIsStableAcrossSaves() async throws {
        defer { cleanUp() }
        var configuration = StoredConfiguration()
        configuration.environment = [.init(name: "A", value: "1", createdAt: Date(timeIntervalSince1970: 1), modifiedAt: Date(timeIntervalSince1970: 1))]
        try await store.save(configuration)
        let first = try Data(contentsOf: paths.configurationFile)
        try await store.save(configuration)
        #expect(try Data(contentsOf: paths.configurationFile) == first)
    }

    @Test func missingKeysDecodeToDefaults() async throws {
        defer { cleanUp() }
        try FileManager.default.createDirectory(at: paths.applicationSupportDirectory, withIntermediateDirectories: true)
        try Data(#"{"schemaVersion":1}"#.utf8).write(to: paths.configurationFile)
        #expect(try await store.load() == StoredConfiguration())
    }

    @Test func corruptFileIsPreservedAndLeftInPlace() async throws {
        defer { cleanUp() }
        try FileManager.default.createDirectory(at: paths.applicationSupportDirectory, withIntermediateDirectories: true)
        let garbage = Data("{ not json".utf8)
        try garbage.write(to: paths.configurationFile)

        do {
            _ = try await store.load()
            Issue.record("expected load to throw")
        } catch ConfigurationStoreError.unreadable(let preservedAt) {
            #expect(try Data(contentsOf: preservedAt) == garbage)
        }
        // The original is untouched; nothing was silently replaced with an empty config.
        #expect(try Data(contentsOf: paths.configurationFile) == garbage)
    }

    @Test func newerSchemaIsRefused() async throws {
        defer { cleanUp() }
        try FileManager.default.createDirectory(at: paths.applicationSupportDirectory, withIntermediateDirectories: true)
        try Data(#"{"schemaVersion":99}"#.utf8).write(to: paths.configurationFile)
        await #expect(throws: ConfigurationStoreError.newerSchema(99)) { try await store.load() }
    }
}

@MainActor
struct AppStateLoadFailureTests {
    @Test func unreadableConfigurationBlocksSavingAndWarns() async {
        struct FailingStore: ConfigurationStore {
            func load() async throws -> StoredConfiguration {
                throw ConfigurationStoreError.unreadable(preservedAt: URL(filePath: "/tmp/kept.json"))
            }
            func save(_ configuration: StoredConfiguration) async throws {
                Issue.record("save must not be called after a failed load")
            }
        }
        let state = AppState(store: FailingStore())
        await state.load()
        #expect(state.errorMessage?.contains("/tmp/kept.json") == true)

        var draft = EnvironmentVariableDraft()
        draft.name = "A"
        state.saveEnvironmentVariable(draft)
        await state.waitForPendingSaves()
    }
}
