//
//  ConfigurationStore.swift
//  Scope
//
//  Persistence behind a protocol so storage (JSON now, possibly SwiftData/CloudKit
//  later) can change without touching app state or views.
//

import Foundation

nonisolated enum ConfigurationStoreError: Error, Equatable {
    /// The file existed but could not be decoded. It has been copied, untouched, to `preservedAt`
    /// and will not be overwritten by Scope until the user resolves it.
    case unreadable(preservedAt: URL)
    /// The file was written by a newer version of Scope.
    case newerSchema(Int)
}

nonisolated protocol ConfigurationStore: Sendable {
    /// Returns an empty configuration if nothing has been saved yet.
    func load() async throws -> StoredConfiguration
    func save(_ configuration: StoredConfiguration) async throws
}
