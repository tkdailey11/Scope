//
//  SyncReconciler.swift
//  Scope
//
//  Pure three-way reconciliation: local items, what iCloud sent, and the digest of each
//  record at the last agreement. Meaningful concurrent edits become conflicts; nothing
//  is resolved by last-write-wins (Design/08).
//

import Foundation

nonisolated struct SyncOutcome: Equatable, Sendable {
    var upserts: [SyncItem] = []
    var deletions: Set<UUID> = []
}

nonisolated enum SyncReconciler {
    /// Folds remote changes into `state`, returning what to apply locally.
    static func reconcile(local: [SyncItem], incoming: [RemoteChange], state: inout SyncState) -> SyncOutcome {
        let localByID = Dictionary(local.filter(\.isPortable).map { ($0.id, $0) }, uniquingKeysWith: { $1 })
        var outcome = SyncOutcome()

        // Only the newest change per record matters.
        var latest: [UUID: RemoteChange] = [:]
        for change in incoming { latest[change.id] = change }

        for change in latest.values.sorted(by: { ($0.modifiedAt, $0.id.uuidString) < ($1.modifiedAt, $1.id.uuidString) }) {
            let key = change.id.uuidString
            if let existing = state.conflicts.firstIndex(where: { $0.id == change.id }) {
                state.conflicts[existing].remote = change
                continue
            }
            // Records this build can't read (a newer kind or schema) are left alone.
            if !change.isDeleted, change.item == nil { continue }

            let localItem = localByID[change.id]
            let remoteDigest = change.item?.digest
            // iCloud echoing back what we already agreed on (including our own pushes) is not news.
            if remoteDigest == state.base[key] { continue }
            let localDigest = localItem?.digest

            if localDigest == remoteDigest {
                state.base[key] = remoteDigest
                continue
            }
            let localChanged = localDigest != state.base[key]
            if localChanged {
                state.conflicts.append(PendingConflict(remote: change))
            } else if let item = change.item {
                outcome.upserts.append(item)
                state.base[key] = remoteDigest
            } else {
                outcome.deletions.insert(change.id)
                state.base[key] = nil
            }
        }
        return outcome
    }

    /// Local edits, additions and deletions iCloud hasn't seen. Records in conflict wait.
    static func outgoing(local: [SyncItem], state: SyncState, device: String, now: Date) -> [RemoteChange] {
        let conflicted = Set(state.conflicts.map(\.id))
        var changes: [RemoteChange] = []
        var present = Set<UUID>()
        for item in local where item.isPortable {
            present.insert(item.id)
            guard !conflicted.contains(item.id), item.digest != state.base[item.id.uuidString] else { continue }
            if let change = try? RemoteChange.upsert(item, by: device) { changes.append(change) }
        }
        for key in state.base.keys.sorted() {
            guard let id = UUID(uuidString: key), !present.contains(id), !conflicted.contains(id) else { continue }
            // The kind of a deleted record is unknown locally; CloudKit only needs the id.
            changes.append(.tombstone(id: id, kind: .environment, at: now, by: device))
        }
        return changes.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    /// Records that `pushed` is now what iCloud holds.
    static func markPushed(_ pushed: [RemoteChange], state: inout SyncState) {
        for change in pushed {
            state.base[change.id.uuidString] = change.item?.digest
        }
    }

    /// Settles one conflict. Keeping the remote version returns what to apply locally;
    /// keeping the local one leaves it to be pushed on the next sync.
    static func resolve(_ id: UUID, keepLocal: Bool, state: inout SyncState) -> SyncOutcome {
        guard let index = state.conflicts.firstIndex(where: { $0.id == id }) else { return SyncOutcome() }
        let remote = state.conflicts.remove(at: index).remote
        state.base[id.uuidString] = remote.item?.digest
        guard !keepLocal else { return SyncOutcome() }
        if let item = remote.item { return SyncOutcome(upserts: [item]) }
        return SyncOutcome(deletions: [id])
    }
}
