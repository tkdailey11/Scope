//
//  SyncItem.swift
//  Scope
//
//  One portable configuration record. Machine-scoped items never become a SyncItem,
//  and per-Mac state (which profile is active) and secret values are stripped.
//

import CryptoKit
import Foundation

nonisolated enum SyncKind: String, Codable, CaseIterable, Sendable {
    case environment, path, alias, function, profile
}

nonisolated enum SyncItem: Hashable, Sendable {
    case environment(EnvironmentVariable)
    case path(PathEntry)
    case alias(ShellAlias)
    case function(ShellFunction)
    case profile(Profile)

    var id: UUID {
        switch self {
        case .environment(let item): item.id
        case .path(let item): item.id
        case .alias(let item): item.id
        case .function(let item): item.id
        case .profile(let item): item.id
        }
    }

    var kind: SyncKind {
        switch self {
        case .environment: .environment
        case .path: .path
        case .alias: .alias
        case .function: .function
        case .profile: .profile
        }
    }

    var modifiedAt: Date {
        switch self {
        case .environment(let item): item.modifiedAt
        case .path(let item): item.modifiedAt
        case .alias(let item): item.modifiedAt
        case .function(let item): item.modifiedAt
        case .profile(let item): item.modifiedAt
        }
    }

    /// Whether this item may leave the Mac. Machine-only configuration stays local.
    var isPortable: Bool {
        let scope: ConfigurationScope? = switch self {
        case .environment(let item): item.scope
        case .path(let item): item.scope
        case .alias(let item): item.scope
        case .function(let item): item.scope
        case .profile: nil
        }
        if case .machine? = scope { return false }
        return true
    }

    /// The record as it is shared: no activation state, no secret values.
    var portable: SyncItem {
        switch self {
        case .environment(var item):
            if item.secretReference != nil { item.value = nil }
            return .environment(item)
        case .profile(var item):
            item.isActive = false
            return .profile(item)
        default:
            return self
        }
    }

    /// Hash of the shareable content, ignoring timestamps, so identical edits on two Macs don't conflict.
    var digest: String {
        var item = portable
        let epoch = Date(timeIntervalSinceReferenceDate: 0)
        switch item {
        case .environment(var v): v.createdAt = epoch; v.modifiedAt = epoch; item = .environment(v)
        case .path(var v): v.createdAt = epoch; v.modifiedAt = epoch; item = .path(v)
        case .alias(var v): v.createdAt = epoch; v.modifiedAt = epoch; item = .alias(v)
        case .function(var v): v.createdAt = epoch; v.modifiedAt = epoch; item = .function(v)
        case .profile(var v): v.createdAt = epoch; v.modifiedAt = epoch; item = .profile(v)
        }
        guard let data = try? Self.encoder.encode(item.payloadValue) else { return "" }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private var payloadValue: any Encodable {
        switch self {
        case .environment(let item): item
        case .path(let item): item
        case .alias(let item): item
        case .function(let item): item
        case .profile(let item): item
        }
    }

    // MARK: - Payload

    func encodedPayload() throws -> Data {
        try Self.encoder.encode(portable.payloadValue)
    }

    static func decode(kind: SyncKind, payload: Data) -> SyncItem? {
        let decoder = JSONDecoder()
        switch kind {
        case .environment: return (try? decoder.decode(EnvironmentVariable.self, from: payload)).map(SyncItem.environment)
        case .path: return (try? decoder.decode(PathEntry.self, from: payload)).map(SyncItem.path)
        case .alias: return (try? decoder.decode(ShellAlias.self, from: payload)).map(SyncItem.alias)
        case .function: return (try? decoder.decode(ShellFunction.self, from: payload)).map(SyncItem.function)
        case .profile: return (try? decoder.decode(Profile.self, from: payload)).map(SyncItem.profile)
        }
    }

    // MARK: - Display

    var title: String {
        switch self {
        case .environment(let item): item.name
        case .path(let item): item.rawPath
        case .alias(let item): item.name
        case .function(let item): item.name
        case .profile(let item): item.name
        }
    }

    /// What the record holds, for comparing two versions in conflict resolution.
    /// Secret-backed values are never shown.
    var summary: String {
        switch self {
        case .environment(let item):
            item.secretReference != nil ? String(localized: "Stored in Keychain") : (item.value ?? "")
        case .path(let item): item.isEnabled ? item.rawPath : String(localized: "\(item.rawPath) (disabled)")
        case .alias(let item): item.command
        case .function(let item): item.body
        case .profile(let item): item.name
        }
    }
}
