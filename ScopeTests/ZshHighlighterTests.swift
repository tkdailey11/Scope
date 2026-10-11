import Foundation
import Testing
@testable import Scope

struct ZshHighlighterTests {
    /// (kind, matched text) pairs, so tests read like the source.
    private func tokens(_ text: String) -> [String] {
        let ns = text as NSString
        return ZshHighlighter.spans(in: text).map { "\($0.kind):\(ns.substring(with: $0.range))" }
    }

    @Test func keywordsMatchWholeWordsOnly() {
        #expect(tokens("if true; then echo done; fi") == ["keyword:if", "keyword:then", "keyword:done", "keyword:fi"])
        #expect(tokens("notif fi-x ./done").isEmpty)
    }

    @Test func commentsNeedAWordBoundary() {
        #expect(tokens("echo hi # note") == ["comment:# note"])
        #expect(tokens("echo a#b").isEmpty)
        #expect(tokens("# top\necho") == ["comment:# top"])
    }

    @Test func quotesAndVariables() {
        #expect(tokens("echo '$HOME'") == ["string:'$HOME'"])
        #expect(tokens("echo \"hi $USER ${HOME}\"") == ["string:\"hi $USER ${HOME}\"", "variable:$USER", "variable:${HOME}"])
        #expect(tokens("cd $1 $@ $?") == ["variable:$1", "variable:$@", "variable:$?"])
        #expect(tokens("echo \"a \\\" if\"") == ["string:\"a \\\" if\""])
    }

    @Test func escapedCharactersAreNotTokens() {
        #expect(tokens("echo \\# \\' \\$HOME").isEmpty)
    }

    @Test func unterminatedInputDoesNotCrashAndColoursToTheEnd() {
        #expect(tokens("echo 'oops") == ["string:'oops"])
        #expect(tokens("echo \"oops $x") == ["string:\"oops $x", "variable:$x"])
        #expect(tokens("echo ${oops").isEmpty)
        #expect(tokens("echo $").isEmpty)
        #expect(tokens("echo \\").isEmpty)
        #expect(tokens("").isEmpty)
    }

    @Test func rangesAreUTF16SoEmojiDoNotShiftLaterTokens() {
        #expect(tokens("echo \"😀\" ; if") == ["string:\"😀\"", "keyword:if"])
    }
}
