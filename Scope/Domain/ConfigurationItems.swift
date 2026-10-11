//
//  ConfigurationItems.swift
//  Scope
//
//  Pure domain types. See Design/07_Data_Model.md.
//

import Foundation

nonisolated enum ConfigurationScope: Codable, Hashable, Sendable {
    case global
    case profile(UUID)
    case machine(UUID)

    /// Composition precedence: higher rank overrides lower rank.
    var rank: Int {
        switch self {
        case .global: 0
        case .profile: 1
        case .machine: 2
        }
    }
}

/// How an environment variable's value is interpreted when generating shell code.
nonisolated enum ValueMode: String, Codable, Hashable, Sendable {
    /// Emitted verbatim as a single-quoted string; nothing expands.
    case literal
    /// Emitted in double quotes so `$HOME`, `$(cmd)` etc. expand at shell startup.
    case expression
}

nonisolated struct EnvironmentVariable: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var value: String?
    var valueMode: ValueMode
    var secretReference: String?
    var scope: ConfigurationScope
    var isEnabled: Bool
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        value: String? = nil,
        valueMode: ValueMode = .literal,
        secretReference: String? = nil,
        scope: ConfigurationScope = .global,
        isEnabled: Bool = true,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.valueMode = valueMode
        self.secretReference = secretReference
        self.scope = scope
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

nonisolated struct PathEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    /// The user's authored form, e.g. `~/go/bin` or `$HOME/bin`.
    var rawPath: String
    var order: Int
    var scope: ConfigurationScope
    var isEnabled: Bool
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        rawPath: String,
        order: Int = 0,
        scope: ConfigurationScope = .global,
        isEnabled: Bool = true,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.rawPath = rawPath
        self.order = order
        self.scope = scope
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

nonisolated struct ShellAlias: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var command: String
    var scope: ConfigurationScope
    var isEnabled: Bool
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        scope: ConfigurationScope = .global,
        isEnabled: Bool = true,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.scope = scope
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

nonisolated struct ShellFunction: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var body: String
    var scope: ConfigurationScope
    var isEnabled: Bool
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        body: String,
        scope: ConfigurationScope = .global,
        isEnabled: Bool = true,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.body = body
        self.scope = scope
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

nonisolated struct Profile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var iconName: String?
    var isActive: Bool
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String? = nil,
        isActive: Bool = false,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.isActive = isActive
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

nonisolated struct Machine: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    /// Stable across Mac renames (not the computer name).
    var stableDeviceIdentifier: String
    var lastSeenAt: Date

    init(
        id: UUID = UUID(),
        displayName: String,
        stableDeviceIdentifier: String,
        lastSeenAt: Date = .now
    ) {
        self.id = id
        self.displayName = displayName
        self.stableDeviceIdentifier = stableDeviceIdentifier
        self.lastSeenAt = lastSeenAt
    }
}
