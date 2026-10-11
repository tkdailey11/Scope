//
//  EffectiveConfiguration.swift
//  Scope
//
//  The computed result of composing Global -> Profile -> Machine.
//  Never persisted; always derived from a ConfigurationSnapshot.
//

import Foundation

nonisolated struct ValidationIssue: Hashable, Sendable {
    enum Severity: String, Sendable {
        case warning
        case error
    }

    var severity: Severity
    var message: String
    /// The managed item this issue relates to, if any.
    var itemID: UUID?
}

/// A winning item plus the scope it came from.
nonisolated struct Resolved<Item: Hashable & Sendable>: Hashable, Sendable {
    var item: Item
    /// Number of lower-precedence items with the same name that this one overrides.
    var overrideCount: Int
}

nonisolated struct EffectiveConfiguration: Sendable {
    var environment: [Resolved<EnvironmentVariable>] = []
    /// Highest-priority entry first (i.e. the order they appear in `$PATH`).
    var path: [PathEntry] = []
    var aliases: [Resolved<ShellAlias>] = []
    var functions: [Resolved<ShellFunction>] = []
    var issues: [ValidationIssue] = []

    var hasErrors: Bool { issues.contains { $0.severity == .error } }
}

/// Everything loaded from persistence that composition needs.
nonisolated struct ConfigurationSnapshot: Sendable {
    var environment: [EnvironmentVariable] = []
    var path: [PathEntry] = []
    var aliases: [ShellAlias] = []
    var functions: [ShellFunction] = []
}
