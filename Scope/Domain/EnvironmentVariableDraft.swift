//
//  EnvironmentVariableDraft.swift
//  Scope
//
//  Editable form state for one variable, with validation kept out of the view.
//

import Foundation

struct EnvironmentVariableDraft: Equatable {
    var name = ""
    var value = ""
    var valueMode: ValueMode = .literal
    var isEnabled = true

    init() {}

    init(_ variable: EnvironmentVariable) {
        name = variable.name
        value = variable.value ?? ""
        valueMode = variable.valueMode
        isEnabled = variable.isEnabled
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    /// - Parameter existingNames: other variable names already in the same scope.
    func nameIssue(existingNames: Set<String>) -> String? {
        if trimmedName.isEmpty { return String(localized: "Enter a name.") }
        if !ZshSyntax.isValidVariableName(trimmedName) {
            return String(localized: "Names may contain letters, digits and underscores, and can't start with a digit.")
        }
        if existingNames.contains(trimmedName) {
            return String(localized: "A variable named \(trimmedName) already exists in this scope.")
        }
        return nil
    }

    /// Catches values that can't be written safely, before they reach the generator.
    func valueIssue() -> String? {
        do {
            _ = switch valueMode {
            case .literal: try ZshQuoting.literal(value)
            case .expression: try ZshQuoting.expression(value)
            }
            return nil
        } catch ZshQuotingError.danglingBackslash {
            return String(localized: "An expression can't end in a single backslash. Remove it or double it.")
        } catch {
            return String(localized: "The value contains a character that can't be written to a shell file.")
        }
    }

    func isValid(existingNames: Set<String>) -> Bool {
        nameIssue(existingNames: existingNames) == nil && valueIssue() == nil
    }

    /// The exact line that will appear in the generated file, if it can be produced.
    var generatedLine: String? {
        guard valueIssue() == nil, ZshSyntax.isValidVariableName(trimmedName) else { return nil }
        let variable = EnvironmentVariable(name: trimmedName, value: value, valueMode: valueMode)
        return try? ZshGenerator.exportLine(for: variable)
    }
}
