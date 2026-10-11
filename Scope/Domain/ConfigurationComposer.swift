//
//  ConfigurationComposer.swift
//  Scope
//
//  Pure, synchronous scope composition: Global -> active Profile -> Machine.
//

import Foundation

nonisolated enum ConfigurationComposer {
    /// - Parameters:
    ///   - activeProfileID: the single active profile (MVP), if any.
    ///   - machineID: the current machine, if registered.
    static func compose(
        _ snapshot: ConfigurationSnapshot,
        activeProfileID: UUID?,
        machineID: UUID?
    ) -> EffectiveConfiguration {
        let applies: (ConfigurationScope) -> Bool = { scope in
            switch scope {
            case .global: true
            case .profile(let id): id == activeProfileID
            case .machine(let id): id == machineID
            }
        }

        var result = EffectiveConfiguration()

        result.environment = resolveByName(
            snapshot.environment.filter { $0.isEnabled && applies($0.scope) },
            name: \.name, scope: \.scope, created: \.createdAt
        )
        result.aliases = resolveByName(
            snapshot.aliases.filter { $0.isEnabled && applies($0.scope) },
            name: \.name, scope: \.scope, created: \.createdAt
        )
        result.functions = resolveByName(
            snapshot.functions.filter { $0.isEnabled && applies($0.scope) },
            name: \.name, scope: \.scope, created: \.createdAt
        )
        result.path = composePath(snapshot.path.filter { $0.isEnabled && applies($0.scope) })

        result.issues = validate(result)
        return result
    }

    // MARK: - Name-based override

    /// Later scopes override earlier ones. Within one scope, the most recently
    /// created item wins so output stays deterministic. Results are sorted by name.
    private static func resolveByName<Item: Hashable & Sendable>(
        _ items: [Item],
        name: KeyPath<Item, String>,
        scope: KeyPath<Item, ConfigurationScope>,
        created: KeyPath<Item, Date>
    ) -> [Resolved<Item>] {
        Dictionary(grouping: items, by: { $0[keyPath: name] })
            .map { _, group in
                let ordered = group.sorted {
                    let (a, b) = ($0[keyPath: scope].rank, $1[keyPath: scope].rank)
                    return a != b ? a < b : $0[keyPath: created] < $1[keyPath: created]
                }
                return Resolved(item: ordered.last!, overrideCount: ordered.count - 1)
            }
            .sorted { $0.item[keyPath: name] < $1.item[keyPath: name] }
    }

    // MARK: - PATH

    /// Most specific scope first (Machine, Profile, Global); `order` within a scope.
    /// Duplicate raw paths keep only their highest-priority occurrence.
    private static func composePath(_ entries: [PathEntry]) -> [PathEntry] {
        let sorted = entries.sorted {
            let (a, b) = ($0.scope.rank, $1.scope.rank)
            if a != b { return a > b }
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.createdAt < $1.createdAt
        }
        var seen = Set<String>()
        return sorted.filter { seen.insert($0.rawPath).inserted }
    }

    // MARK: - Validation

    private static func validate(_ config: EffectiveConfiguration) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        for resolved in config.environment {
            let variable = resolved.item
            if !ZshSyntax.isValidVariableName(variable.name) {
                issues.append(.init(severity: .error, message: "Invalid variable name “\(variable.name)”.", itemID: variable.id))
            }
            if variable.secretReference != nil {
                issues.append(.init(severity: .warning, message: "\(variable.name) is secret-backed and is not yet written to the generated file.", itemID: variable.id))
            } else if variable.value == nil {
                issues.append(.init(severity: .error, message: "\(variable.name) has no value.", itemID: variable.id))
            }
        }
        for resolved in config.aliases where !ZshSyntax.isValidAliasName(resolved.item.name) {
            issues.append(.init(severity: .error, message: "Invalid alias name “\(resolved.item.name)”.", itemID: resolved.item.id))
        }
        for resolved in config.functions where !ZshSyntax.isValidFunctionName(resolved.item.name) {
            issues.append(.init(severity: .error, message: "Invalid function name “\(resolved.item.name)”.", itemID: resolved.item.id))
        }
        for entry in config.path where entry.rawPath.trimmingCharacters(in: .whitespaces).isEmpty {
            issues.append(.init(severity: .error, message: "PATH entry is empty.", itemID: entry.id))
        }
        return issues
    }
}
