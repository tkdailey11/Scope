//
//  ZshQuoting.swift
//  Scope
//
//  The only place shell escaping lives. Keep it out of views.
//

import Foundation

nonisolated enum ZshSyntax {
    static func isValidVariableName(_ name: String) -> Bool {
        matches(name, first: { $0 == "_" || $0.isASCIILetter }, rest: { $0 == "_" || $0.isASCIILetter || $0.isASCIIDigit })
    }

    /// Conservative: letters, digits and `_ - . + : ,` (no whitespace, quotes, `=`, `$`, `/`).
    static func isValidAliasName(_ name: String) -> Bool {
        matches(name, first: { $0 != "-" && ($0 == "_" || $0.isASCIILetter || $0.isASCIIDigit || $0 == ".") },
                rest: { $0.isASCIILetter || $0.isASCIIDigit || "_-.+:,".contains($0) })
    }

    static func isValidFunctionName(_ name: String) -> Bool {
        matches(name, first: { $0 == "_" || $0.isASCIILetter },
                rest: { $0.isASCIILetter || $0.isASCIIDigit || "_-.:".contains($0) })
    }

    private static func matches(_ s: String, first: (Character) -> Bool, rest: (Character) -> Bool) -> Bool {
        guard let head = s.first, first(head) else { return false }
        return s.dropFirst().allSatisfy(rest)
    }
}

private extension Character {
    nonisolated var isASCIILetter: Bool { isASCII && isLetter }
    nonisolated var isASCIIDigit: Bool { isASCII && isNumber }
}

nonisolated enum ZshQuotingError: Error, Equatable {
    /// An expression ends in a lone backslash, which would escape the closing quote.
    case danglingBackslash
    case containsNUL
}

nonisolated enum ZshQuoting {
    /// Single-quoted literal. Nothing inside expands. Embedded `'` becomes `'\''`.
    /// Newlines are preserved (valid inside single quotes).
    static func literal(_ value: String) throws -> String {
        guard !value.contains("\0") else { throw ZshQuotingError.containsNUL }
        return "'" + value.replacing("'", with: "'\\''") + "'"
    }

    /// Double-quoted expression. `$VAR`, `$(...)`, backticks and existing backslash
    /// escapes are left for the shell to interpret; only bare `"` is escaped so the
    /// value cannot terminate its own quoting.
    static func expression(_ value: String) throws -> String {
        guard !value.contains("\0") else { throw ZshQuotingError.containsNUL }
        var out = "\""
        var iterator = value.makeIterator()
        while let char = iterator.next() {
            switch char {
            case "\\":
                guard let next = iterator.next() else { throw ZshQuotingError.danglingBackslash }
                out.append(char)
                out.append(next)
            case "\"":
                out.append("\\\"")
            default:
                out.append(char)
            }
        }
        return out + "\""
    }

    /// Renders a PATH entry. A leading `~` becomes `$HOME`; `$VAR` references stay
    /// expandable; everything else is escaped as in `expression`.
    static func pathComponent(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let normalized: String
        if trimmed == "~" {
            normalized = "$HOME"
        } else if trimmed.hasPrefix("~/") {
            normalized = "$HOME" + trimmed.dropFirst()
        } else {
            normalized = trimmed
        }
        return try expression(normalized)
    }
}
