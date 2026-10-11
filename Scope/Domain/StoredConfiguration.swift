//
//  StoredConfiguration.swift
//  Scope
//
//  Everything Scope persists. Decoding tolerates missing keys so newer
//  collections (profiles, machines) can be added without breaking old files.
//

import Foundation

nonisolated struct StoredConfiguration: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion = StoredConfiguration.currentSchemaVersion
    var environment: [EnvironmentVariable] = []
    var path: [PathEntry] = []
    var aliases: [ShellAlias] = []
    var functions: [ShellFunction] = []

    init() {}

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        environment = try container.decodeIfPresent([EnvironmentVariable].self, forKey: .environment) ?? []
        path = try container.decodeIfPresent([PathEntry].self, forKey: .path) ?? []
        aliases = try container.decodeIfPresent([ShellAlias].self, forKey: .aliases) ?? []
        functions = try container.decodeIfPresent([ShellFunction].self, forKey: .functions) ?? []
    }

    var snapshot: ConfigurationSnapshot {
        ConfigurationSnapshot(environment: environment, path: path, aliases: aliases, functions: functions)
    }
}
