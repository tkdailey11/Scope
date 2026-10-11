//
//  SyncStateStore.swift
//  Scope
//

import Foundation

nonisolated protocol SyncStateStore: Sendable {
    func load() async -> SyncState
    func save(_ state: SyncState) async throws
}

nonisolated struct JSONSyncStateStore: SyncStateStore {
    var fileSystem: any FileSystem
    var paths: ScopePaths

    func load() async -> SyncState {
        guard let data = try? fileSystem.read(paths.syncStateFile),
              let state = try? JSONDecoder().decode(SyncState.self, from: data) else { return SyncState() }
        return state
    }

    func save(_ state: SyncState) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try fileSystem.writeAtomically(try encoder.encode(state), to: paths.syncStateFile)
    }
}

actor InMemorySyncStateStore: SyncStateStore {
    private(set) var state: SyncState
    init(_ state: SyncState = SyncState()) { self.state = state }
    func load() async -> SyncState { state }
    func save(_ state: SyncState) async throws { self.state = state }
}
