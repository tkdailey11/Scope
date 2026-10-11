//
//  ZshHighlighter.swift
//  Scope
//
//  Lightweight, display-only tokenizer for zsh function bodies. It never decides
//  what is valid (that's `zsh -n`); it only picks out comments, strings, variables
//  and keywords. Ranges are UTF-16 so they can be applied to NSTextStorage directly.
//

import Foundation

nonisolated enum ZshHighlighter {
    enum Kind: Sendable {
        case comment, string, variable, keyword
    }

    struct Span: Equatable, Sendable {
        var range: NSRange
        var kind: Kind
    }

    static let keywords: Set<String> = [
        "if", "then", "elif", "else", "fi", "for", "foreach", "while", "until", "do", "done",
        "case", "esac", "in", "select", "function", "return", "local", "typeset", "export",
        "time", "coproc",
    ]

    /// Spans in document order. Where spans overlap (a variable inside a double-quoted
    /// string), the later span is the more specific one and should be applied last.
    static func spans(in text: String) -> [Span] {
        let u = Array(text.utf16)
        var spans: [Span] = []
        var i = 0

        while i < u.count {
            let c = u[i]
            switch c {
            case Char.backslash:
                i += 2
            case Char.hash:
                guard i == 0 || isCommentBoundary(u[i - 1]) else { i += 1; continue }
                var end = i
                while end < u.count, u[end] != Char.newline { end += 1 }
                spans.append(Span(range: NSRange(location: i, length: end - i), kind: .comment))
                i = end
            case Char.singleQuote:
                var j = i + 1
                while j < u.count, u[j] != Char.singleQuote { j += 1 }
                let end = min(j + 1, u.count)
                spans.append(Span(range: NSRange(location: i, length: end - i), kind: .string))
                i = end
            case Char.doubleQuote:
                var j = i + 1
                while j < u.count, u[j] != Char.doubleQuote { j += u[j] == Char.backslash ? 2 : 1 }
                let closing = min(j, u.count)
                let end = min(j + 1, u.count)
                spans.append(Span(range: NSRange(location: i, length: end - i), kind: .string))
                // Variables expand inside double quotes, so mark them on top of the string.
                var k = i + 1
                while k < closing {
                    if u[k] == Char.backslash {
                        k += 2
                    } else if u[k] == Char.dollar, case let length = variableLength(in: u, at: k), length > 0 {
                        spans.append(Span(range: NSRange(location: k, length: min(length, closing - k)), kind: .variable))
                        k += length
                    } else {
                        k += 1
                    }
                }
                i = end
            case Char.dollar:
                let length = variableLength(in: u, at: i)
                if length > 0 {
                    spans.append(Span(range: NSRange(location: i, length: length), kind: .variable))
                    i += length
                } else {
                    i += 1
                }
            case _ where isWordCharacter(c):
                var j = i
                while j < u.count, isWordCharacter(u[j]) { j += 1 }
                if keywords.contains(String(decoding: u[i..<j], as: UTF16.self)) {
                    spans.append(Span(range: NSRange(location: i, length: j - i), kind: .keyword))
                }
                i = j
            default:
                i += 1
            }
        }
        return spans
    }

    // MARK: - Helpers

    private enum Char {
        static let backslash = code("\\")
        static let hash = code("#")
        static let singleQuote = code("'")
        static let doubleQuote = code("\"")
        static let dollar = code("$")
        static let newline = code("\n")
        static let openBrace = code("{")
        static let closeBrace = code("}")
        static let underscore = code("_")
    }

    /// `#` only starts a comment at the start of a word, so `echo a#b` has none.
    private static func isCommentBoundary(_ c: UInt16) -> Bool {
        c == code(" ") || c == code("\t") || c == Char.newline || c == code("\r")
            || c == code(";") || c == code("|") || c == code("&") || c == code("(")
    }

    private static func isLetter(_ c: UInt16) -> Bool {
        (code("a")...code("z")).contains(c) || (code("A")...code("Z")).contains(c)
    }

    private static func isDigit(_ c: UInt16) -> Bool {
        (code("0")...code("9")).contains(c)
    }

    private static func isWordCharacter(_ c: UInt16) -> Bool {
        isLetter(c) || isDigit(c) || c == Char.underscore || c == code(".")
            || c == code("-") || c == code("/") || c > 127
    }

    /// Length of the variable reference starting at the `$` at `k`, or 0 if it isn't one.
    private static func variableLength(in u: [UInt16], at k: Int) -> Int {
        guard k + 1 < u.count else { return 0 }
        let next = u[k + 1]
        if next == Char.openBrace {
            var j = k + 2
            while j < u.count, u[j] != Char.closeBrace, u[j] != Char.newline { j += 1 }
            return j < u.count && u[j] == Char.closeBrace ? j - k + 1 : 0
        }
        if isLetter(next) || next == Char.underscore {
            var j = k + 1
            while j < u.count, isLetter(u[j]) || isDigit(u[j]) || u[j] == Char.underscore { j += 1 }
            return j - k
        }
        if isDigit(next) || "@*#?$!-".utf16.contains(next) { return 2 }
        return 0
    }
}

/// UTF-16 code unit for an ASCII character.
private nonisolated func code(_ scalar: Unicode.Scalar) -> UInt16 {
    UInt16(scalar.value)
}
