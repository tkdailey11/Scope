//
//  SyncState.swift
//  Scope
//
//  Per-Mac sync bookkeeping. Stored locally, never synced.
//

import Foundation

/// A change as it exists in iCloud. `payload` is nil for deletions.
nonisolated struct RemoteChange: Hashable, Codable, Sendable {
    var id: UUID
    var kind: SyncKind
    var payload: Data?
    var modifiedAt: Date
    var modifiedBy: String
    var isDeleted: Bool

    static func upsert(_ item: SyncItem, by device: String) throws -> RemoteChange {
        RemoteChange(id: item.id, kind: item.kind, payload: try item.encodedPayload(), modifiedAt: item.modifiedAt, modifiedBy: device, isDeleted: false)
    }

    static func tombstone(id: UUID, kind: SyncKind, at date: Date, by device: String) -> RemoteChange {
        RemoteChange(id: id, kind: kind, payload: nil, modifiedAt: date, modifiedBy: device, isDeleted: true)
    }

    var item: SyncItem? {
        guard !isDeleted, let payload else { return nil }
        return SyncItem.decode(kind: kind, payload: payload)
    }
}

/// Edited on this Mac and elsewhere since the last sync. Waits for the user to choose.
nonisolated struct PendingConflict: Identifiable, Hashable, Codable, Sendable {
    var remote: RemoteChange
    var id: UUID { remote.id }
}

nonisolated struct SyncState: Codable, Equatable, Sendable {
    var isEnabled = false
    /// CloudKit change token, opaque.
    var changeToken: Data?
    /// Content digest of each record as of the last time this Mac and iCloud agreed, keyed by UUID string.
    var base: [String: String] = [:]
    var conflicts: [PendingConflict] = []
    var lastSyncedAt: Date?

    init() {}

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        changeToken = try container.decodeIfPresent(Data.self, forKey: .changeToken)
        base = try container.decodeIfPresent([String: String].self, forKey: .base) ?? [:]
        conflicts = try container.decodeIfPresent([PendingConflict].self, forKey: .conflicts) ?? []
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
    }
}
