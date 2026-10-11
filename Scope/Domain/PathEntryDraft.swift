//
//  PathEntryDraft.swift
//  Scope
//
//  Editable form state for one PATH entry, with validation kept out of the view.
//

import Foundation

struct PathEntryDraft: Equatable {
    var rawPath = ""
    var isEnabled = true

    init() {}

    init(_ entry: PathEntry) {
        rawPath = entry.rawPath
        isEnabled = entry.isEnabled
    }

    var trimmedPath: String { rawPath.trimmingCharacters(in: .whitespaces) }

    /// - Parameter existingPaths: other entries' authored paths in the same scope.
    func pathIssue(existingPaths: Set<String>) -> String? {
        if trimmedPath.isEmpty { return String(localized: "Enter a directory.") }
        // A colon would silently become two PATH entries.
        if trimmedPath.contains(":") {
            return String(localized: "Enter one directory per entry. Colons separate PATH entries, so add each directory on its own.")
        }
        if existingPaths.contains(trimmedPath) {
            return String(localized: "This directory is already in this scope.")
        }
        do {
            _ = try ZshQuoting.pathComponent(trimmedPath)
        } catch ZshQuotingError.danglingBackslash {
            return String(localized: "A path can't end in a single backslash.")
        } catch {
            return String(localized: "The path contains a character that can't be written to a shell file.")
        }
        return nil
    }

    func isValid(existingPaths: Set<String>) -> Bool {
        pathIssue(existingPaths: existingPaths) == nil
    }

    /// The exact line that will appear in the generated file, if it can be produced.
    var generatedLine: String? {
        guard !trimmedPath.isEmpty, !trimmedPath.contains(":") else { return nil }
        return try? ZshGenerator.pathLine(for: trimmedPath)
    }
}
