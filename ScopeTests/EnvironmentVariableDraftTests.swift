import Testing
@testable import Scope

struct EnvironmentVariableDraftTests {
    private func draft(_ name: String, _ value: String = "x", _ mode: ValueMode = .literal) -> EnvironmentVariableDraft {
        var draft = EnvironmentVariableDraft()
        draft.name = name
        draft.value = value
        draft.valueMode = mode
        return draft
    }

    @Test func nameValidation() {
        #expect(draft("").nameIssue(existingNames: []) != nil)
        #expect(draft("  ").nameIssue(existingNames: []) != nil)
        #expect(draft("1A").nameIssue(existingNames: []) != nil)
        #expect(draft("A-B").nameIssue(existingNames: []) != nil)
        #expect(draft("GOPATH").nameIssue(existingNames: []) == nil)
        #expect(draft(" GOPATH ").nameIssue(existingNames: []) == nil)
    }

    @Test func duplicatesInSameScopeAreRejected() {
        #expect(draft("EDITOR").nameIssue(existingNames: ["EDITOR"]) != nil)
        #expect(draft("EDITOR").nameIssue(existingNames: ["OTHER"]) == nil)
    }

    @Test func danglingBackslashOnlyMattersForExpressions() {
        #expect(draft("A", "C:\\", .expression).valueIssue() != nil)
        #expect(draft("A", "C:\\", .literal).valueIssue() == nil)
    }

    @Test func emptyValueIsAllowed() {
        #expect(draft("A", "").isValid(existingNames: []))
        #expect(draft("A", "").generatedLine == "export A=''")
    }

    @Test func generatedLinePreviewMatchesGenerator() {
        #expect(draft("EDITOR", "nvim").generatedLine == "export EDITOR='nvim'")
        #expect(draft("GOPATH", "$HOME/go", .expression).generatedLine == "export GOPATH=\"$HOME/go\"")
        #expect(draft("Q", "it's").generatedLine == "export Q='it'\\''s'")
        #expect(draft("1BAD").generatedLine == nil)
        #expect(draft("A", "x\\", .expression).generatedLine == nil)
    }
}
