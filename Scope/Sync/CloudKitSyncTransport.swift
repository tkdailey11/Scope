//
//  CloudKitSyncTransport.swift
//  Scope
//
//  Records live in a private custom zone. Payloads use CloudKit encrypted fields,
//  so function bodies and values are end-to-end encrypted. Needs the iCloud/CloudKit
//  entitlement; without it `accountStatus()` reports `.notConfigured` and CloudKit is never touched.
//

import CloudKit
import Foundation
import OSLog
import Security

nonisolated struct CloudKitSyncTransport: SyncTransport {
    static let containerIdentifier = "iCloud.com.tylerdailey.Scope"
    private static let recordType = "ConfigItem"
    private static let logger = Logger(subsystem: "com.scope.Scope", category: "CloudKitSync")
    private let zoneID = CKRecordZone.ID(zoneName: "ScopeConfiguration")

    /// CKContainer traps if the entitlement is missing, so check the signature first.
    static var hasEntitlement: Bool {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-services" as CFString, nil) as? [String]
        else { return false }
        return value.contains("CloudKit")
    }

    private var container: CKContainer { CKContainer(identifier: Self.containerIdentifier) }
    private var database: CKDatabase { container.privateCloudDatabase }

    func accountStatus() async -> SyncAccountStatus {
        guard Self.hasEntitlement else { return .notConfigured }
        do {
            switch try await container.accountStatus() {
            case .available: return .available
            case .noAccount: return .noAccount
            case .restricted: return .restricted
            default: return .temporarilyUnavailable
            }
        } catch {
            Self.logger.error("Account status failed: \(error.localizedDescription, privacy: .public)")
            return .temporarilyUnavailable
        }
    }

    func fetchChanges(since token: Data?) async throws -> (changes: [RemoteChange], token: Data?) {
        _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
        do {
            return try await fetch(since: token)
        } catch let error as CKError where error.code == .changeTokenExpired {
            return try await fetch(since: nil)
        }
    }

    private func fetch(since tokenData: Data?) async throws -> (changes: [RemoteChange], token: Data?) {
        var token = try tokenData.flatMap { try NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: $0) }
        var changes: [RemoteChange] = []
        var moreComing = true
        while moreComing {
            let result = try await database.recordZoneChanges(inZoneWith: zoneID, since: token)
            for (_, modification) in result.modificationResultsByID {
                if let change = Self.change(from: try modification.get().record) { changes.append(change) }
            }
            for deletion in result.deletions {
                if let id = UUID(uuidString: deletion.recordID.recordName) {
                    changes.append(.tombstone(id: id, kind: .environment, at: .now, by: ""))
                }
            }
            token = result.changeToken
            moreComing = result.moreComing
        }
        let data = try token.map { try NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) }
        return (changes, data)
    }

    func push(_ changes: [RemoteChange]) async throws {
        for batch in stride(from: 0, to: changes.count, by: 200).map({ Array(changes[$0..<min($0 + 200, changes.count)]) }) {
            // Changed-keys policy: the reconciler has just merged what the server holds.
            let (saveResults, _) = try await database.modifyRecords(
                saving: batch.map(record(for:)), deleting: [], savePolicy: .changedKeys
            )
            for (_, result) in saveResults { _ = try result.get() }
        }
    }

    private func record(for change: RemoteChange) -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: CKRecord.ID(recordName: change.id.uuidString, zoneID: zoneID))
        record["kind"] = change.kind.rawValue
        record["modifiedAt"] = change.modifiedAt
        record["modifiedBy"] = change.modifiedBy
        record["isDeleted"] = change.isDeleted ? 1 : 0
        record.encryptedValues["payload"] = change.payload ?? Data()
        return record
    }

    private static func change(from record: CKRecord) -> RemoteChange? {
        guard let id = UUID(uuidString: record.recordID.recordName),
              let kindName = record["kind"] as? String, let kind = SyncKind(rawValue: kindName)
        else { return nil }
        let isDeleted = (record["isDeleted"] as? Int64 ?? 0) != 0
        let payload = record.encryptedValues["payload"] as? Data
        return RemoteChange(
            id: id, kind: kind, payload: isDeleted ? nil : payload,
            modifiedAt: record["modifiedAt"] as? Date ?? .now,
            modifiedBy: record["modifiedBy"] as? String ?? "",
            isDeleted: isDeleted
        )
    }
}
