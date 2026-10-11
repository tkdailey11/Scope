//
//  AliasDraft.swift
//  Scope
//
//  Editable form state for one alias, with validation kept out of the view.
//

import Foundation

struct AliasDraft: Equatable {
    var name = ""
    var command = ""
    var isEnabled = true

    init() {}

    init(_ alias: ShellAlias) {
        name = alias.name
        command = alias.command
        isEnabled = alias.isEnabled
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    /// - Parameter existingNames: other alias names already in the same scope.
    func nameIssue(existingNames: Set<String>) -> String? {
        if trimmedName.isEmpty { return String(localized: "Enter a name.") }
        if !ZshSyntax.isValidAliasName(trimmedName) {
            return String(localized: "Names may contain letters, digits and _ - . + : , and can't start with a dash.")
        }
        if existingNames.contains(trimmedName) {
            return String(localized: "An alias named \(trimmedName) already exists in this scope.")
        }
        return nil
    }

    func commandIssue() -> String? {
        if command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: "Enter a command.")
        }
        do {
            _ = try ZshQuoting.literal(command)
            return nil
        } catch {
            return String(localized: "The command contains a character that can't be written to a shell file.")
        }
    }

    func isValid(existingNames: Set<String>) -> Bool {
        nameIssue(existingNames: existingNames) == nil && commandIssue() == nil
    }

    /// The exact line that will appear in the generated file, if it can be produced.
    var generatedLine: String? {
        guard commandIssue() == nil, ZshSyntax.isValidAliasName(trimmedName) else { return nil }
        return try? ZshGenerator.aliasLine(for: ShellAlias(name: trimmedName, command: command))
    }
}
