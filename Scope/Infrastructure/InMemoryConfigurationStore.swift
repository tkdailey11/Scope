//
//  InMemoryConfigurationStore.swift
//  Scope
//
//  For previews and tests.
//

import Foundation

actor InMemoryConfigurationStore: ConfigurationStore {
    private(set) var stored: StoredConfiguration
    private(set) var saveCount = 0
    var failSaves = false

    init(_ initial: StoredConfiguration = StoredConfiguration()) {
        stored = initial
    }

    func load() async throws -> StoredConfiguration { stored }

    func save(_ configuration: StoredConfiguration) async throws {
        if failSaves { throw CocoaError(.fileWriteUnknown) }
        stored = configuration
        saveCount += 1
    }

    func setFailSaves(_ value: Bool) { failSaves = value }
}
