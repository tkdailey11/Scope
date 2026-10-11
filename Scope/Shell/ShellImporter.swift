//
//  ShellImporter.swift
//  Scope
//
//  Conservative zsh import (Design/09, "Import parser"). Recognizes only simple,
//  high-confidence top-level statements. Everything else is reported as detected
//  text and left alone. Never modifies the source files.
//

import Foundation

nonisolated enum ImportedItem: Hashable, Sendable {
    case environment(name: String, value: String, mode: ValueMode)
    case path(String)
    case alias(name: String, command: String)
    case function(name: String, body: String)
}

nonisolated struct ImportCandidate: Identifiable, Hashable, Sendable {
    let id = UUID()
    var item: ImportedItem
    /// File name, e.g. `.zshrc`.
    var file: String
    /// 1-based line where the statement starts.
    var line: Int
    /// Position within one statement that yields several items (the entries of one PATH line).
    var ordinal = 0
    /// Position of the file in load order; later files override earlier ones.
    var fileOrder = 0
}

/// A line (or the first line of a multi-line statement) that was not imported, and why.
nonisolated struct DetectedLine: Identifiable, Hashable, Sendable {
    let id = UUID()
    var file: String
    var line: Int
    var text: String
    var reason: String
}

nonisolated struct ImportParseResult: Sendable {
    var candidates: [ImportCandidate] = []
    var detected: [DetectedLine] = []
}

nonisolated enum ShellImporter {
    static func parse(_ text: String, file: String, fileOrder: Int = 0) -> ImportParseResult {
        let lines = text.components(separatedBy: "\n").map { $0.hasSuffix("\r") ? String($0.dropLast()) : $0 }
        var result = ImportParseResult()
        var depth = 0
        var isInsideScopeBlock = false
        var index = 0

        func detect(_ start: Int, _ reason: String) {
            let first = lines[start].trimmingCharacters(in: .whitespaces)
            result.detected.append(DetectedLine(file: file, line: start + 1, text: first, reason: reason))
        }

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)

            // Scope's own hook block is not user configuration.
            if isInsideScopeBlock {
                if line == StartupHook.endMarker { isInsideScopeBlock = false }
                index += 1
                continue
            }
            if line == StartupHook.beginMarker {
                isInsideScopeBlock = true
                index += 1
                continue
            }
            if line.isEmpty || line.hasPrefix("#") {
                index += 1
                continue
            }

            let start = index
            if depth == 0, let opener = functionOpener(line) {
                if let close = lines[(start + 1)...].firstIndex(of: "}") {
                    let body = lines[(start + 1)..<close].joined(separator: "\n")
                    if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || body.contains("\0") {
                        detect(start, String(localized: "Empty function body."))
                    } else {
                        result.candidates.append(ImportCandidate(
                            item: .function(name: opener, body: body), file: file, line: start + 1, fileOrder: fileOrder
                        ))
                    }
                    index = close + 1
                } else {
                    detect(start, String(localized: "Couldn't find the end of this function (a line containing only “}”)."))
                    index = lines.count
                }
                continue
            }

            let end = statementEnd(lines, from: start)
            index = end + 1
            let spansLines = end > start

            if depth > 0 {
                detect(start, String(localized: "Inside a conditional or block, so it may not always apply."))
            } else if spansLines {
                detect(start, String(localized: "Spans multiple lines."))
            } else if line.hasPrefix("export ") {
                parseExport(String(line.dropFirst(7)), file: file, line: start + 1, fileOrder: fileOrder, into: &result, original: line)
            } else if line.hasPrefix("alias ") {
                parseAlias(String(line.dropFirst(6)), file: file, line: start + 1, fileOrder: fileOrder, into: &result, original: line)
            } else {
                detect(start, String(localized: "Not a pattern Scope imports automatically."))
            }

            depth = max(0, depth + depthChange(for: (start...end).map { lines[$0] }))
        }
        return result
    }

    // MARK: - Statements

    private static func parseExport(
        _ rest: String, file: String, line: Int, fileOrder: Int,
        into result: inout ImportParseResult, original: String
    ) {
        func detect(_ reason: String) {
            result.detected.append(DetectedLine(file: file, line: line, text: original, reason: reason))
        }
        guard let equals = rest.firstIndex(of: "=") else {
            return detect(String(localized: "Exports an existing variable without a value."))
        }
        let name = String(rest[..<equals])
        guard ZshSyntax.isValidVariableName(name) else {
            return detect(String(localized: "Not a simple NAME=value export."))
        }
        let valueText = String(rest[rest.index(after: equals)...])

        if name == "PATH" {
            parsePath(valueText, file: file, line: line, fileOrder: fileOrder, into: &result, original: original)
            return
        }
        guard let value = parseValue(valueText, expandTilde: true) else {
            return detect(String(localized: "The value uses shell syntax Scope doesn't import automatically."))
        }
        if isSecretName(name), value.mode == .literal, !value.text.isEmpty {
            return detect(String(localized: "Looks like a secret. Scope won't import plaintext secrets; add it manually and store the value in Keychain."))
        }
        result.candidates.append(ImportCandidate(
            item: .environment(name: name, value: value.text, mode: value.mode),
            file: file, line: line, fileOrder: fileOrder
        ))
    }

    private static func parsePath(
        _ valueText: String, file: String, line: Int, fileOrder: Int,
        into result: inout ImportParseResult, original: String
    ) {
        func detect(_ reason: String) {
            result.detected.append(DetectedLine(file: file, line: line, text: original, reason: reason))
        }
        guard let value = parseValue(valueText, expandTilde: false) else {
            return detect(String(localized: "The value uses shell syntax Scope doesn't import automatically."))
        }
        var components = value.text.components(separatedBy: ":")
        guard let last = components.popLast(), last == "$PATH" || last == "${PATH}" else {
            return detect(String(localized: "Only “directories:$PATH” (prepending to PATH) is imported. Scope always prepends."))
        }
        let unsafe = components.contains { component in
            component.isEmpty
                || component.contains("PATH")
                || component.contains("`") || component.contains("$(") || component.contains("\\")
                || (value.wasQuoted && component.hasPrefix("~"))
        }
        guard !components.isEmpty, !unsafe else {
            return detect(String(localized: "This PATH line has entries Scope can't import safely."))
        }
        for (ordinal, component) in components.enumerated() {
            result.candidates.append(ImportCandidate(
                item: .path(component), file: file, line: line, ordinal: ordinal, fileOrder: fileOrder
            ))
        }
    }

    private static func parseAlias(
        _ rest: String, file: String, line: Int, fileOrder: Int,
        into result: inout ImportParseResult, original: String
    ) {
        func detect(_ reason: String) {
            result.detected.append(DetectedLine(file: file, line: line, text: original, reason: reason))
        }
        guard let equals = rest.firstIndex(of: "="), ZshSyntax.isValidAliasName(String(rest[..<equals])) else {
            return detect(String(localized: "Not a simple alias name='command' definition."))
        }
        let name = String(rest[..<equals])
        // Aliases expand at use, not definition: a value that expands when defined would change meaning.
        guard let value = parseValue(String(rest[rest.index(after: equals)...]), expandTilde: false),
              value.mode == .literal,
              value.wasQuoted || !value.text.contains("~"),
              !value.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return detect(String(localized: "The alias uses shell syntax Scope doesn't import automatically."))
        }
        result.candidates.append(ImportCandidate(
            item: .alias(name: name, command: value.text), file: file, line: line, fileOrder: fileOrder
        ))
    }

    // MARK: - Values

    struct ParsedValue {
        var text: String
        var mode: ValueMode
        var wasQuoted: Bool
    }

    /// A single quoted or unquoted word, optionally followed by a comment. Nil for anything else.
    static func parseValue(_ source: String, expandTilde: Bool) -> ParsedValue? {
        let chars = Array(source)
        guard let first = chars.first else { return ParsedValue(text: "", mode: .literal, wasQuoted: false) }

        func onlyCommentRemains(after end: Int) -> Bool {
            let remainder = String(chars[end...])
            if remainder.isEmpty { return true }
            guard remainder.first?.isWhitespace == true else { return false }
            let trimmed = remainder.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty || trimmed.hasPrefix("#")
        }

        if first == "'" {
            guard let close = chars.dropFirst().firstIndex(of: "'"), onlyCommentRemains(after: close + 1) else { return nil }
            let text = String(chars[1..<close])
            return text.contains("\0") ? nil : ParsedValue(text: text, mode: .literal, wasQuoted: true)
        }

        if first == "\"" {
            var cursor = 1
            while cursor < chars.count, chars[cursor] != "\"" {
                cursor += chars[cursor] == "\\" ? 2 : 1
            }
            guard cursor < chars.count, onlyCommentRemains(after: cursor + 1) else { return nil }
            let text = String(chars[1..<cursor])
            guard !text.contains("\0") else { return nil }
            let expands = text.contains { $0 == "$" || $0 == "`" || $0 == "\\" }
            return ParsedValue(text: text, mode: expands ? .expression : .literal, wasQuoted: true)
        }

        // Unquoted: one word, no operators, globs or substitutions.
        let wordEnd = chars.firstIndex { $0.isWhitespace } ?? chars.count
        guard onlyCommentRemains(after: wordEnd) else { return nil }
        var word = String(chars[..<wordEnd])
        guard !word.contains(where: { ";&|<>()`'\"\\*?[]!#".contains($0) }) else { return nil }
        for (offset, char) in word.enumerated() where char == "{" || char == "}" {
            guard char == "}" || (offset > 0 && Array(word)[offset - 1] == "$") else { return nil }
        }
        if let tilde = word.firstIndex(of: "~") {
            guard tilde == word.startIndex else { return nil }
            if expandTilde {
                if word == "~" || word.hasPrefix("~/") {
                    word = "$HOME" + word.dropFirst()
                } else {
                    return nil
                }
            }
        }
        return ParsedValue(text: word, mode: word.contains("$") ? .expression : .literal, wasQuoted: false)
    }

    static func isSecretName(_ name: String) -> Bool {
        let upper = name.uppercased()
        return ["SECRET", "TOKEN", "PASSWORD", "PASSWD", "CREDENTIAL", "APIKEY", "API_KEY", "PRIVATE_KEY"].contains { upper.contains($0) }
            || upper.hasSuffix("_KEY")
    }

    // MARK: - Line structure

    /// `name() {`, `name {`-style openers; returns the function name when `line` opens one.
    private static func functionOpener(_ line: String) -> String? {
        var text = Substring(line)
        let hasKeyword = text.hasPrefix("function ")
        if hasKeyword { text = text.dropFirst(9).drop { $0 == " " } }
        guard text.hasSuffix("{") else { return nil }
        text = text.dropLast()
        while text.last == " " { text = text.dropLast() }
        if text.hasSuffix("()") {
            text = text.dropLast(2)
            while text.last == " " { text = text.dropLast() }
        } else if !hasKeyword {
            return nil
        }
        let name = String(text)
        return ZshSyntax.isValidFunctionName(name) ? name : nil
    }

    /// Index of the last line of the statement starting at `start`: continues across
    /// open quotes, trailing backslashes and here-documents.
    private static func statementEnd(_ lines: [String], from start: Int) -> Int {
        var quote: Character?
        var index = start
        var heredocs: [String] = []
        while index < lines.count {
            let chars = Array(lines[index])
            var cursor = 0
            var continued = false
            while cursor < chars.count {
                let char = chars[cursor]
                if let open = quote {
                    if char == "\\", open == "\"" { cursor += 1 } else if char == open { quote = nil }
                } else if char == "\\" {
                    if cursor == chars.count - 1 { continued = true }
                    cursor += 1
                } else if char == "'" || char == "\"" {
                    quote = char
                } else if char == "#", cursor == 0 || chars[cursor - 1].isWhitespace {
                    break
                } else if char == "<", cursor + 2 < chars.count, chars[cursor + 1] == "<", chars[cursor + 2] != "<" {
                    let tail = chars[(cursor + 2)...]
                        .drop { $0 == "-" || $0 == " " }
                        .prefix { !$0.isWhitespace && !";&|<>".contains($0) }
                    let delimiter = String(tail).filter { $0 != "'" && $0 != "\"" && $0 != "\\" }
                    if !delimiter.isEmpty { heredocs.append(delimiter) }
                    cursor += 1
                }
                cursor += 1
            }
            if quote != nil || continued {
                index += 1
                continue
            }
            if !heredocs.isEmpty {
                // Consume body lines through each terminator.
                for delimiter in heredocs {
                    index += 1
                    while index < lines.count, lines[index].trimmingCharacters(in: .whitespaces) != delimiter { index += 1 }
                }
            }
            return min(index, lines.count - 1)
        }
        return lines.count - 1
    }

    /// Net change in block nesting (`if`/`fi`, `case`/`esac`, loops, braces) caused by these lines.
    private static func depthChange(for statement: [String]) -> Int {
        let openers: Set<String> = ["if", "for", "while", "until", "case", "select", "{", "("]
        let closers: Set<String> = ["fi", "done", "esac", "}", ")"]
        var change = 0
        for raw in statement {
            let line = raw.trimmingCharacters(in: .whitespaces)
            let tokens = line.split(whereSeparator: { $0.isWhitespace || $0 == ";" }).map(String.init)
            guard let first = tokens.first else { continue }
            if openers.contains(first) || (line.hasSuffix("{") && !line.hasSuffix("${")) {
                change += 1
                change -= tokens.dropFirst().filter { closers.contains($0) }.count
            } else if closers.contains(first) {
                change -= 1
            }
        }
        return change
    }
}
