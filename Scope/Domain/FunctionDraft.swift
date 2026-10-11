//
//  FunctionDraft.swift
//  Scope
//
//  Editable form state for one shell function, with validation kept out of the view.
//

import Foundation

struct FunctionDraft: Equatable {
    var name = ""
    var body = ""
    var isEnabled = true

    init() {}

    init(_ function: ShellFunction) {
        name = function.name
        body = function.body
        isEnabled = function.isEnabled
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    /// - Parameter existingNames: other function names already in the same scope.
    func nameIssue(existingNames: Set<String>) -> String? {
        if trimmedName.isEmpty { return String(localized: "Enter a name.") }
        if !ZshSyntax.isValidFunctionName(trimmedName) {
            return String(localized: "Names may contain letters, digits and _ - . :, and must start with a letter or underscore.")
        }
        if existingNames.contains(trimmedName) {
            return String(localized: "A function named \(trimmedName) already exists in this scope.")
        }
        return nil
    }

    /// Non-blocking: zsh can't define a function whose name is already an alias.
    func nameWarning(aliasNames: Set<String>) -> String? {
        aliasNames.contains(trimmedName)
            ? String(localized: "An enabled alias is also named \(trimmedName). zsh will fail to define this function while the alias exists.")
            : nil
    }

    func bodyIssue() -> String? {
        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: "Enter the function body.")
        }
        if body.contains("\0") {
            return String(localized: "The body contains a character that can't be written to a shell file.")
        }
        return nil
    }

    func isValid(existingNames: Set<String>) -> Bool {
        nameIssue(existingNames: existingNames) == nil && bodyIssue() == nil
    }

    /// The exact definition that will appear in the generated file, if it can be produced.
    var generatedText: String? {
        guard bodyIssue() == nil, ZshSyntax.isValidFunctionName(trimmedName) else { return nil }
        return ZshGenerator.functionText(for: ShellFunction(name: trimmedName, body: body))
    }

    /// Maps a line in `generatedText` back to a 1-based line of the body as typed.
    /// Nil for the `name() {` and closing `}` lines, which the user didn't write.
    func bodyLine(forGeneratedLine line: Int) -> Int? {
        guard let text = generatedText else { return nil }
        let generatedLineCount = text.split(separator: "\n", omittingEmptySubsequences: false).count
        guard line >= 2, line <= generatedLineCount - 1 else { return nil }
        let droppedLeadingNewlines = body.prefix { $0 == "\n" || $0 == "\r\n" }.count
        return line - 1 + droppedLeadingNewlines
    }
}
