//
//  JSONConfigurationStore.swift
//  Scope
//

import Foundation

nonisolated struct JSONConfigurationStore: ConfigurationStore {
    var fileSystem: any FileSystem
    var paths: ScopePaths
    var now: @Sendable () -> Date = { .now }

    func load() async throws -> StoredConfiguration {
        let file = paths.configurationFile
        guard fileSystem.fileExists(at: file) else { return StoredConfiguration() }

        let data = try fileSystem.read(file)
        let configuration: StoredConfiguration
        do {
            configuration = try JSONDecoder().decode(StoredConfiguration.self, from: data)
        } catch {
            throw ConfigurationStoreError.unreadable(preservedAt: try preserveUnreadable(data))
        }
        guard configuration.schemaVersion <= StoredConfiguration.currentSchemaVersion else {
            throw ConfigurationStoreError.newerSchema(configuration.schemaVersion)
        }
        return configuration
    }

    func save(_ configuration: StoredConfiguration) async throws {
        let encoder = JSONEncoder()
        // Sorted keys keep the file stable under version control or sync.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try fileSystem.writeAtomically(try encoder.encode(configuration), to: paths.configurationFile)
    }

    private func preserveUnreadable(_ data: Data) throws -> URL {
        let stamp = Int(now().timeIntervalSince1970)
        let url = paths.applicationSupportDirectory
            .appending(path: "configuration.unreadable-\(stamp).json", directoryHint: .notDirectory)
        try fileSystem.writeAtomically(data, to: url)
        return url
    }
}
